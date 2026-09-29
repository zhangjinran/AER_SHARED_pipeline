clc; clear; 
%% ================== 1. 路径与基础配置 ==================
% 请根据你的实际路径进行修改
csv_dir = 'F:\AER_RETRA_CASE';
addpath('F:\AER_RETRA_CASE\先验数据');
% ★ 核心修改 1：更改了输出文件名，强制从零开始建立全新的 12 月份数据库！
total_mat_file = fullfile(csv_dir, 'CALIPSO_STATS_Monthly.mat');
processed_log  = fullfile(csv_dir, 'processed_files_log_monthly.mat');
logFile = fullfile(csv_dir, 'CALIPSO_processing_monthly_log.txt');

fid = fopen(logFile,'a'); % 追加模式
fprintf(fid,'\n======================================================\n');
fprintf(fid,'CALIPSO Processing (12-Month Structure) started at %s\n', datestr(now));

%% ================== 2. 加载先验参数库 ==================
fprintf('正在加载 MOPSMAP 与 OMCAM 先验参数库...\n');
try
    load('Lidar_Ratio_All.mat','Lidar_Ratio_All');   % 6×100 查找表
    Parameter_Particle_CALISPO=load('Parameter_Particle_CALISPO.mat');      % CALIPSO 粒径谱分布参数
    Extinction_Normalized=load('Extinction_Normalized.mat'); % MOPSMAP 归一化消光系数
catch ME
    error('加载先验参数失败！请确保 Lidar_Ratio_All.mat, Parameter_Particle_CALISPO.mat, Extinction_Normalized.mat 均在当前路径下。错误信息: %s', ME.message);
end
RH_grid = 1:100;
fprintf('先验参数库加载完成！\n');

%% ================== 3. 识别“新”文件 (增量更新) ==================
all_csvs = dir(fullfile(csv_dir, '*.csv'));
all_csv_names = {all_csvs.name}'; 

if isfile(processed_log)
    load(processed_log, 'processed_list');
else
    processed_list = {}; 
end

new_csv_names = setdiff(all_csv_names, processed_list);
if isempty(new_csv_names)
    fprintf('太棒了！没有发现新的 CSV 文件，所有数据均已是最新状态。\n');
    fprintf(fid, 'No new files to process.\n');
    fclose(fid);
    return;
end
fprintf('发现 %d 个新的 CSV 文件，准备进行处理...\n', length(new_csv_names));
fprintf(fid, 'Found %d new files to process.\n', length(new_csv_names));
new_csv_paths = fullfile(csv_dir, new_csv_names);

%% ================== 4. 加载历史数据或初始化网格 ==================
month_names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

if isfile(total_mat_file)
    fprintf('正在加载历史 12-Month 总数据库，请稍候...\n');
    load(total_mat_file, 'CALIPSO_STATS');
    fprintf('历史数据加载完成！\n');
else
    fprintf('未找到历史数据库，正在执行首次初始化 (建立 12 个月的空抽屉)...\n');
    nLat = 36; nLon = 72;
    CALIPSO_STATS.meta.grid_size = 5;
    CALIPSO_STATS.meta.daynight  = {'Day', 'Night'};
    % ★ 核心修改 2：元数据更新为 12 个月
    CALIPSO_STATS.meta.months    = cellstr(month_names); 
    CALIPSO_STATS.meta.aerosol_types = 1:7;
    
    CALIPSO_STATS.grid(nLat,nLon) = struct();
    for i = 1:nLat
        for j = 1:nLon
            CALIPSO_STATS.grid(i,j).lat_range = [-90+(i-1)*5, -90+i*5];
            CALIPSO_STATS.grid(i,j).lon_range = [-180+(j-1)*5, -180+j*5];
            
            % 为每个网格点创建 Day/Night，并在其下创建 Jan ~ Dec 12个结构体
            for dn = ["Day", "Night"]
                for m = 1:12
                    CALIPSO_STATS.grid(i,j).(dn).(month_names(m)) = struct();
                end
            end
        end
    end
end

%% ================== 5. 配置 Datastore ==================
ds = tabularTextDatastore(new_csv_paths, 'Delimiter', ',', 'ReadVariableNames', true);
ds.SelectedVariableNames = { ...
    'Lon', 'Lat', 'DN', 'Height', 'Type', 'DayNight', ...
    'LR', 'Depol', 'RH', 'Ext', 'Back'};
ds.ReadSize = 3e6; 
map_type = @(t) (t==1)*1 + (t==2)*2 + (t==3)*3 + (t==4)*3 + (t==6)*3;

%% ================== 6. 主循环 ==================
hWait = waitbar(0, '正在处理新数据并计算 Nd...', 'Name', 'CALIPSO Processing');
drawnow;
chunk_id   = 0;
total_rows = 0;
chunk_time = [];
t_start    = tic;

while hasdata(ds)
    t_chunk = tic;
    T = read(ds);
    chunk_id = chunk_id + 1;
    
    %% ---------- 6.1 质量控制 ----------
    good = T.LR > 0 & T.LR < 100 & ...
           T.RH > 0 & T.Depol >= 0 & ...
           T.Ext > 0 & T.Back > 0 & ...
           isfinite(T.LR) & isfinite(T.RH) & ...
           isfinite(T.Depol) & isfinite(T.Ext) & isfinite(T.Back) & isfinite(T.Height);
    T = T(good,:);
    if isempty(T); continue; end
    
    %% ---------- 6.2 时空与标志映射 ----------
    lat_idx = floor((T.Lat + 90) / 5) + 1;
    lon_idx = floor((T.Lon + 180) / 5) + 1;
    
    % ★ 核心修改 3：直接提取 1~12 的月份索引
    mths = month(datetime(T.DN, 'ConvertFrom', 'datenum'));
    month_id = uint8(mths); 
    
    dn_id = zeros(height(T),1,'uint8');
    dn_id(T.DayNight == "Day") = 1;
    dn_id(T.DayNight == "Night") = 2;
    
    % 过滤无效数据（确保月份在 1-12 之间）
    valid = (lat_idx>=1 & lat_idx<=36) & (lon_idx>=1 & lon_idx<=72) & ...
            (month_id>=1 & month_id<=12) & (dn_id>0) & (T.Type>=1 & T.Type<=7);
    
    T = T(valid,:);
    lat_idx = lat_idx(valid); lon_idx = lon_idx(valid);
    month_id = month_id(valid); dn_id = dn_id(valid);
    if isempty(T); continue; end
    
    %% ---------- 6.3 物理量修正与 MOPSMAP 计算 ----------
    RH = T.RH;
    RH(RH<1)=1; RH(RH>100)=100;
    T.RH = RH; 
    RH1 = ones(size(RH));   
    
    lr_mops     = nan(height(T),1);
    lr_mops_RH1 = nan(height(T),1);   
    
    for a = 1:7
        idx = T.Type == a;
        if ~any(idx); continue; end
        
        if a==5 || a==7
            delta = T.Depol(idx);
            f_dust = (delta - 0.05) .* 1.31 ./ (0.26 .* (1 + delta));
            f_dust = max(0, min(1, f_dust));
            
            LR_dust   = interp1(RH_grid, Lidar_Ratio_All(2,:), RH(idx));
            LR_dust_1 = interp1(RH_grid, Lidar_Ratio_All(2,:), RH1(idx));
            
            if a==5
                LR_nd   = interp1(RH_grid, Lidar_Ratio_All(3,:), RH(idx));
                LR_nd_1 = interp1(RH_grid, Lidar_Ratio_All(3,:), RH1(idx));
            else
                LR_nd   = interp1(RH_grid, Lidar_Ratio_All(1,:), RH(idx));
                LR_nd_1 = interp1(RH_grid, Lidar_Ratio_All(1,:), RH1(idx));
            end
            lr_mops(idx)     = f_dust .* LR_dust + (1 - f_dust) .* LR_nd;
            lr_mops_RH1(idx) = f_dust .* LR_dust_1 + (1 - f_dust) .* LR_nd_1;
        else
            mop_type = map_type(a);
            lr_mops(idx)     = interp1(RH_grid, Lidar_Ratio_All(mop_type,:), RH(idx));
            lr_mops_RH1(idx) = interp1(RH_grid, Lidar_Ratio_All(mop_type,:), RH1(idx));
        end
    end
    
    %% ---------- 6.4 核心：OMCAM Nd 数浓度计算 ----------
    [Nd_dry, Nd_wet] = Calc_Nd_OMCAM(T, Parameter_Particle_CALISPO, Extinction_Normalized);
    
    %% ---------- 6.5 动态追加到历史网格 ----------
    % ★ 核心修改 4：按照 month_id (1-12) 进行分组拼表
    [G, g_lat, g_lon, g_dn, g_month, g_type] = findgroups(lat_idx, lon_idx, dn_id, month_id, T.Type);
    
    daynight_names = ["Day", "Night"];
    
    for g = 1:max(G)
        idx = (G==g);
        i  = g_lat(g); j  = g_lon(g);
        dn_str = daynight_names(g_dn(g));   
        mn_str = month_names(g_month(g)); % 提取 Jan, Feb...
        tp_str = sprintf('Type%d', g_type(g));
        
        newData = table( ...
            T.Lon(idx), T.Lat(idx), T.DN(idx), T.Height(idx), ...
            T.LR(idx), lr_mops(idx), lr_mops_RH1(idx), ... 
            T.RH(idx), T.Depol(idx), T.Ext(idx), T.Back(idx), ... 
            Nd_dry(idx), Nd_wet(idx), ...
            'VariableNames', ...
            {'Lon','Lat','Time','Height','LidarRatio', ...
             'lidar_ratio_mopsmap','lidar_ratio_mopsmap_RH1', ...
             'ERA5_RH','Depolarization_Ratio','Extinction','Backscatter', ...
             'Nd_dry_OMCAM', 'Nd_wet_OMCAM'});
             
        % 挂载至全新的 12 月层级结构
        if ~isfield(CALIPSO_STATS.grid(i,j).(dn_str).(mn_str), tp_str)
            CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data = newData;
        else
            CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data = ...
                [CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data; newData];
        end
    end
    
    %% ---------- 6.6 进度日志 ----------
    total_rows = total_rows + height(T);
    dt = toc(t_chunk);
    chunk_time(end+1) = dt;
    avg_dt = mean(chunk_time(max(1,end-5):end));
    elapsed = toc(t_start);
    
    frac = ds.progress; 
    waitbar(frac, hWait, ...
        sprintf('Chunks: %d | Rows: %.2f M | Avg %.1f s/c | Elapsed %.1f min', ...
        chunk_id, total_rows/1e6, avg_dt, elapsed/60));
    fprintf(fid, 'Chunk %d | rows %.2f M | total %.2f M | %.1f s\n', ...
        chunk_id, height(T)/1e6, total_rows/1e6, dt);
end

%% ================== 7. 保存并更新记录 ==================
fprintf('\n数据读取与计算已全部完成，正在保存 12-Month 超级总文件...\n');
save(total_mat_file, 'CALIPSO_STATS', '-v7.3');

% 更新处理名单
processed_list = [processed_list; new_csv_names];
save(processed_log, 'processed_list');

fprintf(fid,'\nProcessing finished at %s\n', datestr(now));
fclose(fid);
close(hWait);
fprintf('✓ 终极成功：成功建立 12 个月独立存储库，合并了 %.2f 百万行数据！\n', total_rows/1e6);