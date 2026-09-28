function result=run_ccn_v2_month(run_root,yyyymm)
%RUN_CCN_V2_MONTH Build/publish one month from formal T_all products only.
% Missing or unpublished T_all dates are recorded and skipped; no upstream data are rebuilt.
arguments
    run_root (1,:) char
    yyyymm (1,6) char
end
v2root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(v2root,'producers'),'-begin');
addpath(fullfile(v2root,'publishers'),'-begin');
addpath(fullfile(v2root,'validation'),'-begin');
addpath(fullfile(v2root,'config'),'-begin');
cfg=ccn_v2_config();

logdir=fullfile(run_root,'logs');if ~isfolder(logdir),mkdir(logdir);end
diary(fullfile(logdir,sprintf('ccn_v2_%s_matlab.log',yyyymm)));cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('CCN_V2_MONTH_START %s %s\n',yyyymm,datestr(now,31));
prior=fullfile(cfg.prior_root,'omcam_v2__acp-table4-unitgate-v1');
if ~isfolder(prior),error('CCNv2:MissingPrior','Formal OMCAM-v2 prior unavailable: %s',prior);end
troot=fullfile(cfg.project_root,'products','tall','t_all','tall__ap-final-v1__era5-real__adapter-v1__qc-v1',yyyymm(1:4),yyyymm(5:6));
days=eomday(str2double(yyyymm(1:4)),str2double(yyyymm(5:6)));
expected={};missing={};
for day=1:days
    ymd=sprintf('%s%02d',yyyymm,day);
    daydir=fullfile(troot,sprintf('%02d',day));
    tall=fullfile(daydir,sprintf('T_all_%s.mat',ymd));
    if ~isfile(tall) || ~isfile(fullfile(daydir,'_SUCCESS'))
        missing{end+1}=ymd;fprintf('MISSING_TALL %s\n',ymd);continue;
    end
    candidate=fullfile(run_root,'staging',sprintf('ccn_v2_%s',yyyymm),'daily',ymd,sprintf('CCN_GRID_V2_%s.mat',ymd));
    destdir=fullfile(cfg.day_product_root,cfg.product_key,ymd(1:4),ymd(5:6),ymd(7:8));
    if isfolder(destdir) && isfile(fullfile(destdir,'_SUCCESS'))
        expected{end+1}=ymd;fprintf('DAY_EXISTS %s\n',ymd);continue;
    elseif isfolder(destdir)
        error('CCNv2:IncompleteProduct','Refuse to reuse incomplete day product: %s',destdir);
    end
    if ~isfile(candidate),build_ccn_grid_day_v2(tall,prior,candidate);end
    test_ccn_v2_day_gate(candidate,fullfile(run_root,'reports',sprintf('day_gate_%s_v2.csv',ymd)));
    publish_ccn_grid_day_v2(candidate,tall,ymd);
    expected{end+1}=ymd;fprintf('DAY_PASS %s\n',ymd);
end
if isempty(expected),error('CCNv2:NoDays','No formal T_all dates available for %s.',yyyymm);end
month_candidate=fullfile(run_root,'staging',sprintf('ccn_v2_%s',yyyymm),'monthly',sprintf('CCN_GRID_V2_MONTH_%s.mat',yyyymm));
build_ccn_grid_month_v2(fullfile(cfg.day_product_root,cfg.product_key),yyyymm,month_candidate,expected);
dest=publish_ccn_grid_month_v2(month_candidate,yyyymm,expected);
result=struct('status','PASS','month_product',dest,'included_dates',{expected},'missing_tall_dates',{missing});
disp(result);fprintf('CCN_V2_MONTH_PASS %s %s\n',yyyymm,datestr(now,31));
end
