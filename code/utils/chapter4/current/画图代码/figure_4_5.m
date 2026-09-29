% =========================================================================
% Script: Plot_Grouped_Boxplot_NumberConcentration_Clean.m
% 核心修复: 
%   1. 【量级差距过滤】新增 Magnitude_Diff_Thresh，自动剔除星地相差过大的极端失效案例。
%   2. 强制提取实部 real() 并过滤 Inf/NaN，确保 boxchart 安全运行。
% =========================================================================
clc; clear; close all;

%% ================== 1. ⚙️ 全局参数与分类设置 ==================
dN_Multiplier = 1e8; 
CALIPSO_Scale_Factor = 1; 

% ★ 新增：极端量级差距拦截阈值 (例如 2.0 表示允许最大相差 10^2 = 100 倍)
Magnitude_Diff_Thresh = 2.0; 

type_names = {'Marine', 'Dust', 'Polluted Cont.', 'Clean Cont.', ...
              'Polluted Dust', 'Elevated Smoke', 'Dusty Marine'};

fprintf('📂 正在加载数据库并提取数浓度特征...\n');
chapter4_project_dir = getenv('CHAPTER4_PROJECT_DIR');
if isempty(chapter4_project_dir), chapter4_project_dir = pwd; end
column_input_file = getenv('CHAPTER4_COLUMN_INPUT_FILE');
if isempty(column_input_file), column_input_file = fullfile(chapter4_project_dir, 'AERONET_CALIPSO_Column_Integrated_DB.mat'); end
load(column_input_file, 'Column_DB');

Y_Total_N = [];       
X_AeroType = {};      
C_DataSource = {};    

total_pairs_before = 0;
total_pairs_after = 0;

%% ================== 2. 数据提取与积分计算 ==================
for t = 1:7
    type_str = sprintf('Type%d', t);
    if isfield(Column_DB, type_str)
        sites = fieldnames(Column_DB.(type_str));
        for s = 1:length(sites)
            site_name = sites{s};
            
            n_aero_matrix = Column_DB.(type_str).(site_name).Aero_dN * dN_Multiplier;
            n_CALIPSO_matrix = Column_DB.(type_str).(site_name).CALIPSO_dN * CALIPSO_Scale_Factor * dN_Multiplier;
            
            % 安全求和
            total_n_aero = sum(n_aero_matrix, 2, 'omitnan'); 
            total_n_CALIPSO = sum(n_CALIPSO_matrix, 2, 'omitnan');
            
            % 1. 基本有效性检查
            valid_idx = (total_n_aero > 0) & (total_n_CALIPSO > 0);
            total_pairs_before = total_pairs_before + sum(valid_idx);
            
            % =======================================================
            % ★ 核心修改：极端量级差距过滤 ★
            % =======================================================
            % 计算两者在对数空间下的绝对差异 (数量级差距)
            mag_diff = abs(log10(total_n_CALIPSO) - log10(total_n_aero));
            
            % 保留那些差距在阈值以内的数据对
            valid_idx = valid_idx & (mag_diff <= Magnitude_Diff_Thresh);
            % =======================================================
            
            if any(valid_idx)
                n_valid = sum(valid_idx);
                total_pairs_after = total_pairs_after + n_valid;
                
                Y_Total_N = [Y_Total_N; total_n_aero(valid_idx)];
                X_AeroType = [X_AeroType; repmat(type_names(t), n_valid, 1)];
                C_DataSource = [C_DataSource; repmat({'AERONET (Ground Truth)'}, n_valid, 1)];
                
                Y_Total_N = [Y_Total_N; total_n_CALIPSO(valid_idx)];
                X_AeroType = [X_AeroType; repmat(type_names(t), n_valid, 1)];
                C_DataSource = [C_DataSource; repmat({'CALIPSO (Retrieval)'}, n_valid, 1)];
            end
        end
    end
end

fprintf('🛡️ 量级异常清洗完成！\n');
fprintf('   - 清洗前原始配对数: %d\n', total_pairs_before);
fprintf('   - 剔除 %d 个相差超 %g 个数量级的极端案例\n', total_pairs_before - total_pairs_after, Magnitude_Diff_Thresh);
fprintf('   - 最终保留有效配对: %d\n', total_pairs_after);

% =======================================================
% 终极并行数据消杀 (防崩溃保障)
% =======================================================
Y_Total_N = real(Y_Total_N);
valid_final_idx = isfinite(Y_Total_N) & (Y_Total_N > 0);

Y_Total_N    = Y_Total_N(valid_final_idx);
X_AeroType   = X_AeroType(valid_final_idx);
C_DataSource = C_DataSource(valid_final_idx);

if isempty(Y_Total_N)
    error('🚨 错误：过滤后没有留下任何有效数据！可能是阈值设得太小。');
end

% 转换为 Categorical 类型
X_AeroType_Cat = categorical(X_AeroType, type_names, 'Ordinal', true);
C_DataSource_Cat = categorical(C_DataSource, {'AERONET (Ground Truth)', 'CALIPSO (Retrieval)'});

%% ================== 3. 绘制 SCI 分组箱线图 (Grouped Boxplot) ==================
fig = figure('Name', 'Number Concentration Boxplot', 'Color', 'w', 'Position', [150, 200, 1000, 550]);
ax = axes('Position', [0.1, 0.15, 0.85, 0.75]);
hold on;

% 绘制箱线图
b = boxchart(X_AeroType_Cat, Y_Total_N, 'GroupByColor', C_DataSource_Cat);

color_AERONET = [0.15, 0.45, 0.85]; 
color_CALIPSO    = [0.85, 0.25, 0.15]; 
colororder([color_AERONET; color_CALIPSO]);

b(1).BoxFaceAlpha = 0.6; 
b(2).BoxFaceAlpha = 0.6; 
b(1).MarkerStyle = '.'; b(1).MarkerSize = 6; b(1).MarkerColor = [0.4 0.4 0.4]; 
b(2).MarkerStyle = '.'; b(2).MarkerSize = 6; b(2).MarkerColor = [0.4 0.4 0.4]; 

% 对数坐标系
set(gca, 'YScale', 'log', 'Box', 'on', 'TickDir', 'in', 'LineWidth', 1.2, 'FontSize', 11);
set(gca, 'YGrid', 'on', 'GridLineStyle', '--', 'GridAlpha', 0.4);

% 自适应 Y 轴限制 (因为清除了极端值，现在的坐标系上下限会自动收紧，变得非常漂亮！)
min_y = min(Y_Total_N);
max_y = max(Y_Total_N);
ylim([10^(floor(log10(min_y))), 10^(ceil(log10(max_y)))]);

xlabel('Aerosol Subtypes', 'FontWeight', 'bold', 'FontSize', 13);
ylabel('Integrated Number Concentration (m^{-2})', 'FontWeight', 'bold', 'FontSize', 13);
title('Probability Density & Bias Analysis of Number Concentration', 'FontSize', 15, 'FontWeight', 'bold');

lgd = legend('Location', 'northeast');
set(lgd, 'FontSize', 11, 'Box', 'on', 'Color', 'w', 'EdgeColor', 'k');
title(lgd, 'Data Source'); 

fprintf('🎉 分组箱线图绘制成功！\n');
chapter4_fig_dir = getenv('CHAPTER4_FIG_DIR');
if ~isempty(chapter4_fig_dir)
    if ~isfolder(chapter4_fig_dir), mkdir(chapter4_fig_dir); end
    exportgraphics(fig, fullfile(chapter4_fig_dir, 'Figure_4_5.png'), 'Resolution', 300);
end
