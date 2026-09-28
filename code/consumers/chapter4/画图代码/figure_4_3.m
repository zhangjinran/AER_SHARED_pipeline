% =========================================================================
% Script: Plot_Two_4x2_Scatter_Stats_NoTitle.m
% 核心修改:
%   1. 【去除大标题】移除了 sgtitle，完全贴合学术论文插图的规范。
%   2. 【动态散点密度】普通类型保留 200 个点防止糊图，"All Aerosol Types" 提升至 1000 个点展现总体分布！
% =========================================================================
clc; clear; close all;

%% ================== 1. ⚙️ 全局操作面板 ==================
CALIPSO_Scale_Factor = 1; 
dN_Multiplier = 1e8; 
type_names = {'Marine', 'Dust', 'Polluted Cont.', 'Clean Cont.', ...
              'Polluted Dust', 'Elevated Smoke', 'Dusty Marine'};
row_names = [type_names, {'All Aerosol Types'}];
cmap_7 = [0 0 1; 0 1 1; 0 1 0; 0.5 1 0; 1 1 0; 1 0.5 0; 1 0 0];

Max_Plot_Points = 400;       % 普通单一种类的最大散点数
Max_Plot_Points_All = 3000;  % ★ 新增：All Aerosol Types 的专属最大散点数
Outlier_Threshold = 4; 

%% ================== 2. 数据准备与提取 ==================
fprintf('📂 Loading Column Integrated DB...\n');
chapter4_project_dir = getenv('CHAPTER4_PROJECT_DIR');
if isempty(chapter4_project_dir), chapter4_project_dir = pwd; end
column_input_file = getenv('CHAPTER4_COLUMN_INPUT_FILE');
if isempty(column_input_file), column_input_file = fullfile(chapter4_project_dir, 'AERONET_CALIPSO_Column_Integrated_DB.mat'); end
load(column_input_file, 'Column_DB');
All_Data = struct();

for i = 1:8
    All_Data(i).dV_Aero = []; All_Data(i).dV_CALIPSO = [];
    All_Data(i).dN_Aero = []; All_Data(i).dN_CALIPSO = [];
    All_Data(i).Type_v  = []; All_Data(i).Type_n  = []; 
end

for t = 1:7
    type_str = sprintf('Type%d', t);
    if isfield(Column_DB, type_str)
        sites = fieldnames(Column_DB.(type_str));
        for s = 1:length(sites)
            site_name = sites{s};
            
            v_aero = Column_DB.(type_str).(site_name).Aero_dV(:);
            v_CALIPSO = Column_DB.(type_str).(site_name).CALIPSO_dV(:) * CALIPSO_Scale_Factor;
            n_aero = Column_DB.(type_str).(site_name).Aero_dN(:) * dN_Multiplier;
            n_CALIPSO = Column_DB.(type_str).(site_name).CALIPSO_dN(:) * CALIPSO_Scale_Factor * dN_Multiplier;
            
            valid_v = (v_aero > 0) & (v_CALIPSO > 0) & ~isnan(v_aero) & ~isnan(v_CALIPSO);
            valid_n = (n_aero > 0) & (n_CALIPSO > 0) & ~isnan(n_aero) & ~isnan(n_CALIPSO);
            
            All_Data(t).dV_Aero = [All_Data(t).dV_Aero; v_aero(valid_v)];
            All_Data(t).dV_CALIPSO = [All_Data(t).dV_CALIPSO; v_CALIPSO(valid_v)];
            All_Data(t).Type_v  = [All_Data(t).Type_v; repmat(t, sum(valid_v), 1)];
            
            All_Data(t).dN_Aero = [All_Data(t).dN_Aero; n_aero(valid_n)];
            All_Data(t).dN_CALIPSO = [All_Data(t).dN_CALIPSO; n_CALIPSO(valid_n)];
            All_Data(t).Type_n  = [All_Data(t).Type_n; repmat(t, sum(valid_n), 1)];
            
            All_Data(8).dV_Aero = [All_Data(8).dV_Aero; v_aero(valid_v)];
            All_Data(8).dV_CALIPSO = [All_Data(8).dV_CALIPSO; v_CALIPSO(valid_v)];
            All_Data(8).Type_v  = [All_Data(8).Type_v; repmat(t, sum(valid_v), 1)];
            
            All_Data(8).dN_Aero = [All_Data(8).dN_Aero; n_aero(valid_n)];
            All_Data(8).dN_CALIPSO = [All_Data(8).dN_CALIPSO; n_CALIPSO(valid_n)];
            All_Data(8).Type_n  = [All_Data(8).Type_n; repmat(t, sum(valid_n), 1)];
        end
    end
end

%% ================== 3. 核心双循环绘图逻辑 ==================
lims_dV = [1e-8, 1e0]; 
lims_dN = [1e-1, 1e9]; 
letters = char(97 + (0:15)); % a 到 p

for f = 1:2
    fig_name = sprintf('4x2 Scatter Stats Matrix - Part %d', f);
    fig = figure('Name', fig_name, 'Color', 'w', 'Position', [100 + (f-1)*50, 100, 900, 1100]);
    
    margin_top = 0.07;      
    margin_bottom = 0.07;   
    margin_left = 0.12;     
    margin_right = 0.12;    
    gap_x = 0.12;           
    gap_y = 0.065;          
    
    width_col = (1 - margin_left - margin_right - gap_x) / 2;
    height_row = (1 - margin_top - margin_bottom - 3*gap_y) / 4;
    type_offset = (f - 1) * 4; 
    
    for row = 1:4
        current_type_idx = type_offset + row; 
        
        for col = 1:2 
            pos_x = margin_left + (col-1)*(width_col + gap_x);
            pos_y = margin_bottom + (4-row)*(height_row + gap_y);
            ax = axes('Position', [pos_x, pos_y, width_col, height_row]);
            
            if col == 1
                x_data = All_Data(current_type_idx).dV_CALIPSO;
                y_data = All_Data(current_type_idx).dV_Aero;
                c_data = All_Data(current_type_idx).Type_v;
                curr_lims = lims_dV;
                is_dV = true;
            else
                x_data = All_Data(current_type_idx).dN_CALIPSO;
                y_data = All_Data(current_type_idx).dN_Aero;
                c_data = All_Data(current_type_idx).Type_n;
                curr_lims = lims_dN;
                is_dV = false;
            end
            
            % ★ 核心修改：动态分配允许绘制的最大点数
            if current_type_idx == 8
                current_max_points = Max_Plot_Points_All;
            else
                current_max_points = Max_Plot_Points;
            end
            
            if ~isempty(x_data)
                good_idx = abs(log10(x_data) - log10(y_data)) <= Outlier_Threshold;
                x_data = x_data(good_idx); y_data = y_data(good_idx); c_data = c_data(good_idx);
                
                % ★ 使用动态的最大点数进行随机抽稀
                if length(x_data) > current_max_points
                    rand_idx = randperm(length(x_data), current_max_points);
                    x_data = x_data(rand_idx); y_data = y_data(rand_idx); c_data = c_data(rand_idx);
                end
            end
            
            hold on; N_plot = length(x_data);
            if N_plot > 5 
                scatter(x_data, y_data, 15, c_data, 'filled', 'MarkerEdgeColor', 'none');
                colormap(ax, cmap_7); caxis([0.5, 7.5]); 
                
                log_x = log10(x_data); log_y = log10(y_data);
                p = polyfit(log_x, log_y, 1);
                corr_matrix = corrcoef(log_x, log_y);
                R_val = corr_matrix(1, 2);
                
                plot(curr_lims, curr_lims, 'k--', 'LineWidth', 1.5);
                x_fit = logspace(log10(curr_lims(1)), log10(curr_lims(2)), 100);
                plot(x_fit, 10.^(p(1)*log10(x_fit) + p(2)), 'r-', 'LineWidth', 2);
                
                stats_str = sprintf('y = %.2fx + %.2f\nR = %.3f', p(1), p(2), R_val);
                text(0.96, 0.05, stats_str, 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                     'VerticalAlignment', 'bottom', 'FontSize', 9, 'FontWeight', 'bold', 'BackgroundColor', 'none');
            else
                plot(curr_lims, curr_lims, 'k--', 'LineWidth', 1.5);
            end
            
            set(gca, 'XScale', 'log', 'YScale', 'log', 'Box', 'on', 'TickDir', 'in', ...
                     'XGrid', 'off', 'YGrid', 'off', 'XMinorGrid', 'off', 'YMinorGrid', 'off', ...
                     'LineWidth', 1.2, 'Color', 'w');
                     
            xlim(curr_lims); ylim(curr_lims);
            
            if is_dV
                set(gca, 'XTick', [1e-8, 1e-6, 1e-4, 1e-2, 1e0], 'YTick', [1e-8, 1e-6, 1e-4, 1e-2, 1e0], ...
                         'FontSize', 10, 'XTickLabelRotation', 0);
                ylabel(sprintf('dV/dlnr-AERO\n(\\mu m^3/\\mu m^2)'), 'FontSize', 10, 'FontWeight', 'bold');
            else
                set(gca, 'XTick', [1e-1, 1e1, 1e3, 1e5, 1e7, 1e9], 'YTick', [1e-1, 1e1, 1e3, 1e5, 1e7, 1e9], ...
                         'FontSize', 10, 'XTickLabelRotation', 0);
                ylabel(sprintf('dN/dlnr-AERO\n(m^{-2})'), 'FontSize', 10, 'FontWeight', 'bold');
            end
            
            if row < 4
                set(gca, 'XTickLabel', []);
            else
                if is_dV
                    xlabel('dV/dlnr-CALIPSO (\mu m^3/\mu m^2)', 'FontSize', 11, 'FontWeight', 'bold');
                else
                    xlabel('dN/dlnr-CALIPSO (m^{-2})', 'FontSize', 11, 'FontWeight', 'bold');
                end
            end
            
            global_letter_idx = (f-1)*8 + (row-1)*2 + col; 
            var_str = 'Volume'; if ~is_dV, var_str = 'Number'; end
            
            title_str = sprintf('(%c) %s: %s', letters(global_letter_idx), var_str, row_names{current_type_idx});
            text(0.0, 1.02, title_str, 'Units', 'normalized', 'HorizontalAlignment', 'left', ...
                 'VerticalAlignment', 'bottom', 'FontSize', 11, 'FontWeight', 'bold', 'BackgroundColor', 'none');
                 
            if row == 4 && col == 1
                h_scatter = scatter(NaN, NaN, 15, [0.6 0.8 0], 'filled'); 
                h_11 = plot(NaN, NaN, 'k--', 'LineWidth', 1.5);           
                h_reg = plot(NaN, NaN, 'r-', 'LineWidth', 2);             
                lgd1 = legend([h_scatter, h_11, h_reg], {'Data', '1:1', 'Reg'}, 'Location', 'northwest');
                set(lgd1, 'FontSize', 8, 'Box', 'on', 'Color', 'w');
                lgd1.ItemTokenSize = [10, 10];
            end
            
        end
    end
    
    cbar_ax = axes('Position', [1 - margin_right + 0.02, margin_bottom, 0.02, 1 - margin_top - margin_bottom], 'Visible', 'off');
    colormap(cbar_ax, cmap_7); caxis(cbar_ax, [0.5, 7.5]);
    cb = colorbar(cbar_ax, 'Position', [1 - margin_right + 0.02, margin_bottom, 0.02, 1 - margin_top - margin_bottom]);
    set(cb, 'Ticks', 1:7, 'TickLabels', type_names, 'FontSize', 10, 'TickDirection', 'out');
    cb.Label.String = 'Aerosol Types';
    cb.Label.FontWeight = 'bold'; cb.Label.FontSize = 11;

    chapter4_fig_dir = getenv('CHAPTER4_FIG_DIR');
    if ~isempty(chapter4_fig_dir)
        if ~isfolder(chapter4_fig_dir), mkdir(chapter4_fig_dir); end
        exportgraphics(fig, fullfile(chapter4_fig_dir, sprintf('Figure_4_3_Panel_%d.png', f)), 'Resolution', 300);
    end
end

fprintf('🎉 第二张图的 All Aerosol Types 已经成功扩容至 1000 个点！\n');
