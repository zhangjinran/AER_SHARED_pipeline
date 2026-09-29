clc;
addpath(fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))),'utils','shared','current'));

%% ===================== 1. 路径与配置 ==========================
% ★ 指向你的 CALIPSO L2 APro 数据文件夹
calipso_dir = getenv('CHAPTER5_FINALMAT_FILE');
if isempty(calipso_dir)
    calipso_dir = '\\DXP8800Pro-CRS\CALIPSO\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP\2007\2007_01_01.mat';
end

% ★ 输出文件名已更新，避免与旧结构的 MAT 文件冲突
out_mat_file = getenv('CHAPTER5_CLEAR_OUTPUT_FILE');
if isempty(out_mat_file)
    out_mat_file = 'F:\AER_SHARED_PIPELINE\runs\produce\run_20070101_era5real_001\intermediate\chapter5\CLEAR_AIR_STATS_20070101_finalmat_refactored.mat';
end
out_dir = fileparts(out_mat_file);
if ~isempty(out_dir) && ~isfolder(out_dir), mkdir(out_dir); end

S_final=load_day_with_nas_retry(calipso_dir);
final_files=S_final.day.files;
file_num = numel(final_files);
save_interval = 10; % 每10个文件磁盘同步一次

% ★ 核心升级 1：垂直高度分辨率拉满 (0~15km, 30米/0.03km 超高分辨率, 共 500 层)
z_edges = (0:0.06:15.0)'; 
num_bins = length(z_edges) - 1; 

% 12 个月的字段名称
month_names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

fprintf('\n\n');
fprintf('🚀 CALIPSO 晴空统计引擎启动：12个月份独立解析\n');
fprintf('📊 物理逻辑：AVD == 1 (Clear Air) | 30米超清垂直分辨率 (500层)\n');
fprintf('============================================================\n\n');

%% ===================== 2. 初始化网格 (36x72) ==========================
nLat = 36; nLon = 72; % 5°x5° 网格

if isfile(out_mat_file)
    fprintf('>>> 📁 检测到已有文件，正在断点续传...\n');
    resume_state = load_with_nas_retry(out_mat_file, 'CLEAR_STATS', 'processed_files');
    CLEAR_STATS = resume_state.CLEAR_STATS;
    processed_files = resume_state.processed_files;
    start_idx = processed_files + 1;
else
    fprintf('>>> 📁 正在初始化 12个月 × 500层 的全新网格结构...\n');
    CLEAR_STATS.grid = struct();
    for r = 1:nLat
        for c = 1:nLon
            for dn = ["Day","Night"]
                % ★ 核心升级 2：按 12 个月独立存储
                for mo = 1:12
                    m_str = month_names(mo);
                    % 传统的三个阈值累加 (用于地图)
                    CLEAR_STATS.grid(r,c).(dn).(m_str).count_2km  = 0;
                    CLEAR_STATS.grid(r,c).(dn).(m_str).count_5km  = 0;
                    CLEAR_STATS.grid(r,c).(dn).(m_str).count_10km = 0;
                    % 超高分辨率垂直分布 (500 x 1 列向量)
                    CLEAR_STATS.grid(r,c).(dn).(m_str).count_vert_prof = zeros(num_bins, 1);
                end
            end
        end
    end
    processed_files = 0; start_idx = 1;
    save(out_mat_file, 'CLEAR_STATS', 'processed_files');
end
%% ===================== 3. 循环处理 =============================
for i = start_idx:file_num
    F_final = final_files{i};
    file_name = F_final.filename;
    file_path = calipso_dir;

    fprintf('  [File %d/%d] %s ', i, file_num, file_name);

    try
        %% A. 读取与时间日夜标记
        if contains(file_name, 'ZN') || contains(file_name, 'Night')
            daynight_flag = "Night"; 
        else
            daynight_flag = "Day";
        end
        
        % 提取 AVD
        AVD_raw = uint16(F_final.Atmospheric_Volume_Description);
        AVD = AVD_raw(:,:,1);
        if size(AVD, 2) ~= 399 && size(AVD, 1) == 399, AVD = AVD'; end
        N_prof = size(AVD, 1); N_bin = 399;
        
        %% B. 一维化展平 (Bulldozer!)
        avd_1d = reshape(AVD, [], 1);
        
        % 提取地理与时间坐标
        Lon_raw = double(F_final.Longitude);
        Lat_raw = double(F_final.Latitude);
        Time_raw = double(F_final.Profile_Time);
        
        Lon = calipso_profile_center(Lon_raw,N_prof);
        Lat = calipso_profile_center(Lat_raw,N_prof);
        Time_vec = calipso_profile_center(Time_raw,N_prof);
        utc_dn_prof = Time_vec / 86400 + datenum(1993, 1, 1);
        
        % 获取高度轴
        alt_axis = double(F_final.Lidar_Data_Altitudes);
        
        Lon_Mat  = repmat(Lon(:), 1, N_bin);
        Lat_Mat  = repmat(Lat(:), 1, N_bin);
        Time_Mat = repmat(utc_dn_prof(:), 1, N_bin);
        Alt_Mat  = repmat(alt_axis(:)', N_prof, 1);
        
        lon_1d  = reshape(Lon_Mat, [], 1);
        lat_1d  = reshape(Lat_Mat, [], 1);
        time_1d = reshape(Time_Mat, [], 1);
        alt_1d  = reshape(Alt_Mat, [], 1);

        %% C. 核心识别：提取晴空像元 (Clear Air)
        Feature_Type_1d = bitand(avd_1d, uint16(7)); 
        clear_mask = (Feature_Type_1d == 1);
        
        if ~any(clear_mask)
            error('No Clear Air pixels found.');
        end
        
        h_v   = alt_1d(clear_mask);
        lon_v = lon_1d(clear_mask);
        lat_v = lat_1d(clear_mask);
        utc_v = time_1d(clear_mask);
        
        %% D. 计算基础分箱信息
        [~, months, ~] = datevec(utc_v);
        
        % 计算网格位置 [1~72, 1~36]
        lon_idx = max(1, min(72, ceil((lon_v + 180) / 5)));
        lat_idx = max(1, min(36, ceil((lat_v + 90) / 5)));
        
        % 计算高度对应的垂直 Bin
        b_idx = discretize(h_v, z_edges);

        %% E. 分配与累加至网格结构
        layers = [2.0, 5.0, 10.0];
        f_names = ["count_2km", "count_5km", "count_10km"];
        file_stats = [0, 0, 0];
        
        % ★ 逐月循环 (1 ~ 12)
        for mo = 1:12
            s_mask = (months == mo);
            m_str  = month_names(mo);
            
            if any(s_mask)
                % 1. 累加 2km/5km/10km 标量阈值
                for k = 1:3
                    h_mask = s_mask & (h_v <= layers(k));
                    file_stats(k) = file_stats(k) + sum(h_mask);
                    
                    if any(h_mask)
                        counts = accumarray([lat_idx(h_mask), lon_idx(h_mask)], 1, [nLat, nLon]);
                        [rr, cc] = find(counts > 0);
                        for idx = 1:length(rr)
                            r = rr(idx); c = cc(idx);
                            CLEAR_STATS.grid(r,c).(daynight_flag).(m_str).(f_names(k)) = ...
                                CLEAR_STATS.grid(r,c).(daynight_flag).(m_str).(f_names(k)) + counts(r,c);
                        end
                    end
                end
                
                % 2. 累加精细垂直高度廓线 (500 层)
                valid_b_mask = s_mask & ~isnan(b_idx);
                if any(valid_b_mask)
                    subs = [lat_idx(valid_b_mask), lon_idx(valid_b_mask), b_idx(valid_b_mask)];
                    counts_3d = accumarray(subs, 1, [nLat, nLon, num_bins]);
                    
                    [rr, cc] = find(sum(counts_3d, 3) > 0);
                    for idx = 1:length(rr)
                        r = rr(idx); c = cc(idx);
                        CLEAR_STATS.grid(r,c).(daynight_flag).(m_str).count_vert_prof = ...
                            CLEAR_STATS.grid(r,c).(daynight_flag).(m_str).count_vert_prof + squeeze(counts_3d(r,c,:));
                    end
                end
            end
        end
        
        fprintf('-> OK (Clear Pixels: 2k:%d, 5k:%d, 10k:%d)\n', file_stats(1), file_stats(2), file_stats(3));

    catch ME
        fprintf(2,'CLEAR_AIR_ORBIT_FAILED %s\n',getReport(ME,'extended','hyperlinks','off'));
        rethrow(ME); % Never mark a skipped/failed orbit as a completed day.
    end
    
    %% F. 存档机制
    if mod(i, save_interval) == 0 || i == file_num
        processed_files = i;
        save(out_mat_file, 'CLEAR_STATS', 'processed_files');
        fprintf('    💾 [磁盘同步] 已安全保存至第 %d 个文件\n', i);
    end
end 

fprintf('\n✅ 任务圆满结束！最终文件已生成： %s\n', out_mat_file);

function S_final = load_day_with_nas_retry(calipso_dir)
% NAS reads may transiently fail at HDF5 chunk level. Retry only the I/O.
max_attempts = 5;
for attempt = 1:max_attempts
    try
        S_final = load_with_nas_retry(calipso_dir,'day');
        if ~isfield(S_final,'day')
            error('ClearAir:MissingDay','Variable day is absent from %s',calipso_dir);
        end
        fprintf('CLEAR_AIR_FINALMAT_READ_PASS attempt=%d/%d\n',attempt,max_attempts);
        return
    catch ME
        fprintf(2,'CLEAR_AIR_FINALMAT_READ_RETRY attempt=%d/%d file=%s error=%s\n', ...
            attempt,max_attempts,calipso_dir,ME.message);
        if attempt == max_attempts, rethrow(ME); end
        pause(2 * attempt);
    end
end
end
