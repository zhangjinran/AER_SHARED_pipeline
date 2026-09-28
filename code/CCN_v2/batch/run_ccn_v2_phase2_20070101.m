function result = run_ccn_v2_phase2_20070101(run_root)
%RUN_CCN_V2_PHASE2_20070101 Execute frozen Phase-2 sample and one-day Gates.
if nargin<1||isempty(run_root),error('CCNv2:MissingRunRoot','Run root is required.');end
run_root=char(run_root); if ~isfolder(run_root),error('CCNv2:MissingRunRoot','Run root does not exist.');end
v2root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(v2root,'validation'),'-begin'); addpath(fullfile(v2root,'producers'),'-begin');
logdir=fullfile(run_root,'logs'); if ~isfolder(logdir),mkdir(logdir);end
diary(fullfile(logdir,'phase2_20070101_matlab.log')); cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('CCN_V2_PHASE2_START %s\n',datestr(now,31));
prior_root=fullfile(run_root,'staging','priors','assembled','omcam_v2_full_001','candidates');
sample_report=fullfile(run_root,'reports','sample_gate_v2.csv');
test_ccn_v2_sample_gate(prior_root,sample_report);
tall='F:\AER_SHARED_PIPELINE\products\tall\t_all\tall__ap-final-v1__era5-real__adapter-v1__qc-v1\2007\01\01\T_all_20070101.mat';
candidate=fullfile(run_root,'staging','day_20070101','ccn_grid_v2_day_001','CCN_GRID_V2_20070101.mat');
if ~isfile(candidate), build_ccn_grid_day_v2(tall,prior_root,candidate); end
day_report=fullfile(run_root,'reports','day_gate_20070101_v2.csv');
test_ccn_v2_day_gate(candidate,day_report);
result=struct('status','PASS','sample_report',sample_report,'candidate_path',candidate,'day_report',day_report);
disp(result); fprintf('CCN_V2_PHASE2_PASS %s\n',datestr(now,31));
end
