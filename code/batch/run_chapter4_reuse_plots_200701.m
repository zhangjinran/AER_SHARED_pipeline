restoredefaultpath; rehash toolboxcache;
addpath('F:\AER_SHARED_PIPELINE\code\consumers\chapter4','-begin'); addpath('F:\AER_SHARED_PIPELINE\code\functions','-begin');
setenv('CHAPTER4_CODE_ROOT','F:\AER_SHARED_PIPELINE\code'); setenv('CHAPTER4_PROJECT_DIR','F:\AER_SHARED_PIPELINE\runs\produce\run_200701_month_004'); setenv('CHAPTER4_COLUMN_INPUT_FILE','F:\AER_SHARED_PIPELINE\runs\chapter4\run_200701_month_001\intermediate\chapter4_baseline_200701_formal\AERONET_CALIPSO_Column_Integrated_DB_200701.mat'); setenv('CHAPTER4_FIG_DIR','F:\AER_SHARED_PIPELINE\runs\produce\run_200701_month_004\plots\chapter4'); set(0,'DefaultFigureVisible','off');
setenv('CHAPTER4_PLOT_PARAMETER','1'); run('F:\AER_SHARED_PIPELINE\code\consumers\chapter4\画图代码\figure_4_1and4_2.m');
setenv('CHAPTER4_PLOT_PARAMETER','2'); run('F:\AER_SHARED_PIPELINE\code\consumers\chapter4\画图代码\figure_4_1and4_2.m');
run('F:\AER_SHARED_PIPELINE\code\consumers\chapter4\画图代码\figure_4_3.m'); run('F:\AER_SHARED_PIPELINE\code\consumers\chapter4\画图代码\figure_4_4.m'); run('F:\AER_SHARED_PIPELINE\code\consumers\chapter4\画图代码\figure_4_5.m'); fprintf('CHAPTER4_REUSE_PLOTS_PASS\n');
