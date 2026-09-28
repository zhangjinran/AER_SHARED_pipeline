% =========================================================================
% 脚本名称: PostProcess_Column_Integration_OneToOne_Weighted_CALIPSO.m
% 核心逻辑: 
%   1. 完美对接最新的全谱段数据库 (AERONET_CALIPSO_Matched_FullSpectrum.mat)。
%   2. ★ 核心升级：利用球形体积公式 (V = 4/3*pi*r^3) 将 AERONET dV 物理转换为 dN！
%   3. 执行 50km 区域融合，沿垂直方向对卫星粒径谱进行列积分。
%   4. 输出 1V1 的终极散点对比矩阵，包含同步的时间戳。
% =========================================================================
clc; clear; close all;
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(fileparts(script_dir)));
prior_dir = fullfile(project_root, 'inputs', 'priors');

%% ================== 1. 参数与基础物理量设置 ==================
Delta_Z_meters = 60; 
Dz_Factor = Delta_Z_meters * 1e-6; 

% ★ 新增：为了将 AERONET dV 转换为 dN，我们需要粒径网格 (Radius)
try
    Radius = importdata(fullfile(prior_dir, 'AERONET_dVdlnr_R.mat'));
catch
    Radius = [0.05, 0.0656, 0.0861, 0.113, 0.148, 0.194, 0.255, 0.334, 0.439, ...
              0.576, 0.756, 0.992, 1.3, 1.71, 2.24, 2.94, 3.86, 5.06, 6.64, ...
              8.71, 11.4, 15];
end
% 计算 AERONET 22个粒径网格对应的“单个球形颗粒体积”
% 公式: V = 4/3 * pi * r^3
Particle_Volume = (4/3) * pi * (Radius.^3); 

fprintf('📂 正在加载最新的全谱段散点匹配数据库...\n');
matched_input_file = getenv('CHAPTER4_MATCH_INPUT_FILE');
if isempty(matched_input_file), matched_input_file = 'AERONET_CALIPSO_Matched.mat'; end
column_output_file = getenv('CHAPTER4_COLUMN_OUTPUT_FILE');
if isempty(column_output_file), column_output_file = 'AERONET_CALIPSO_Column_Integrated_DB.mat'; end
load(matched_input_file, 'Matched_DB');

Column_DB = struct();
for t = 1:7
    Column_DB.(sprintf('Type%d', t)) = struct();
end
matched_observations_count = zeros(1, 7);

%% ================== 2. 数据重组与加权融合主循环 ==================
fprintf('🚀 启动区域融合：执行谱分布垂直列积分，并物理推算 AERONET dN...\n');
all_sites = {};
for t = 1:7
    type_str = sprintf('Type%d', t);
    if isfield(Matched_DB, type_str)
        all_sites = [all_sites; fieldnames(Matched_DB.(type_str))];
    end
end
all_sites = unique(all_sites);

for s = 1:length(all_sites)
    site_name = all_sites{s};
    
    site_pool = struct('Aero_Time', [], 'CALIPSO_Time', [], 'Type', [], 'CALIPSO_dV', [], 'CALIPSO_dN', [], 'Aero_dV', [], 'Aero_dN', []);
    
    for t = 1:7
        type_str = sprintf('Type%d', t);
        if isfield(Matched_DB.(type_str), site_name)
            data = Matched_DB.(type_str).(site_name);
            num_pts = length(data.CALIPSO_Time);
            
            if num_pts > 0
                site_pool.Aero_Time    = [site_pool.Aero_Time; data.Aero_Time]; 
                site_pool.CALIPSO_Time = [site_pool.CALIPSO_Time; data.CALIPSO_Time];
                site_pool.Type         = [site_pool.Type; repmat(t, num_pts, 1)];
                
                site_pool.CALIPSO_dV   = [site_pool.CALIPSO_dV; data.CALIPSO_dVdlnr];
                site_pool.CALIPSO_dN   = [site_pool.CALIPSO_dN; data.CALIPSO_dNdlnr];
                
                % ========================================================
                % ★ 破除 NaN 的核心转换：
                % 取出 AERONET 官方原始的体积谱 dV
                curr_aero_dv = data.Aero_dVdlnr; 
                site_pool.Aero_dV = [site_pool.Aero_dV; curr_aero_dv];
                
                % 使用物理公式，把体积除以单颗粒体积，算出 dN (利用 MATLAB 隐式扩展)
                curr_aero_dn = curr_aero_dv ./ Particle_Volume;
                site_pool.Aero_dN = [site_pool.Aero_dN; curr_aero_dn];
                % ========================================================
            end
        end
    end
    
    if isempty(site_pool.Aero_Time), continue; end
    unique_aero_times = unique(site_pool.Aero_Time);
    
    for v = 1:length(unique_aero_times)
        curr_aero_time = unique_aero_times(v);
        region_idx = find(site_pool.Aero_Time == curr_aero_time);
        
        types_in_region = site_pool.Type(region_idx);
        pixel_loadings = sum(site_pool.CALIPSO_dV(region_idx, :), 2, 'omitnan'); 
        
        unique_types_here = unique(types_in_region);
        type_total_loadings = zeros(size(unique_types_here));
        for ut = 1:length(unique_types_here)
            type_mask = (types_in_region == unique_types_here(ut));
            type_total_loadings(ut) = sum(pixel_loadings(type_mask), 'omitnan');
        end
        [~, max_load_idx] = max(type_total_loadings);
        regional_dominant_type = unique_types_here(max_load_idx);
        
        unique_profiles_in_region = unique(site_pool.CALIPSO_Time(region_idx));
        num_profiles = length(unique_profiles_in_region);
        
        prof_col_dv_matrix = zeros(num_profiles, size(site_pool.CALIPSO_dV, 2));
        prof_col_dn_matrix = zeros(num_profiles, size(site_pool.CALIPSO_dN, 2));
        prof_weights       = zeros(num_profiles, 1);
        
        for p = 1:num_profiles
            p_time = unique_profiles_in_region(p);
            p_idx = region_idx(site_pool.CALIPSO_Time(region_idx) == p_time);
            
            p_dv_spectrum = sum(site_pool.CALIPSO_dV(p_idx, :), 1, 'omitnan') * Dz_Factor;
            p_dn_spectrum = sum(site_pool.CALIPSO_dN(p_idx, :), 1, 'omitnan') * Dz_Factor;
            p_weight = sum(p_dv_spectrum, 'omitnan'); 
            
            prof_col_dv_matrix(p, :) = p_dv_spectrum;
            prof_col_dn_matrix(p, :) = p_dn_spectrum;
            prof_weights(p)          = p_weight;
        end
        
        if sum(prof_weights, 'omitnan') > 0
            prof_weights_norm = prof_weights ./ sum(prof_weights, 'omitnan');
        else
            prof_weights_norm = ones(num_profiles, 1) / num_profiles;
        end
        
        regional_calipso_dv = sum(prof_col_dv_matrix .* prof_weights_norm, 1, 'omitnan');
        regional_calipso_dn = sum(prof_col_dn_matrix .* prof_weights_norm, 1, 'omitnan');
        
        aero_dv = site_pool.Aero_dV(region_idx(1), :);
        aero_dn = site_pool.Aero_dN(region_idx(1), :); % 现在这里装的都是算出来的真实 dN！
        
        dom_type_str = sprintf('Type%d', regional_dominant_type);
        if ~isfield(Column_DB.(dom_type_str), site_name)
            Column_DB.(dom_type_str).(site_name).Aero_dV = [];
            Column_DB.(dom_type_str).(site_name).Aero_dN = [];
            Column_DB.(dom_type_str).(site_name).CALIPSO_dV = [];
            Column_DB.(dom_type_str).(site_name).CALIPSO_dN = [];
            Column_DB.(dom_type_str).(site_name).Time = []; 
        end
        
        Column_DB.(dom_type_str).(site_name).Aero_dV = [Column_DB.(dom_type_str).(site_name).Aero_dV; aero_dv];
        Column_DB.(dom_type_str).(site_name).Aero_dN = [Column_DB.(dom_type_str).(site_name).Aero_dN; aero_dn];
        Column_DB.(dom_type_str).(site_name).CALIPSO_dV = [Column_DB.(dom_type_str).(site_name).CALIPSO_dV; regional_calipso_dv];
        Column_DB.(dom_type_str).(site_name).CALIPSO_dN = [Column_DB.(dom_type_str).(site_name).CALIPSO_dN; regional_calipso_dn];
        
        Column_DB.(dom_type_str).(site_name).Time = [Column_DB.(dom_type_str).(site_name).Time; string(datestr(curr_aero_time, 'yyyy-mm-dd HH:MM'))];
        
        matched_observations_count(regional_dominant_type) = matched_observations_count(regional_dominant_type) + 1;
    end
end

%% ================== 3. 保存最终成果 ==================
save(column_output_file, 'Column_DB');
fprintf('\n🎉 完美！AERONET dN 已成功通过球形物理公式推算完毕！\n');
fprintf('结果已保存至: %s\n', column_output_file);
fprintf('============== 各类型最终有效对比点数 ==============\n');
type_names = {'1.Marine', '2.Dust', '3.Polluted Cont.', '4.Clean Cont.', '5.Polluted Dust', '6.Elevated Smoke', '7.Dusty Marine'};
for t = 1:7
    fprintf('▶ %-18s: %6d 个\n', type_names{t}, matched_observations_count(t));
end
fprintf('=======================================================\n');
