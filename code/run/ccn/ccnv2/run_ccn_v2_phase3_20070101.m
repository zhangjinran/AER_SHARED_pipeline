function result = run_ccn_v2_phase3_20070101(run_root)
%RUN_CCN_V2_PHASE3_20070101 Run frozen old/new diagnostic with a run diary.
run_root=char(run_root); if ~isfolder(run_root),error('CCNv2:MissingRunRoot','Run root is required.');end
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(code_root,'test','ccn','ccnv2'),'-begin');
logdir=fullfile(run_root,'logs'); if ~isfolder(logdir),mkdir(logdir);end
diary(fullfile(logdir,'phase3_20070101_matlab.log')); c=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('CCN_V2_PHASE3_START %s\n',datestr(now,31));
v2=fullfile(run_root,'staging','day_20070101','ccn_grid_v2_day_001','CCN_GRID_V2_20070101.mat');
legacy='F:\AER_SHARED_PIPELINE\products\ccn\ccn_grid\ccn__ap-final-v1__era5-real__grid5deg__ccn-v1\2007\01\01\CCN_GRID_20070101.mat';
result=compare_ccn_v2_vs_legacy_20070101(v2,legacy,fullfile(run_root,'reports'));
fprintf('CCN_V2_PHASE3_PASS %s\n',datestr(now,31));
end
