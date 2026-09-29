% =========================================================================
% 脚本名称: AERONET_CALIPSO_Collocation_FullSpectrum_Final.m
% 核心逻辑: 
%   1. 恢复完整微物理反演，精确输出 dVdlnr 和 dNdlnr 粒径谱！
%   2. 终极修复：根据解剖报告，精准对齐结构体内部的非对称变量名！
%   3. 完美适配 12-Month 独立存储架构。
% =========================================================================
clc; close all;
clearvars -except CALIPSO_STATS CLEAR_STATS
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(fileparts(script_dir));
prior_dir = fullfile(project_root, 'inputs', 'priors');
function_dir = fullfile(project_root, 'code', 'functions');
addpath(prior_dir);
addpath(function_dir);
%% ================== 1. 参数与前置数据加载 ==================
Dist_Thresh = 0.5;   
Time_Thresh = 0.3;   

fprintf('====================================================\n');
fprintf('     🛰️ CALIPSO - AERONET 终极全谱段微物理匹配引擎   \n');
fprintf('====================================================\n');

fprintf('⏳ 正在加载气溶胶微物理反演字典...\n');
try
    Radius = importdata(fullfile(prior_dir, 'AERONET_dVdlnr_R.mat'));
    Para_Particle = importdata(fullfile(prior_dir, 'Parameter_Particle_CALISPO.mat'));
    Extinction_Normalized = importdata(fullfile(prior_dir, 'Extinction_Normalized.mat'));
catch
    error('⚠️ 致命错误：找不到字典文件，请确保它们在当前路径下！');
end

Extinction_Normalized_All = zeros(6, length(Extinction_Normalized.CM(:,2)));
Extinction_Normalized_All(1,:) = Extinction_Normalized.CM(:,2)';
Extinction_Normalized_All(2,:) = Extinction_Normalized.DU(:,2)';
Extinction_Normalized_All(3,:) = Extinction_Normalized.PC(:,2)';
Extinction_Normalized_All(4,:) = Extinction_Normalized.CC(:,2)';
Extinction_Normalized_All(5,:) = Extinction_Normalized.PD(:,2)';
Extinction_Normalized_All(6,:) = Extinction_Normalized.SM(:,2)';

CALIPSO_mat_file  = getenv('CHAPTER4_CALIPSO_STATS_FILE');
if isempty(CALIPSO_mat_file), CALIPSO_mat_file = 'CALIPSO_STATS_Monthly.mat'; end
aeronet_file   = getenv('CHAPTER4_AERONET_FILE');
site_info_file = getenv('CHAPTER4_AERONET_SITE_INFO_FILE');
out_match_file = getenv('CHAPTER4_MATCH_OUTPUT_FILE');
if isempty(aeronet_file), aeronet_file = './result/20220501_20230631_AERONET_Data_INVL15.mat'; end
if isempty(site_info_file), site_info_file = './result/20220501_20230631_Site_Info_INV20.mat'; end
if isempty(out_match_file), out_match_file = 'AERONET_CALIPSO_Matched.mat'; end

if ~exist('CALIPSO_STATS', 'var')
    if ~isfile(CALIPSO_mat_file)
        error('Chapter4:MissingStats','CALIPSO_STATS file not found: %s',CALIPSO_mat_file);
    end
    fprintf('⏳ 正在加载 CALIPSO_STATS: %s\n',CALIPSO_mat_file);
    load(CALIPSO_mat_file, 'CALIPSO_STATS');
end

AERONET_Data = importdata(aeronet_file);
AERONET_Site_Info = importdata(site_info_file);
AERONET_Site_Name = AERONET_Site_Info.SiteName;
total_sites = length(AERONET_Site_Name);

Matched_DB = struct();
for t = 1:7
    Matched_DB.(sprintf('Type%d', t)) = struct();
end
type_match_counts = zeros(1, 7); 
months_list = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};
dn_strs = {'Day', 'Night'};
global_error_printed = false;

fprintf('🚀 数据库挂载完毕，开始执行主匹配与全谱段反演循环！\n');
fprintf('----------------------------------------------------\n');

%% ================== 2. 主循环：AERONET 站点匹配 ==================
for s = 1:total_sites
    site_name = AERONET_Site_Name{s};
    
    if ~isfield(AERONET_Data, site_name), continue; end
    site_data = AERONET_Data.(site_name);
    if isempty(site_data.time_UTC), continue; end
    
    site_lon = site_data.longitude(1);
    site_lat = site_data.latitude(1);
    
    fprintf('[%3d/%d] 📍 %-18s | 地基记录: %4d 条\n', s, total_sites, site_name, length(site_data.time_UTC));
    
    c_center = max(1, min(72, ceil((site_lon + 180) / 5)));
    r_center = max(1, min(36, ceil((site_lat + 90) / 5)));
    
    Pool = struct('Lat', [], 'Lon', [], 'Time', [], 'Ext', [], 'Bsc', [], 'Dep', [], 'RH', [], 'Type', []);
    
    for r = max(1, r_center-1) : min(36, r_center+1)
        for c = max(1, c_center-1) : min(72, c_center+1)
            for D = 1:2
                dn = dn_strs{D};
                for m_idx = 1:12
                    m_str = months_list{m_idx};
                    if isfield(CALIPSO_STATS.grid(r,c), dn) && isfield(CALIPSO_STATS.grid(r,c).(dn), m_str)
                        for t = 1:7
                            tp = sprintf('Type%d', t);
                            try
                                T_data = CALIPSO_STATS.grid(r,c).(dn).(m_str).(tp).data;
                                
                                lat = T_data.Lat; lon = T_data.Lon; time = T_data.Time;
                                ext = T_data.Extinction; bsc = T_data.Backscatter;
                                try dep = T_data.Depolarization_Ratio; catch, dep = T_data.Depolarization; end
                                try rh = T_data.ERA5_RH; catch, try rh = T_data.RH; catch, rh = repmat(50, height(T_data), 1); end; end
                                
                                if isdatetime(time), time = datenum(time); end
                                
                                valid_p = isfinite(ext) & (ext > 0) & isfinite(bsc) & (bsc > 0) & isfinite(dep) & (dep >= 0);
                                
                                if any(valid_p)
                                    Pool.Lat = [Pool.Lat; lat(valid_p)]; Pool.Lon = [Pool.Lon; lon(valid_p)];
                                    Pool.Time = [Pool.Time; time(valid_p)]; Pool.Ext = [Pool.Ext; ext(valid_p)];
                                    Pool.Bsc = [Pool.Bsc; bsc(valid_p)]; Pool.Dep = [Pool.Dep; dep(valid_p)];
                                    Pool.RH  = [Pool.RH; rh(valid_p)]; Pool.Type = [Pool.Type; repmat(t, sum(valid_p), 1)];
                                end
                            catch
                            end
                        end
                    end
                end
            end
        end
    end
    
    if isempty(Pool.Lat)
        fprintf('   -> ☁️ 附近 5x5° 网格无卫星覆盖\n');
        continue; 
    end
    
    site_total_matched_pixels = 0; 
    overlap_found = 0;
    
    for a_idx = 1:length(site_data.time_UTC)
        a_time_raw = site_data.time_UTC(a_idx);
        if isdatetime(a_time_raw), a_time = datenum(a_time_raw); else, a_time = double(a_time_raw); end
        
        a_dv = site_data.Size_Distribution(a_idx, :); 
        
        dist_array = sqrt((Pool.Lon - site_lon).^2 + (Pool.Lat - site_lat).^2);
        time_diff_array = abs(Pool.Time - a_time);
        
        valid_idx = find(dist_array < Dist_Thresh & time_diff_array < Time_Thresh);
        
        if ~isempty(valid_idx)
            overlap_found = overlap_found + length(valid_idx);
            matched_types = Pool.Type(valid_idx);
            unique_types = unique(matched_types);
            
            for ut_idx = 1:length(unique_types)
                curr_type = unique_types(ut_idx);
                type_str = sprintf('Type%d', curr_type);
                
                curr_valid_idx = valid_idx(matched_types == curr_type);
                num_pixels = length(curr_valid_idx); 
                
                Data_CALIPSO = struct();
                Data_CALIPSO.Out_ExtCoef_Particle = Pool.Ext(curr_valid_idx);
                Data_CALIPSO.Out_Backscatter_Coefficient = Pool.Bsc(curr_valid_idx);
                Data_CALIPSO.Out_Depolarization_Ratio = Pool.Dep(curr_valid_idx);
                Data_CALIPSO.Out_RH = Pool.RH(curr_valid_idx);
                Data_CALIPSO.Out_Type_Aer2 = Pool.Type(curr_valid_idx);
                
                try
                    Data_test = Fun_CALIPSO_Calculation_dVdlnr_dNdlnr_Nd_Consider_Hyg_Integral(...
                        Data_CALIPSO, Radius, Para_Particle, Extinction_Normalized_All, [], []);
                    
                    if ~isempty(Data_test)
            
                        CALIPSO_dv_matrix = reshape(Data_test.dVdlnr_wet_CALIPSO, num_pixels, length(Radius));
                        CALIPSO_dn_matrix = reshape(Data_test.dNdlnr_wet, num_pixels, length(Radius));
                        
                        if ~isfield(Matched_DB.(type_str), site_name)
                            Matched_DB.(type_str).(site_name).Aero_Time = [];
                            Matched_DB.(type_str).(site_name).Aero_dVdlnr = [];
                            Matched_DB.(type_str).(site_name).CALIPSO_Time = [];
                            Matched_DB.(type_str).(site_name).CALIPSO_dVdlnr = [];
                            Matched_DB.(type_str).(site_name).CALIPSO_dNdlnr = [];
                        end
                        
                        Matched_DB.(type_str).(site_name).Aero_Time = [Matched_DB.(type_str).(site_name).Aero_Time; repmat(a_time, num_pixels, 1)];
                        Matched_DB.(type_str).(site_name).Aero_dVdlnr = [Matched_DB.(type_str).(site_name).Aero_dVdlnr; repmat(a_dv, num_pixels, 1)];
                        Matched_DB.(type_str).(site_name).CALIPSO_Time = [Matched_DB.(type_str).(site_name).CALIPSO_Time; Pool.Time(curr_valid_idx)];
                        Matched_DB.(type_str).(site_name).CALIPSO_dVdlnr = [Matched_DB.(type_str).(site_name).CALIPSO_dVdlnr; CALIPSO_dv_matrix];
                        Matched_DB.(type_str).(site_name).CALIPSO_dNdlnr = [Matched_DB.(type_str).(site_name).CALIPSO_dNdlnr; CALIPSO_dn_matrix];
                        
                        type_match_counts(curr_type) = type_match_counts(curr_type) + num_pixels;
                        site_total_matched_pixels = site_total_matched_pixels + num_pixels;
                    end
                catch ME
                    if ~global_error_printed
                        fprintf(2, '\n🚨 [程序异常]: 报错信息: %s\n', ME.message);
                        global_error_printed = true;
                    end
                end
            end
        end
    end
    
    if site_total_matched_pixels > 0
        fprintf('   -> ✅ 成功！时空窗口内匹配并反演出 %d 条全谱段数据。\n', site_total_matched_pixels);
    elseif overlap_found > 0
        fprintf('   -> ⚠️ 发现 %d 个重合点，但反演被跳过 (请检查)。\n', overlap_found);
    else
        fprintf('   -> ❌ 无匹配：时空窗口内未对齐。\n');
    end
end

%% ================== 3. 保存结果 ==================
save(out_match_file, 'Matched_DB');
fprintf('\n====================================================\n');
fprintf('🎉 数据大满贯！12个月全谱段匹配完成！已保存至: %s\n', out_match_file);
for t = 1:7
    fprintf('▶ Type %d : %6d 条谱分布数据\n', t, type_match_counts(t));
end
