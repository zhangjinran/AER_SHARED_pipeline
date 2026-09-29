function result=run_ccn_v2_phase4_200701(run_root)
%RUN_CCN_V2_PHASE4_200701 Build/publish all available January daily products then pooled month.
run_root=char(run_root);code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
v2root=fullfile(code_root,'utils','ccn','ccnv2');
addpath(fullfile(v2root,'producers'),'-begin');addpath(fullfile(v2root,'publishers'),'-begin');addpath(fullfile(code_root,'test','ccn','ccnv2'),'-begin');addpath(fullfile(v2root,'config'),'-begin');
logdir=fullfile(run_root,'logs');if ~isfolder(logdir),mkdir(logdir);end
diary(fullfile(logdir,'phase4_200701_matlab.log'));c=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('CCN_V2_PHASE4_START %s\n',datestr(now,31));
candidate_prior=fullfile(run_root,'staging','priors','assembled','omcam_v2_full_001','candidates');
prior=fullfile('F:\AER_SHARED_PIPELINE','inputs','priors','ccn_v2','omcam_v2__acp-table4-unitgate-v1');
if ~isfolder(prior),publish_ccn_v2_prior_input(candidate_prior);end
troot='F:\AER_SHARED_PIPELINE\products\tall\t_all\tall__ap-final-v1__era5-real__adapter-v1__qc-v1\2007\01';expected={};missing={};
for day=1:31
    ymd=sprintf('200701%02d',day);tall=fullfile(troot,sprintf('%02d',day),sprintf('T_all_%s.mat',ymd));
    if ~isfile(tall),missing{end+1}=ymd;fprintf('MISSING_TALL %s\n',ymd);continue;end
    candidate=fullfile(run_root,'staging','phase4_200701','daily',ymd,sprintf('CCN_GRID_V2_%s.mat',ymd));
    if strcmp(ymd,'20070101')
        phase2_candidate=fullfile(run_root,'staging','day_20070101','ccn_grid_v2_day_001','CCN_GRID_V2_20070101.mat');
        if isfile(phase2_candidate),candidate=phase2_candidate;end
    end
    if ~isfile(candidate),build_ccn_grid_day_v2(tall,prior,candidate);end
    test_ccn_v2_day_gate(candidate,fullfile(run_root,'reports',sprintf('day_gate_%s_v2.csv',ymd)));
    publish_ccn_grid_day_v2(candidate,tall,ymd);
    expected{end+1}=ymd;fprintf('DAY_PASS %s\n',ymd);
end
cfg=ccn_v2_config();
month_candidate=fullfile(run_root,'staging','phase4_200701','monthly','CCN_GRID_V2_MONTH_200701.mat');
build_ccn_grid_month_v2(fullfile(cfg.day_product_root,cfg.product_key),'200701',month_candidate,expected);
dest=publish_ccn_grid_month_v2(month_candidate,'200701',expected);
result=struct('status','PASS','month_product',dest,'included_dates',{expected},'missing_tall_dates',{missing});disp(result);
fprintf('CCN_V2_PHASE4_PASS %s\n',datestr(now,31));
end
