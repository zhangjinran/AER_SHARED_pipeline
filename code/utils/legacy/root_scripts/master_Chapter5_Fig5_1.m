%% master_Chapter5_Fig5_1.m
% 集成主函数：CALIPSO HDF → 参数匹配 → 网格统计 → 图 5.1（全球 Nd 地图）
%
% 集成了以下原始脚本的核心逻辑：
%   ① CALIPSO_ERA5_MATCH.m     — HDF 读取 + ERA5 RH 插值
%   ② spacial_match_cvs2mat.m  — 网格化 + MOPSMAP + OMCAM Nd
%   ③ clear_air_collection.m   — 晴空统计
%   ④ figure_5_1.m             — 绘制图 5.1
%
% 输出文件（均加 _integrated 后缀，不与原文件重名）：
%   CALIPSO_results_integrated.mat       — 步骤①中间结果
%   CALIPSO_STATS_integrated.mat         — 步骤②网格统计
%   CLEAR_AIR_STATS_integrated.mat       — 步骤③晴空统计
%   Figure_5_1.png                       — 图 5.1 图片
%
% 注意：ERA5_CACHE 需提前由 read_ERA5/read_ERA5.m 生成

clear; clc; close all;
addpath('./函数');
addpath('./先验数据');

% =========================================================================
% 0. 全局配置（共同输入写在开头）
% =========================================================================
% ★★★★★ 用户按需修改以下参数 ★★★★★
calipso_dir = 'Z:\05kmAP';    % CALIPSO HDF 文件夹
ERA5_DIR    = './ERA5_CACHE';                            % ERA5 缓存文件夹
date_start  = '2007-01-01';                                           % 空=原始模式, 填'2022-06-01'=按日期筛选
date_end    = '2008-01-01';                                           % 同上，空=单日
out_suffix  = '_integrated';                             % 输出文件后缀
out_dir     = './output_integrated';                     % 输出根目录(仅存build_log)
run_id      = ['run_', datestr(now, 'yyyymmdd_HHMMss')]; % 本次运行标识，如 run_20260712_215100
cache_dir   = fullfile(out_dir, run_id, 'cache');        % 中间产物(.mat)
results_dir = fullfile(out_dir, run_id, 'results');      % 最终成果(图片等)
auto_skip   = false;                                     % true=静默跳过缓存, false=每次询问
ExternalStatsPath = getenv('CHAPTER5_EXTERNAL_STATS_PATH');
% ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★

% ★ 创建输出根目录 + 本次运行子目录
if ~isfolder(out_dir)
    mkdir(out_dir);
    fprintf('  创建输出根目录: %s\n', out_dir);
end
mkdir(cache_dir); mkdir(results_dir);
fprintf('  本次运行: %s\n', run_id);

use_external_stats = ~isempty(ExternalStatsPath);
if use_external_stats
    if ~isfile(ExternalStatsPath)
        error('Chapter5:MissingExternalStats', ...
            'External CALIPSO_STATS not found: %s', ExternalStatsPath);
    end
    S_ext = load(ExternalStatsPath, 'CALIPSO_STATS');
    if ~isfield(S_ext, 'CALIPSO_STATS')
        error('Chapter5:InvalidExternalStats', ...
            'External file does not contain CALIPSO_STATS.');
    end
    CALIPSO_STATS = S_ext.CALIPSO_STATS;
    fprintf('\n=== EXTERNAL CALIPSO_STATS ===\n');
    fprintf('path = %s\n', ExternalStatsPath);
    fprintf('internal Step 1/Step 2 = SKIPPED\n');
end

% ★ 施工日志：加载或初始化
build_log_path = fullfile(out_dir, 'build_log.mat');
session_rerun  = false(4, 1);

if isfile(build_log_path)
    load(build_log_path, 'build_log');
    fprintf('  加载施工日志: %s (%d 条历史记录)\n', build_log_path, length(build_log.runs));
else
    build_log = struct();
    build_log.version = '1.2';
    build_log.runs = {};
    fprintf('  新建施工日志: %s\n', build_log_path);
end

% ★ 为本次运行占位（追加到日志末尾）
current_run = struct();
current_run.id = run_id;
current_run.out_dir = out_dir;
current_run.timestamp = datestr(now);
if ~isempty(date_start)
    if isdatetime(date_start)
        current_run.date_start = datestr(date_start, 'yyyy-mm-dd');
    else
        current_run.date_start = date_start;
    end
    if isempty(date_end)
        current_run.date_end = current_run.date_start;
    elseif isdatetime(date_end)
        current_run.date_end = datestr(date_end, 'yyyy-mm-dd');
    else
        current_run.date_end = date_end;
    end
end
current_run.input_files = {};
current_run.steps = cell(4, 1);
for si = 1:4
    current_run.steps{si} = struct();
    current_run.steps{si}.name = '';
    current_run.steps{si}.status = 'pending';
    current_run.steps{si}.output = '';
    current_run.steps{si}.timestamp = '';
end
build_log.runs{end+1} = current_run;
save(build_log_path, 'build_log');
fprintf('  >> 施工日志已保存（占位）: %s\n', build_log_path);

if ~use_external_stats
% =========================================================================
% 1. 步骤①: HDF → 气溶胶参数 + ERA5 RH 插值
%    来源: CALIPSO_ERA5_MATCH.m
% =========================================================================
fprintf('============================================================\n');
fprintf('  步骤①: CALIPSO HDF -> 气溶胶参数 + ERA5 RH 插值\n');
fprintf('============================================================\n');
files = filter_hdf_by_date(calipso_dir, date_start, date_end);
file_num = length(files);
fprintf('  共发现 %d 个文件\n', file_num);

% ★ 清理重复的历史运行记录
if length(build_log.runs) > 1
    build_log = cleanup_build_log(build_log, out_dir, date_start, date_end, sort({files.name})');
end

% ★ 缓存检查：步骤①
[cache_run_id, step1_skip] = find_cached_run(build_log, 1, sort({files.name})', session_rerun, auto_skip, date_start, date_end);

if step1_skip
    cache_path = fullfile(out_dir, cache_run_id, 'cache', sprintf('CALIPSO_results%s.mat', out_suffix));
    d_info = dir(cache_path);
    fprintf('  跳过步骤①，加载历史缓存 (%.2f GB)...\n', d_info.bytes / 1e9);
    t_load = tic;
    load(cache_path, 'T_all');
    fprintf('    ✓ 加载完成 (%.1f 秒)\n\n', toc(t_load));
else
    % 加载 ERA5 元数据
    meta = get_ERA5_meta(ERA5_DIR);

    all_data = {};

for i = 1:file_num
    file_path = fullfile(files(i).folder, files(i).name);
    fname = files(i).name;
    fprintf('  [%d/%d] %s ... ', i, file_num, fname);

    try
        %% 1.1 读取基础光学参数
        Ext_raw   = double(hdfread(file_path, '/Extinction_Coefficient_532'));
        Back_raw  = double(hdfread(file_path, '/Total_Backscatter_Coefficient_532'));
        Depol_raw = double(hdfread(file_path, '/Particulate_Depolarization_Ratio_Profile_532'));
        AVD_raw   = uint16(hdfread(file_path, '/Atmospheric_Volume_Description'));

        Ext = Ext_raw(:,:,1); Back = Back_raw(:,:,1);
        Depol = Depol_raw(:,:,1); AVD = AVD_raw(:,:,1);

        % 规范方向: 确保高度层(399)在第二维
        if size(Ext, 1) == 399,  Ext = Ext';  end
        if size(Back, 1) == 399, Back = Back'; end
        if size(Depol, 1) == 399, Depol = Depol'; end
        if size(AVD, 1) == 399,  AVD = AVD';  end

        N_prof = size(Ext, 1); N_bin = 399;
        total_elements = N_prof * N_bin;

        % 展平为 1D
        ext_1d   = reshape(Ext(:,:), [], 1);
        back_1d  = reshape(Back(:,:), [], 1);
        depol_1d = reshape(Depol(:,:), [], 1);
        avd_1d   = reshape(AVD(:,:), [], 1);

        %% 1.2 读取坐标与时间
        Lon_raw  = double(hdfread(file_path, '/Longitude'));
        Lat_raw  = double(hdfread(file_path, '/Latitude'));
        Time_raw = double(hdfread(file_path, '/Profile_Time'));

        if numel(Lon_raw) >= N_prof * 3
            Lon = reshape(Lon_raw(1:N_prof*3), 3, N_prof)'; Lon = Lon(:, 2);
            Lat = reshape(Lat_raw(1:N_prof*3), 3, N_prof)'; Lat = Lat(:, 2);
            Time_vec = reshape(Time_raw(1:N_prof*3), 3, N_prof)'; Time_vec = Time_vec(:, 2);
        else
            Lon = Lon_raw(:); Lat = Lat_raw(:); Time_vec = Time_raw(:);
        end
        Lon = Lon(1:N_prof); Lat = Lat(1:N_prof); Time_vec = Time_vec(1:N_prof);
        utc_dn_prof = Time_vec / 86400 + datenum(1993, 1, 1);

        % 高度轴
        meta_h = hdfread(file_path, '/metadata', 'Fields', 'Lidar_Data_Altitudes');
        alt_axis = double(meta_h{1});

        % 扩展为 2D 再拍平
        lon_1d  = reshape(repmat(Lon(:), 1, N_bin), [], 1);
        lat_1d  = reshape(repmat(Lat(:), 1, N_bin), [], 1);
        time_1d = reshape(repmat(utc_dn_prof(:), 1, N_bin), [], 1);
        alt_1d  = reshape(repmat(alt_axis(:)', N_prof, 1), [], 1);

        %% 1.3 气溶胶分类 (AVD 位运算)
        Feature_Type_1d = bitand(avd_1d, uint16(7));
        type_1d = bitand(bitshift(avd_1d, -9), uint16(7));
        type_1d(Feature_Type_1d ~= 3) = 0;
        type_1d = double(type_1d);

        %% 1.4 有效像元筛选
        valid_mask = (type_1d > 0) & (ext_1d > 0) & (back_1d > 0) & ...
                     (depol_1d >= 0) & isfinite(ext_1d) & isfinite(back_1d) & isfinite(depol_1d);

        if ~any(valid_mask)
            fprintf('跳过(无有效气溶胶)\n');
            continue;
        end
        N_valid = sum(valid_mask);

        % 构造临时表格
        T_file = table();
        T_file.FileName  = repmat({fname}, N_valid, 1);
        T_file.Lon       = lon_1d(valid_mask);
        T_file.Lat       = lat_1d(valid_mask);
        T_file.Height    = alt_1d(valid_mask);
        T_file.Ext       = ext_1d(valid_mask);
        T_file.Back      = back_1d(valid_mask);
        T_file.Depol     = depol_1d(valid_mask);
        T_file.LR        = ext_1d(valid_mask) ./ back_1d(valid_mask);
        T_file.Type      = type_1d(valid_mask);
        T_file.UTC       = time_1d(valid_mask);

        % 日夜标记
        if contains(fname, 'ZN') || contains(fname, 'Night')
            T_file.DayNight = repmat("Night", N_valid, 1);
        else
            T_file.DayNight = repmat("Day", N_valid, 1);
        end

        %% 1.5 ERA5 RH 空间插值
        RH_v = NaN(N_valid, 1);
        t_match_idx = round(interp1(datenum(meta.time), 1:numel(meta.time), ...
                                     T_file.UTC, 'nearest', 'extrap'));
        unique_ts = unique(t_match_idx);

        for ut = unique_ts'
            era_f = fullfile(ERA5_DIR, ...
                sprintf('ERA5_%s.mat', datestr(meta.time(ut), 'yyyymmdd_HH')));
            if isfile(era_f)
                E = load(era_f, 'ERA5');
                curr_pts = find(t_match_idx == ut);
                for ii = 1:numel(curr_pts)
                    idx = curr_pts(ii);
                    lon_ix = min(max(round(mod(T_file.Lon(idx),360)/meta.dlon)+1,1),numel(meta.lon));
                    lat_ix = min(max(round((90-T_file.Lat(idx))/meta.dlat)+1,1),numel(meta.lat));
                    h_p = squeeze(E.ERA5.height(lon_ix, lat_ix, :));
                    r_p = squeeze(E.ERA5.RH(lon_ix, lat_ix, :));
                    if ~any(isnan(h_p))
                        RH_v(idx) = interp1(h_p, r_p, T_file.Height(idx)*1000, 'linear', NaN);
                    end
                end
            end
        end
        T_file.RH = RH_v;

        all_data{end+1} = T_file;
        fprintf('%d 个像元\n', N_valid);

    catch ME
        fprintf('跳过(%s)\n', ME.message);
    end
end

if isempty(all_data)
    error('没有处理到任何有效数据!');
end
T_all = vertcat(all_data{:});
fprintf('  步骤①完成: 共 %d 个气溶胶像元\n\n', height(T_all));

save(fullfile(cache_dir, sprintf('CALIPSO_results%s.mat', out_suffix)), 'T_all', '-v7.3');
fprintf('  >> 已保存: %s\n\n', fullfile(cache_dir, sprintf('CALIPSO_results%s.mat', out_suffix)));

    session_rerun(1) = true;
end

% ★ 更新本次运行 步骤①日志
cr = build_log.runs{end};
cr.input_files = sort({files.name})';
cr.steps{1}.name = 'HDF→参数+ERA5 RH';
cr.steps{1}.status = 'done';
cr.steps{1}.output = sprintf('CALIPSO_results%s.mat', out_suffix);
cr.steps{1}.timestamp = datestr(now);
build_log.runs{end} = cr;
save(build_log_path, 'build_log');
fprintf('  >> 施工日志已保存（步骤①完成）: %s\n', build_log_path);

% =========================================================================
% 2. 步骤②: 网格化 5°×5° + MOPSMAP LR 修正 + OMCAM Nd 计算
%    来源: spacial_match_cvs2mat.m
% =========================================================================
fprintf('============================================================\n');
fprintf('  步骤②: 网格化 5x5 + MOPSMAP LR 修正 + OMCAM Nd 计算\n');
fprintf('============================================================\n');

% 2.1 加载先验参数
fprintf('  加载先验参数库...\n');
load('Lidar_Ratio_All.mat', 'Lidar_Ratio_All');
Para_Particle = load('Parameter_Particle_CALISPO.mat');
Ext_Norm      = load('Extinction_Normalized.mat');
RH_grid = 1:100;

month_names = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
nLat = 36; nLon = 72;

% ★ 缓存检查：步骤②
[cache_run_id, step2_skip] = find_cached_run(build_log, 2, {}, session_rerun, auto_skip, date_start, date_end);

if step2_skip
    cache_path = fullfile(out_dir, cache_run_id, 'cache', sprintf('CALIPSO_STATS%s.mat', out_suffix));
    d_info = dir(cache_path);
    fprintf('  跳过步骤②，加载历史缓存 (%.2f GB)...\n', d_info.bytes / 1e9);
    t_load = tic;
    load(cache_path, 'CALIPSO_STATS');
    fprintf('    ✓ 加载完成 (%.1f 秒)\n\n', toc(t_load));
else
    % 2.2 初始化 12 月网格结构
    CALIPSO_STATS = struct();
    CALIPSO_STATS.meta.grid_size = 5;
    CALIPSO_STATS.meta.daynight  = {'Day', 'Night'};
    CALIPSO_STATS.meta.months    = cellstr(month_names);
    CALIPSO_STATS.meta.aerosol_types = 1:7;
    CALIPSO_STATS.grid(nLat, nLon) = struct();

for i = 1:nLat
    for j = 1:nLon
        CALIPSO_STATS.grid(i,j).lat_range = [-90+(i-1)*5, -90+i*5];
        CALIPSO_STATS.grid(i,j).lon_range = [-180+(j-1)*5, -180+j*5];
        for dn = ["Day", "Night"]
            for m = 1:12
                CALIPSO_STATS.grid(i,j).(dn).(month_names(m)) = struct();
            end
        end
    end
end

% 2.3 计算网格索引
lat_idx = floor((T_all.Lat + 90) / 5) + 1;
lon_idx = floor((T_all.Lon + 180) / 5) + 1;
mths = month(datetime(T_all.UTC, 'ConvertFrom', 'datenum'));
month_id = uint8(mths);

dn_id = zeros(height(T_all), 1, 'uint8');
dn_id(T_all.DayNight == "Day")   = 1;
dn_id(T_all.DayNight == "Night") = 2;

valid_g = (lat_idx >= 1 & lat_idx <= 36) & (lon_idx >= 1 & lon_idx <= 72) & ...
          (month_id >= 1 & month_id <= 12) & (dn_id > 0) & (T_all.Type >= 1 & T_all.Type <= 7);

T = T_all(valid_g, :);
lat_idx  = lat_idx(valid_g);
lon_idx  = lon_idx(valid_g);
month_id = month_id(valid_g);
dn_id    = dn_id(valid_g);
fprintf('  有效网格数据 %d 条\n', height(T));

% 2.4 MOPSMAP LR 修正
RH = T.RH;
RH(RH < 1) = 1;  RH(RH > 100) = 100;

lr_mops = NaN(height(T), 1);
map_type = @(t) (t==1)*1 + (t==2)*2 + (t==3)*3 + (t==4)*3 + (t==6)*3;

for a = 1:7
    idx = T.Type == a;
    if ~any(idx); continue; end

    if a == 5 || a == 7   % 混合型: 退偏比线性混合
        delta = T.Depol(idx);
        f_dust = (delta - 0.05) * 1.31 ./ (0.26 * (1 + delta));
        f_dust = max(0, min(1, f_dust));
        LR_dust = interp1(RH_grid, Lidar_Ratio_All(2,:), RH(idx));
        if a == 5
            LR_nd = interp1(RH_grid, Lidar_Ratio_All(3,:), RH(idx));
        else
            LR_nd = interp1(RH_grid, Lidar_Ratio_All(1,:), RH(idx));
        end
        lr_mops(idx) = f_dust .* LR_dust + (1 - f_dust) .* LR_nd;
    else
        lr_mops(idx) = interp1(RH_grid, Lidar_Ratio_All(map_type(a),:), RH(idx));
    end
end

% 2.5 OMCAM Nd 计算
[Nd_dry, Nd_wet] = Calc_Nd_OMCAM(T, Para_Particle, Ext_Norm);

% 2.6 按网格分组存储
[G, g_lat, g_lon, g_dn, g_month, g_type] = ...
    findgroups(lat_idx, lon_idx, dn_id, month_id, T.Type);
daynight_names = ["Day", "Night"];

fprintf('  分组存储到网格结构 (%d 组)...\n', max(G));
for g = 1:max(G)
    idx = (G == g);
    i = g_lat(g); j = g_lon(g);
    dn_str = daynight_names(g_dn(g));
    mn_str = month_names(g_month(g));
    tp_str = sprintf('Type%d', g_type(g));

    newData = table(...
        T.Lon(idx), T.Lat(idx), T.UTC(idx), T.Height(idx), ...
        T.LR(idx), lr_mops(idx), T.RH(idx), T.Depol(idx), ...
        T.Ext(idx), T.Back(idx), ...
        Nd_dry(idx), Nd_wet(idx), ...
        'VariableNames', ...
        {'Lon','Lat','Time','Height','LidarRatio', ...
         'lidar_ratio_mopsmap','ERA5_RH','Depolarization_Ratio', ...
         'Extinction','Backscatter','Nd_dry_OMCAM','Nd_wet_OMCAM'});

    if ~isfield(CALIPSO_STATS.grid(i,j).(dn_str).(mn_str), tp_str)
        CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data = newData;
    else
        CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data = ...
            [CALIPSO_STATS.grid(i,j).(dn_str).(mn_str).(tp_str).data; newData];
    end
end

save(fullfile(cache_dir, sprintf('CALIPSO_STATS%s.mat', out_suffix)), 'CALIPSO_STATS', '-v7.3');
fprintf('  >> 已保存: %s\n\n', fullfile(cache_dir, sprintf('CALIPSO_STATS%s.mat', out_suffix)));

    session_rerun(2) = true;
end

% ★ 更新本次运行 步骤②日志
cr = build_log.runs{end};
cr.steps{2}.name = '网格化+MOPSMAP+OMCAM';
cr.steps{2}.status = 'done';
cr.steps{2}.output = sprintf('CALIPSO_STATS%s.mat', out_suffix);
cr.steps{2}.timestamp = datestr(now);
build_log.runs{end} = cr;
save(build_log_path, 'build_log');
fprintf('  >> 施工日志已保存（步骤②完成）: %s\n', build_log_path);

end % ~use_external_stats: internal Step 1/Step 2

% =========================================================================
% 3. 步骤③: CALIPSO 晴空像元 (AVD==1) 统计
%    来源: clear_air_collection.m
% =========================================================================
fprintf('============================================================\n');
fprintf('  步骤③: CALIPSO 晴空像元 (AVD==1) 统计\n');
fprintf('============================================================\n');

z_edges = (0:0.06:15.0)';
num_bins = length(z_edges) - 1;

% ★ 缓存检查：步骤③
[cache_run_id, step3_skip] = find_cached_run(build_log, 3, sort({files.name})', session_rerun, auto_skip, date_start, date_end);

if step3_skip
    cache_path = fullfile(out_dir, cache_run_id, 'cache', sprintf('CLEAR_AIR_STATS%s.mat', out_suffix));
    d_info = dir(cache_path);
    fprintf('  跳过步骤③，加载历史缓存 (%.2f GB)...\n', d_info.bytes / 1e9);
    t_load = tic;
    load(cache_path, 'CLEAR_STATS');
    fprintf('    ✓ 加载完成 (%.1f 秒)\n\n', toc(t_load));
else
    % 初始化晴空网格
    CLEAR_STATS.grid = struct();
for r = 1:nLat
    for c = 1:nLon
        for dn = ["Day", "Night"]
            for mo = 1:12
                m_str = month_names(mo);
                CLEAR_STATS.grid(r,c).(dn).(m_str).count_2km  = 0;
                CLEAR_STATS.grid(r,c).(dn).(m_str).count_5km  = 0;
                CLEAR_STATS.grid(r,c).(dn).(m_str).count_10km = 0;
                CLEAR_STATS.grid(r,c).(dn).(m_str).count_vert_prof = zeros(num_bins, 1);
            end
        end
    end
end

fprintf('  处理 %d 个 HDF 文件...\n', file_num);

for i = 1:file_num
    file_path = fullfile(files(i).folder, files(i).name);
    fname = files(i).name;
    fprintf('  [%d/%d] %s ... ', i, file_num, fname);

    try
        % 日夜标记
        if contains(fname, 'ZN') || contains(fname, 'Night')
            daynight_flag = "Night";
        else
            daynight_flag = "Day";
        end

        % 读取 AVD
        AVD_raw = uint16(hdfread(file_path, '/Atmospheric_Volume_Description'));
        AVD = AVD_raw(:,:,1);
        if size(AVD, 2) ~= 399 && size(AVD, 1) == 399, AVD = AVD'; end
        N_prof = size(AVD, 1); N_bin = 399;

        avd_1d = reshape(AVD(:,:), [], 1);

        % 坐标
        Lon_raw  = double(hdfread(file_path, '/Longitude'));
        Lat_raw  = double(hdfread(file_path, '/Latitude'));
        Time_raw = double(hdfread(file_path, '/Profile_Time'));

        if numel(Lon_raw) >= N_prof * 3
            Lon = reshape(Lon_raw(1:N_prof*3), 3, N_prof)'; Lon = Lon(:, 2);
            Lat = reshape(Lat_raw(1:N_prof*3), 3, N_prof)'; Lat = Lat(:, 2);
            Time_vec = reshape(Time_raw(1:N_prof*3), 3, N_prof)'; Time_vec = Time_vec(:, 2);
        else
            Lon = Lon_raw(:); Lat = Lat_raw(:); Time_vec = Time_raw(:);
        end
        Lon = Lon(1:N_prof); Lat = Lat(1:N_prof); Time_vec = Time_vec(1:N_prof);
        utc_dn_prof = Time_vec / 86400 + datenum(1993, 1, 1);

        meta_h = hdfread(file_path, '/metadata', 'Fields', 'Lidar_Data_Altitudes');
        alt_axis = double(meta_h{1});

        lon_1d  = reshape(repmat(Lon(:), 1, N_bin), [], 1);
        lat_1d  = reshape(repmat(Lat(:), 1, N_bin), [], 1);
        time_1d = reshape(repmat(utc_dn_prof(:), 1, N_bin), [], 1);
        alt_1d  = reshape(repmat(alt_axis(:)', N_prof, 1), [], 1);

        % 晴空识别
        Feature_Type_1d = bitand(avd_1d, uint16(7));
        clear_mask = (Feature_Type_1d == 1);

        if ~any(clear_mask)
            fprintf('无晴空\n');
            continue;
        end

        h_v   = alt_1d(clear_mask);
        lon_v = lon_1d(clear_mask);
        lat_v = lat_1d(clear_mask);
        utc_v = time_1d(clear_mask);

        [~, months, ~] = datevec(utc_v);

        lon_idx_c = max(1, min(72, ceil((lon_v + 180) / 5)));
        lat_idx_c = max(1, min(36, ceil((lat_v + 90) / 5)));
        b_idx = discretize(h_v, z_edges);

        layers = [2.0, 5.0, 10.0];
        f_names = ["count_2km", "count_5km", "count_10km"];

        for mo = 1:12
            s_mask = (months == mo);
            m_str = month_names(mo);

            if any(s_mask)
                for k = 1:3
                    h_mask = s_mask & (h_v <= layers(k));
                    if any(h_mask)
                        counts = accumarray([lat_idx_c(h_mask), lon_idx_c(h_mask)], 1, [nLat, nLon]);
                        [rr, cc] = find(counts > 0);
                        for idx = 1:length(rr)
                            CLEAR_STATS.grid(rr(idx), cc(idx)).(daynight_flag).(m_str).(f_names(k)) = ...
                                CLEAR_STATS.grid(rr(idx), cc(idx)).(daynight_flag).(m_str).(f_names(k)) + counts(rr(idx), cc(idx));
                        end
                    end
                end

                valid_b_mask = s_mask & ~isnan(b_idx);
                if any(valid_b_mask)
                    subs = [lat_idx_c(valid_b_mask), lon_idx_c(valid_b_mask), b_idx(valid_b_mask)];
                    counts_3d = accumarray(subs, 1, [nLat, nLon, num_bins]);
                    [rr, cc] = find(sum(counts_3d, 3) > 0);
                    for idx = 1:length(rr)
                        CLEAR_STATS.grid(rr(idx), cc(idx)).(daynight_flag).(m_str).count_vert_prof = ...
                            CLEAR_STATS.grid(rr(idx), cc(idx)).(daynight_flag).(m_str).count_vert_prof + squeeze(counts_3d(rr(idx), cc(idx), :));
                    end
                end
            end
        end
        fprintf('\n');

    catch ME
        fprintf('跳过(%s)\n', ME.message);
    end
end

save(fullfile(cache_dir, sprintf('CLEAR_AIR_STATS%s.mat', out_suffix)), 'CLEAR_STATS');
fprintf('  >> 已保存: %s\n\n', fullfile(cache_dir, sprintf('CLEAR_AIR_STATS%s.mat', out_suffix)));

    session_rerun(3) = true;
end

% ★ 更新本次运行 步骤③日志
cr = build_log.runs{end};
cr.steps{3}.name = '晴空像元统计';
cr.steps{3}.status = 'done';
cr.steps{3}.output = sprintf('CLEAR_AIR_STATS%s.mat', out_suffix);
cr.steps{3}.timestamp = datestr(now);
build_log.runs{end} = cr;
save(build_log_path, 'build_log');
fprintf('  >> 施工日志已保存（步骤③完成）: %s\n', build_log_path);

% =========================================================================
% 4. 绘图: Figure 5.1 — 全球绝对平均 Nd 地图
%    来源: figure_5_1.m
% =========================================================================
fprintf('============================================================\n');
fprintf('  绘图: Figure 5.1 - 全球绝对平均 Nd 地图\n');
fprintf('============================================================\n');

Target_DayNight = 'Day';
Target_Months   = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
Nd_State        = 'dry';
Alt_Limit_Num   = 10.0;

[nLat, nLon] = size(CALIPSO_STATS.grid);
Nd_map = nan(nLat, nLon, 7);
Total_Nd_map = nan(nLat, nLon);
target_var = sprintf('Nd_%s_OMCAM', Nd_State);

z_edges_p = 0:0.06:15.0;
z_centers = z_edges_p(1:end-1) + 0.03;
clear_alt_mask = (z_centers <= Alt_Limit_Num);

fprintf('  聚合 %d 个月数据, 高度上限 %.1f km...\n', length(Target_Months), Alt_Limit_Num);

% ★ 缓存检查：步骤④
[cache_run_id, step4_skip] = find_cached_run(build_log, 4, {}, session_rerun, auto_skip, date_start, date_end);

if ~step4_skip
    for i = 1:nLat
    if mod(i, 5) == 0, fprintf('    纬度 %d / %d\n', i, nLat); end
    for j = 1:nLon
        sum_Nd = zeros(1, 7);
        total_aerosol_samples = 0;
        clear_air_samples = 0;

        for mo_idx = 1:length(Target_Months)
            m_str = Target_Months{mo_idx};

            % 晴空本底
            try
                vert_prof = CLEAR_STATS.grid(i,j).(Target_DayNight).(m_str).count_vert_prof;
                clear_air_samples = clear_air_samples + sum(vert_prof(clear_alt_mask));
            catch, end

            % 气溶胶信号
            try
                mo_struct = CALIPSO_STATS.grid(i,j).(Target_DayNight).(m_str);
                for t = 1:7
                    tp = sprintf('Type%d', t);
                    if isfield(mo_struct, tp)
                        T_data = mo_struct.(tp).data;
                        try
                            vals   = T_data.(target_var);
                            h_vals = T_data.Height;
                            valid_mask = isfinite(vals) & (vals > 0) & (h_vals <= Alt_Limit_Num);
                            valid_vals = vals(valid_mask);
                            total_aerosol_samples = total_aerosol_samples + length(valid_vals);
                            sum_Nd(t) = sum_Nd(t) + sum(valid_vals);
                        catch, end
                    end
                end
            catch, end
        end

        true_total = total_aerosol_samples + clear_air_samples;
        if true_total > 0
            for t = 1:7
                Nd_map(i, j, t) = sum_Nd(t) / true_total;
            end
            Total_Nd_map(i, j) = sum(sum_Nd) / true_total;
        else
            Nd_map(i, j, :) = 0;
            Total_Nd_map(i, j) = 0;
        end
    end
end

% 4.2 绘图
log_cmin = 1;  log_cmax = 4;
type_names = {'(a) Marine', '(b) Dust', '(c) Polluted Cont.', ...
              '(d) Clean Cont.', '(e) Polluted Dust', '(f) Elevated Smoke', '(g) Dusty Marine'};

fig = figure('Name', 'Figure 5.1 - Global Absolute Mean Nd', 'Color', 'w', ...
             'Units', 'normalized', 'Position', [0.1 0.05 0.55 0.9]);
colormap(turbo);
t_layout = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for idx = 1:7
    nexttile;
    show_lon = (idx == 7);
    plot_smooth_map(Nd_map(:,:,idx), type_names{idx}, log_cmin, log_cmax, show_lon);
    drawnow;
end

nexttile;
plot_smooth_map(Total_Nd_map, '(h) Total Aerosol', log_cmin, log_cmax, true);
drawnow;

cb = colorbar;
cb.Layout.Tile = 'east';
caxis([log_cmin, log_cmax]);
tick_real_vals = [10, 30, 100, 300, 1000, 3000, 10000];
cb.Ticks = log10(tick_real_vals);
cb.TickLabels = {'10', '30', '100', '300', '1000', '3000', '10000'};
cb.Label.String = 'Absolute Mean N_{50} (cm^{-3})';
cb.Label.FontSize = 14;
cb.Label.FontWeight = 'bold';

sgtitle(sprintf('Global Absolute Mean Aerosol N_{50} (<%.1f km | %d Months Aggregated)', ...
        Alt_Limit_Num, length(Target_Months)), 'FontSize', 22, 'FontWeight', 'bold');

saveas(fig, fullfile(results_dir, 'Figure_5_1.png'));
fprintf('  >> 图片已保存: %s\n', fullfile(results_dir, 'Figure_5_1.png'));

    session_rerun(4) = true;
end

% ★ 更新本次运行 步骤④日志
cr = build_log.runs{end};
cr.steps{4}.name = '绘图Figure 5.1';
cr.steps{4}.status = 'done';
cr.steps{4}.output = 'Figure_5_1.png';
cr.steps{4}.timestamp = datestr(now);
build_log.runs{end} = cr;

% ★ 持久化施工日志
build_log.last_run = datestr(now);
save(build_log_path, 'build_log');
fprintf('  >> 施工日志已保存: %s\n', build_log_path);

fprintf('\n============================================================\n');
fprintf('  All done!\n');
fprintf('============================================================\n');


% =========================================================================
% 子函数: 查找历史缓存
% =========================================================================
function [cache_run_id, can_skip] = find_cached_run(build_log, step_id, current_files, session_rerun, auto_skip, date_start, date_end)
% 遍历 build_log.runs（从最新到最旧），找匹配的已完成运行
% 匹配规则：日期模式比 date_start/date_end，原始模式比 input_files
    can_skip = false;
    cache_run_id = '';

    n_runs = length(build_log.runs);
    if n_runs <= 1
        return;
    end

    for r = n_runs-1:-1:1
        run = build_log.runs{r};

        if ~strcmp(run.steps{step_id}.status, 'done')
            continue;
        end

        % 上游依赖被重跑了？
        dep_rerun = false;
        if step_id == 2 && session_rerun(1), dep_rerun = true; end
        if step_id == 4 && (session_rerun(2) || session_rerun(3)), dep_rerun = true; end
        if dep_rerun
            continue;
        end

        % === 判断是否匹配：日期模式 or 原始模式 ===
        has_match = false;
        if isfield(run, 'date_start') && ~isempty(run.date_start)
            % 历史 run 有日期 → 比日期
            if ~isempty(date_start)
                % 统一处理 date_end 为空的情况（单日）
                if isempty(date_end)
                    end_to_compare = date_start;
                else
                    end_to_compare = date_end;
                end
                if strcmp(run.date_start, date_start) && strcmp(run.date_end, end_to_compare)
                    has_match = true;
                end
            end
        else
            % 历史 run 无日期 → 比文件列表
            if ~isempty(current_files) && isequal(run.input_files, current_files)
                has_match = true;
            end
        end

        if ~has_match
            continue;
        end

        % 检查文件是否真的存在
        out_f = run.steps{step_id}.output;
        cache_path = fullfile(run.out_dir, run.id, 'cache', out_f);
        if ~isfile(cache_path)
            fprintf('  警告: %s 日志标记 done 但缓存文件缺失 (%s)\n', run.id, out_f);
            continue;
        end

        % 找到匹配！
        if auto_skip
            can_skip = true;
            cache_run_id = run.id;
            fprintf('  在 %s 中找到 %s 的缓存\n', run.id, run.steps{step_id}.name);
            return;
        else
            resp = input(sprintf('  在 %s 中找到步骤%d (%s) 的缓存，跳过？[Y/n]: ', ...
                run.id, step_id, run.steps{step_id}.name), 's');
            if (isempty(resp) || lower(resp(1)) == 'y')
                can_skip = true;
                cache_run_id = run.id;
                return;
            end
        end
    end
end

% =========================================================================
% 子函数: Robinson 投影地图 (来自 figure_5_1.m)
% =========================================================================
function plot_smooth_map(map_data, title_str, l_cmin, l_cmax, show_lon)
    lon_c = -177.5:5:177.5;
    lat_c = -87.5:5:87.5;
    lon_ext = [-180, lon_c, 180];
    lat_ext = [-90, lat_c, 90];

    data_ext = nan(length(lat_ext), length(lon_ext));
    data_ext(2:end-1, 2:end-1) = map_data;
    data_ext(2:end-1, 1)   = map_data(:, end);
    data_ext(2:end-1, end) = map_data(:, 1);
    data_ext(1, :)   = data_ext(2, :);
    data_ext(end, :) = data_ext(end-1, :);

    data_ext(data_ext <= 0) = NaN;
    log_data = log10(data_ext);
    [X, Y] = meshgrid(lon_ext, lat_ext);

    log_data(log_data < l_cmin) = l_cmin;
    log_data(log_data > l_cmax) = l_cmax;

    levels = linspace(l_cmin, l_cmax, 35);

    axesm('robinson', 'MapLatLimit', [-90 90], 'MapLonLimit', [-180 180]);
    set(gca, 'Visible', 'off');
    framem on; gridm on; plabel on;

    if show_lon
        mlabel on;
    else
        mlabel off;
    end

    setm(gca, 'MLabelLocation', 60, 'PLabelLocation', 30, ...
              'MLabelParallel', 'south', ...
              'GLineWidth', 0.5, 'GLineStyle', ':', 'GColor', [0.6 0.6 0.6], ...
              'FontName', 'Helvetica', 'FontSize', 9);

    contourfm(Y, X, log_data, levels, 'LineStyle', 'none'); hold on;
    load coastlines;
    plotm(coastlat, coastlon, 'Color', [0.2 0.2 0.2], 'LineWidth', 0.8);

    caxis([l_cmin, l_cmax]);
    title(title_str, 'FontWeight', 'bold', 'FontSize', 13, 'Visible', 'on');
    tightmap;
end
