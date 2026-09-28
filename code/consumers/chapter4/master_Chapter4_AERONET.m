function master_Chapter4_AERONET(varargin)
%MASTER_CHAPTER4_AERONET Run the complete Chapter 4 pipeline and export figures.
%   Outputs are isolated under result/Chapter4, separate from Chapter 5.

    p = inputParser;
    addParameter(p, 'RebuildData', false, @(x) islogical(x) && isscalar(x));
    addParameter(p, 'Visible', false, @(x) islogical(x) && isscalar(x));
    parse(p, varargin{:});
    opt = p.Results;

    project_dir = fileparts(mfilename('fullpath'));
    data_dir = fullfile(project_dir, 'result', 'Chapter4', 'data');
    fig_dir = fullfile(project_dir, 'result', 'Chapter4', 'figures');
    if ~isfolder(data_dir), mkdir(data_dir); end
    if ~isfolder(fig_dir), mkdir(fig_dir); end

    old_dir = pwd;
    old_visible = get(groot, 'defaultFigureVisible');
    old_fig_env = getenv('CHAPTER4_FIG_DIR');
    old_param_env = getenv('CHAPTER4_PLOT_PARAMETER');
    old_project_env = getenv('CHAPTER4_PROJECT_DIR');
    cleanup = onCleanup(@() restore_state(old_dir, old_visible, old_fig_env, old_param_env, old_project_env)); %#ok<NASGU>
    cd(project_dir);
    setenv('CHAPTER4_FIG_DIR', fig_dir);
    setenv('CHAPTER4_PROJECT_DIR', project_dir);
    set(groot, 'defaultFigureVisible', ternary(opt.Visible, 'on', 'off'));

    matched_path = fullfile(project_dir, 'AERONET_CALIPSO_Matched.mat');
    column_path = fullfile(project_dir, 'AERONET_CALIPSO_Column_Integrated_DB.mat');
    if opt.RebuildData || ~isfile(matched_path) || ~isfile(column_path)
        fprintf('\n[Chapter 4] Step 1/2: AERONET-CALIPSO collocation\n');
        run_isolated(fullfile(project_dir, 'ARONET_CALIPSO_Fast_Collocation.m'));
        fprintf('\n[Chapter 4] Step 2/2: column integration\n');
        run_isolated(fullfile(project_dir, 'PostProcess_Column_Integration_OneToOne_Weighted_WithTime.m'));
    else
        fprintf('[Chapter 4] Reusing existing matched and column-integrated data.\n');
    end
    copyfile(matched_path, fullfile(data_dir, 'AERONET_CALIPSO_Matched.mat'));
    copyfile(column_path, fullfile(data_dir, 'AERONET_CALIPSO_Column_Integrated_DB.mat'));

    fprintf('[Chapter 4] Plotting Figure 4.1 (dV/dlnr)\n');
    setenv('CHAPTER4_PLOT_PARAMETER', '1');
    run_isolated(fullfile(project_dir, '画图代码', 'figure_4_1and4_2.m'));
    fprintf('[Chapter 4] Plotting Figure 4.2 (dN/dlnr)\n');
    setenv('CHAPTER4_PLOT_PARAMETER', '2');
    run_isolated(fullfile(project_dir, '画图代码', 'figure_4_1and4_2.m'));
    fprintf('[Chapter 4] Plotting Figure 4.3\n');
    run_isolated(fullfile(project_dir, '画图代码', 'figure_4_3.m'));
    fprintf('[Chapter 4] Plotting Figure 4.4\n');
    run_isolated(fullfile(project_dir, '画图代码', 'figure_4_4.m'));
    fprintf('[Chapter 4] Plotting Figure 4.5\n');
    run_isolated(fullfile(project_dir, '画图代码', 'figure_4_5.m'));

    close all force;
    fprintf('\nChapter 4 complete.\nData: %s\nFigures: %s\n', data_dir, fig_dir);
end

function run_isolated(script_path)
    run(script_path);
end

function restore_state(old_dir, old_visible, old_fig_env, old_param_env, old_project_env)
    cd(old_dir);
    set(groot, 'defaultFigureVisible', old_visible);
    setenv('CHAPTER4_FIG_DIR', old_fig_env);
    setenv('CHAPTER4_PLOT_PARAMETER', old_param_env);
    setenv('CHAPTER4_PROJECT_DIR', old_project_env);
end

function value = ternary(condition, yes, no)
    if condition, value = yes; else, value = no; end
end
