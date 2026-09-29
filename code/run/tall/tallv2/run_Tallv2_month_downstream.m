function run_Tallv2_month_downstream(stage)
% January 2007: immutable Tallv2 daily inputs -> CCN, Chapter 5, Chapter 4.
root='F:/AER_SHARED_PIPELINE';cd(root);
addpath(fullfile(root,'code','utils','shared','current'));
base=fullfile(root,'runs','produce','run_200701_Tallv2_base_001');
invpath=fullfile(base,'date_inventory_Tallv2.csv');
inv=readtable(invpath,'TextType','string');
if isdatetime(inv.date)
 inv.date=string(inv.date,'yyyy-MM-dd');
else
 inv.date=string(inv.date);
end
assert(height(inv)==31&&nnz(inv.status=="READY")==30&&nnz(inv.status~="READY")==1,'Tallv2:Inventory','Unexpected frozen coverage.');
assert(inv.date(16)=="2007-01-16"&&inv.status(16)=="MISSING_APRO",'Tallv2:Inventory','Missing date changed.');
ready=inv(inv.status=="READY",:);ymd=cellstr(erase(ready.date,'-'));
troot=fullfile(root,'products','tall','t_all_v2','tall__ap-final-v1__era5-real__geotime-v2__qc-v1');
clearroot=fullfile(root,'products','chapter5','clear_air_stats_v2','clear__ap-final-v1__geotime-v2');
for q=1:numel(ymd)
 d=ymd{q};tall=fullfile(troot,d(1:4),d(5:6),d(7:8),['T_all_' d '.mat']);
 clr=fullfile(clearroot,d(1:4),d(5:6),d(7:8),['CLEAR_AIR_STATS_' d '.mat']);
 assert(formal(tall)&&formal(clr),'Tallv2:Base','Incomplete daily pair %s',d);
end
setenv('CCN_V2_PRODUCT_KEY','ccnv2__tall-v2-geotime__era5-rh__omcam-v2__grid2x5-z60');
setenv('CHAPTER5_V2_STATS_PRODUCT_KEY','stats-ch5v2__tall-v2-geotime__era5-rh__omcam-v2__grid5deg__stats-v2');
setenv('CHAPTER5_V2_MAP_PRODUCT_KEY','ch5map__stats-ch5v2-tall-v2-geotime__clear-v2__grid5deg__z10km__map-v2');
setenv('CHAPTER5_V2_CLEAR_PRODUCT_KEY','clear__ap-final-v1__geotime-v2');
switch stage
 case 'ccn',run_ccn(root,troot,ymd);
 case 'chapter5',run_ch5(root,troot,clearroot,inv,ymd);
 case 'chapter4',run_ch4(root,troot,ymd);
 otherwise,error('Tallv2:Stage','Unknown stage %s',stage);
end
fprintf('TALLV2_MONTH_DOWNSTREAM_COMPLETE %s\n',stage);
end
function run_ccn(root,troot,ymd)
v2=fullfile(root,'code','utils','ccn','ccnv2');addpath(genpath(v2));addpath(fullfile(root,'code','test','ccn','ccnv2'));cfg=ccn_v2_config();
runroot=fullfile(root,'runs','ccn','run_200701_Tallv2_001');
prior=fullfile(cfg.prior_root,'omcam_v2__acp-table4-unitgate-v1');
dayroot=fullfile(cfg.day_product_root,cfg.product_key);
for q=1:numel(ymd)
 d=ymd{q};tall=fullfile(troot,d(1:4),d(5:6),d(7:8),['T_all_' d '.mat']);
 dest=fullfile(dayroot,d(1:4),d(5:6),d(7:8),['CCN_GRID_V2_' d '.mat']);
 if formal(dest),fprintf('TALLV2_CCN_DAY_REUSED %s\n',d);continue;end
 assert(~isfolder(fileparts(dest)),'Tallv2:Partial','Incomplete day folder %s',fileparts(dest));
 candidate=fullfile(runroot,'staging','daily',d,['CCN_GRID_V2_' d '.mat']);
 if ~isfile(candidate),build_ccn_grid_day_v2(tall,prior,candidate);end
 gate=fullfile(runroot,'reports',['day_gate_' d '_Tallv2.csv']);make_dir(fileparts(gate));
 test_ccn_v2_day_gate(candidate,gate);
 publish_ccn_grid_day_v2(candidate,tall,d);
 fprintf('TALLV2_CCN_DAY_PASS %d/%d %s\n',q,numel(ymd),d);
end
monthly=fullfile(cfg.month_product_root,cfg.product_key,'2007','01','CCN_GRID_V2_MONTH_200701.mat');
if ~formal(monthly)
 assert(~isfolder(fileparts(monthly)),'Tallv2:Partial','Incomplete month folder.');
 candidate=fullfile(runroot,'staging','monthly','CCN_GRID_V2_MONTH_200701.mat');
 if ~isfile(candidate),build_ccn_grid_month_v2(dayroot,'200701',candidate,ymd);end
 S=load(candidate,'meta','sum_component','sum_total','sample_count');
 assert(isequal(string(S.meta.included_dates(:)),string(ymd(:)))&&isequal(size(S.sum_component),[90 72 133 5 3])&&...
  isequal(size(S.sum_total),[90 72 133 3])&&isequal(size(S.sample_count),[90 72 133]),'Tallv2:CCNMonthGate','Bad month schema or dates.');
 clear S
 publish_ccn_grid_month_v2(candidate,'200701',ymd);
end
plotdir=fullfile(runroot,'plots','ccn_v2','200701');
outputs=plot_ccn_v2_monthly_diagnostics(monthly,plotdir,'smooth_surface','2007-01 | Tallv2');
disp(outputs);fprintf('TALLV2_CCN_MONTH_PLOTS_PASS\n');
end
function run_ch5(root,troot,clearroot,inv,ymd)
v2=fullfile(root,'code','utils','chapter5','chapter5v2');addpath(genpath(v2));addpath(fullfile(root,'code','test','chapter5','chapter5v2'));addpath(fullfile(root,'code','utils','shared','common'));
cfg=chapter5_v2_config();runroot=fullfile(root,'runs','chapter5','run_200701_Tallv2_001');
staging=fullfile(runroot,'staging');make_dir(staging);
dailyroot=cfg.stats_product_root;
for q=1:numel(ymd)
 d=ymd{q};tall=fullfile(troot,d(1:4),d(5:6),d(7:8),['T_all_' d '.mat']);
 dest=fullfile(dailyroot,d(1:4),d(5:6),d(7:8),['CALIPSO_STATS_CH5_V2_' d '.mat']);
 if formal(dest),fprintf('TALLV2_CH5_DAY_REUSED %s\n',d);continue;end
 assert(~isfolder(fileparts(dest)),'Tallv2:Partial','Incomplete Chapter5 day folder %s',fileparts(dest));
 candidate=fullfile(staging,['day_' d],'stats_ch5_v2_day_Tallv2',['CALIPSO_STATS_CH5_V2_' d '.mat']);
 if ~isfile(candidate),build_calipso_stats_ch5_v2_day(tall,candidate);end
 gate=fullfile(runroot,'reports','day_gates',['day_' d '_gate.csv']);make_dir(fileparts(gate));
 test_chapter5_v2_day_gate(candidate,gate);
 fprintf('TALLV2_CH5_DAY_GATE_PASS %d/%d %s\n',q,numel(ymd),d);
end
frozen=fullfile(runroot,'date_inventory_200701_Tallv2.csv');
if ~isfile(frozen),writetable(inv,frozen);end
monthly=fullfile(cfg.map_product_root,'2007','01','CHAPTER5_MAP_STATS_V2_200701.mat');
if ~formal(monthly)
 assert(~isfolder(fileparts(monthly)),'Tallv2:Partial','Incomplete Chapter5 month folder.');
 candidate=fullfile(staging,'month_200701','CHAPTER5_MAP_STATS_V2_200701.mat');
 if ~isfile(candidate),build_chapter5_map_stats_v2_month(2007,1,staging,clearroot,frozen,candidate);end
 S=load(candidate,'CHAPTER5_MAP_STATS_V2');X=S.CHAPTER5_MAP_STATS_V2;
 assert(numel(X.processed_dates)==30&&numel(X.missing_dates)==1&&...
  isequal(string(X.processed_dates(:)),inv.date(inv.status=="READY"))&&...
  isequal(size(X.nd_sum),[36 72 2 7])&&all(isfinite(X.nd_sum(:)))&&all(X.nd_sum(:)>=0)&&...
  all(X.aerosol_count(:)>=0)&&all(X.clear_count(:)>=0),'Tallv2:CH5MonthGate','Month coverage/schema invalid.');
 clear S X
 for q=1:numel(ymd)
  d=ymd{q};dest=fullfile(dailyroot,d(1:4),d(5:6),d(7:8),['CALIPSO_STATS_CH5_V2_' d '.mat']);
  if formal(dest),continue;end
  candidate_day=fullfile(staging,['day_' d],'stats_ch5_v2_day_Tallv2',['CALIPSO_STATS_CH5_V2_' d '.mat']);
  gate=fullfile(runroot,'reports','day_gates',['day_' d '_gate.csv']);
  publish_calipso_stats_ch5_v2_day([d(1:4) '-' d(5:6) '-' d(7:8)],candidate_day,gate);
  fprintf('TALLV2_CH5_DAY_PUBLISHED %d/%d %s\n',q,numel(ymd),d);
 end
 publish_chapter5_map_stats_v2_month(2007,1,candidate,frozen);
end
setenv('CHAPTER5_MAP_STATS_INPUT',monthly);
setenv('CHAPTER5_OUTPUT_DIR',fullfile(runroot,'plots','chapter5','monthly'));
setenv('CHAPTER5_PLOT_LABEL','2007-01 | Tallv2');
isolated_script(fullfile(root,'plots','chapter5','plot_chapter5_map_stats.m'));
fprintf('TALLV2_CH5_MONTH_PLOTS_PASS\n');
end
function run_ch4(root,troot,ymd)
setenv('CHAPTER4_RUN_ID','run_200701_Tallv2_001');
setenv('CHAPTER4_YEAR','2007');setenv('CHAPTER4_MONTH','1');
setenv('CHAPTER4_FILE_TAG','200701_Tallv2');
setenv('CHAPTER4_TALL_ROOT',troot);setenv('CHAPTER4_TALL_DATES',strjoin(ymd,','));
isolated_script(fullfile(root,'code','run','chapter4','current','run_chapter4_month.m'));
fprintf('TALLV2_CH4_MONTH_PLOTS_PASS\n');
end
function isolated_script(p)
run(p);
end
function yes=formal(p)
dirpath=fileparts(p);yes=isfile(p)&&isfile(fullfile(dirpath,'_SUCCESS'))&&...
 isfile(fullfile(dirpath,'manifest.txt'))&&isfile(fullfile(dirpath,'input_inventory.csv'));
if yes,info=dir(p);yes=info.bytes>0;end
end
function make_dir(p)
if ~isfolder(p),mkdir(p);end
end
