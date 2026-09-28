% =========================================================================
% 脚本名称: Plot_7Panel_Spectra_SmartMatch_CALIPSO.m
% 核心功能: 
%   1. 完美适配 AERONET_CALIPSO_Column_Integrated_DB.mat 数据结构。
%   2. 智能寻优最佳匹配案例 (RMSE 最小化)。
%   3. 时空追踪器！精准提取并打印选定案例的“站点名称”与“具体时间”。
% =========================================================================
clc; clear; close all;

%% ================== 1. ⚙️ 全局操作面板 ==================
plot_parameter_env = getenv('CHAPTER4_PLOT_PARAMETER');
if isempty(plot_parameter_env)
    Plot_Parameter = 1; % 1 = dV/dlnr (体积谱), 2 = dN/dlnr (数浓度谱)
else
    Plot_Parameter = str2double(plot_parameter_env);
end

% 物理量级微调 (根据你实际数据的量级调整)
CALIPSO_Scale_Factor = 1; 
dN_Multiplier = 1e8; 

%% ================== 2. 数据准备 ==================
fprintf('📂 正在加载最新的柱积分数据库...\n');
chapter4_project_dir = getenv('CHAPTER4_PROJECT_DIR');
if isempty(chapter4_project_dir), chapter4_project_dir = pwd; end
column_input_file = getenv('CHAPTER4_COLUMN_INPUT_FILE');
if isempty(column_input_file), column_input_file = fullfile(chapter4_project_dir, 'AERONET_CALIPSO_Column_Integrated_DB.mat'); end
load(column_input_file, 'Column_DB');

try
    Radius = importdata(fullfile(chapter4_project_dir, 'result', 'AERONET_dVdlnr_R.mat'));
catch
    Radius = [0.05, 0.0656, 0.0861, 0.113, 0.148, 0.194, 0.255, 0.334, 0.439, ...
              0.576, 0.756, 0.992, 1.3, 1.71, 2.24, 2.94, 3.86, 5.06, 6.64, ...
              8.71, 11.4, 15];
end

type_names = {'Marine', 'Dust', 'Polluted Cont.', 'Clean Cont.', ...
              'Polluted Dust', 'Elevated Smoke', 'Dusty Marine'};
          
subplot_positions = [1, 2, 3, 4, 5, 6, 8]; 

if Plot_Parameter == 1
    param_str = 'dVdlnr';
    y_label_str = '\it{dV/d}\rm{ln}\it{r} \rm{(\mu m^3/\mu m^2)}';
else
    param_str = 'dNdlnr';
    y_label_str = '\it{dN/d}\rm{ln}\it{r} \rm{(cm^{-2})}'; 
end

%% ================== 3. 提取数据与【带追踪的智能寻优】 ==================
Plot_Data = struct();
fprintf('=========================================================================\n');
fprintf('🧠 智能寻优引擎启动 | 正在为您寻找 7 大类气溶胶的“天作之合”...\n');
fprintf('=========================================================================\n');
fprintf('%-16s | %-20s | %-20s | %s\n', 'Aerosol Type', 'Best Site (地点)', 'Time (时间)', 'RMSE');
fprintf('-------------------------------------------------------------------------\n');

for t = 1:7
    type_str = sprintf('Type%d', t);
    Pool_Aero = []; Pool_CALIPSO = [];
    Pool_Meta_Site = {}; Pool_Meta_Time = {}; % 元数据追踪池
    
    if isfield(Column_DB, type_str)
        sites = fieldnames(Column_DB.(type_str));
        for s = 1:length(sites)
            site_name = sites{s};
            
            % ★ 更新：对齐最新的 CALIPSO 字段名
            if Plot_Parameter == 1
                curr_aero = Column_DB.(type_str).(site_name).Aero_dV;
                curr_calipso = Column_DB.(type_str).(site_name).CALIPSO_dV;
            else
                curr_aero = Column_DB.(type_str).(site_name).Aero_dN;
                curr_calipso = Column_DB.(type_str).(site_name).CALIPSO_dN;
            end
            
            num_rows = size(curr_aero, 1);
            if num_rows == 0, continue; end
            
            % 提取时间标签
            time_data = strings(num_rows, 1);
            if isfield(Column_DB.(type_str).(site_name), 'Time')
                time_data = string(Column_DB.(type_str).(site_name).Time);
            elseif isfield(Column_DB.(type_str).(site_name), 'Date')
                time_data = string(Column_DB.(type_str).(site_name).Date);
            else
                time_data(:) = "Unknown_Time"; 
            end
            
            % 将数据并入大池子
            Pool_Aero = [Pool_Aero; curr_aero];
            Pool_CALIPSO = [Pool_CALIPSO; curr_calipso];
            
            % 将站点名和时间并入追踪池
            for row_idx = 1:num_rows
                Pool_Meta_Site{end+1, 1} = site_name;
                Pool_Meta_Time{end+1, 1} = time_data(row_idx);
            end
        end
    end
    
    num_cases = size(Pool_Aero, 1);
    Plot_Data(t).num_cases = num_cases;
    
    if num_cases > 0
        % 尺度放大
        Pool_CALIPSO = Pool_CALIPSO * CALIPSO_Scale_Factor;
        if Plot_Parameter == 2
            Pool_Aero = Pool_Aero * dN_Multiplier;
            Pool_CALIPSO = Pool_CALIPSO * dN_Multiplier;
        end
        
        % 核心寻优算法 (基于对数 RMSE 最小化)
        best_idx = 1;
        min_error = inf;
        
        for k = 1:num_cases
            curve_aero = Pool_Aero(k, :);
            curve_calipso = Pool_CALIPSO(k, :);
            
            valid_pts = (curve_aero > 0) & (curve_calipso > 0) & isfinite(curve_aero) & isfinite(curve_calipso);
            
            if sum(valid_pts) >= 5 
                log_aero = log10(curve_aero(valid_pts));
                log_calipso = log10(curve_calipso(valid_pts));
                current_error = sqrt(mean((log_aero - log_calipso).^2));
                
                if current_error < min_error
                    min_error = current_error;
                    best_idx = k;
                end
            end
        end
        
        % 打印最终找到的最佳案例的具体地点和时间
        best_site = Pool_Meta_Site{best_idx};
        best_time = Pool_Meta_Time{best_idx};
        
        fprintf('%-16s | %-20s | %-20s | %.4f\n', type_names{t}, best_site, best_time, min_error);
        
        % 提取用于绘图的数据
        Plot_Data(t).Aero = Pool_Aero(best_idx, :);
        Plot_Data(t).CALIPSO = Pool_CALIPSO(best_idx, :);
    else
        fprintf('%-16s | %-20s | %-20s | %s\n', type_names{t}, 'No Data', 'No Data', 'N/A');
    end
end
fprintf('=========================================================================\n');

%% ================== 4. 绘制 7-Panel 严格对齐图 ==================
fig = figure('Name', sprintf('7-Panel Best Match %s', param_str), ...
             'Color', 'w', 'Position', [50, 50, 1400, 900]);

for t = 1:7
    if Plot_Data(t).num_cases == 0
        subplot(3, 3, subplot_positions(t));
        title(sprintf('(%c) %s\n(No Data)', 96+t, type_names{t}), 'FontSize', 14, 'FontWeight', 'bold');
        axis off; continue;
    end
    
    plot_aero = Plot_Data(t).Aero;
    plot_calipso = Plot_Data(t).CALIPSO;
    
    plot_aero(plot_aero <= 0) = NaN;
    plot_calipso(plot_calipso <= 0) = NaN;
    
    ax = subplot(3, 3, subplot_positions(t));
    
    if Plot_Parameter == 1
        % 体积谱 dVdlnr 使用线性 Y 轴
        semilogx(Radius, plot_aero, '-o', 'Color', 'b', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'b'); hold on;
        semilogx(Radius, plot_calipso, '-s', 'Color', 'r', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        set(gca, 'YScale', 'linear');
        ylim([0, 0.05]); yticks([0, 0.01, 0.02, 0.03, 0.04, 0.05]);
    else
        % 数浓度谱 dNdlnr 使用对数 Y 轴
        loglog(Radius, plot_aero, '-o', 'Color', 'b', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'b'); hold on;
        loglog(Radius, plot_calipso, '-s', 'Color', 'r', 'LineWidth', 2.5, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
        set(gca, 'YScale', 'log');
        ylim([1e3, 5e9]); yticks([1e4, 1e6, 1e8]); yticklabels({'10^4', '10^6', '10^8'}); 
    end
       
    grid on;
    set(gca, 'XScale', 'log', 'XMinorGrid', 'on', 'YMinorGrid', 'on', 'GridAlpha', 0.4);
    set(gca, 'FontSize', 12, 'LineWidth', 1.2, 'Box', 'on', 'TickDir', 'in');
    
    xlim([0.05, 20]); xticks([1e-1, 1e0, 1e1]); xticklabels({'10^{-1}', '10^{0}', '10^{1}'});
    
    title(sprintf('(%c) %s', 96+t, type_names{t}), 'FontSize', 15, 'FontWeight', 'bold');
    
    if ismember(t, [4, 5, 6, 7]), xlabel('Radius (\mu m)', 'FontSize', 14, 'FontWeight', 'bold'); end
    if ismember(t, [1, 4, 7]), ylabel(y_label_str, 'FontSize', 14, 'FontWeight', 'bold'); end
    
    if t == 7 
        lgd_str_aero = sprintf('%s - AERONET', param_str);
        lgd_str_calipso = sprintf('%s - CALIPSO', param_str);
        lgd = legend(lgd_str_aero, lgd_str_calipso, 'FontSize', 12, 'FontWeight', 'bold');
        pos = get(gca, 'Position'); 
        lgd.Position = [pos(1) + pos(3) + 0.03, pos(2) + pos(4)/2 - 0.05, 0.1, 0.1];
        lgd.Box = 'on'; 
    end
end

sgtitle(sprintf('AERONET vs CALIPSO (%s) - Optimal Match Selection', param_str), ...
        'FontSize', 18, 'FontWeight', 'bold');

chapter4_fig_dir = getenv('CHAPTER4_FIG_DIR');
if ~isempty(chapter4_fig_dir)
    if ~isfolder(chapter4_fig_dir), mkdir(chapter4_fig_dir); end
    exportgraphics(fig, fullfile(chapter4_fig_dir, sprintf('Figure_4_%d.png', Plot_Parameter)), 'Resolution', 300);
end
