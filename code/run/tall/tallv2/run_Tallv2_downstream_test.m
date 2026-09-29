function run_Tallv2_downstream_test(stage)
root='F:/AER_SHARED_PIPELINE';cd(root);addpath(fullfile(root,'code','utils','shared','current'));addpath(fullfile(root,'code','utils','shared','common'));
tag='20070101_Tallv2';
tallroot=fullfile(root,'products','tall','t_all_v2','tall__ap-final-v1__era5-real__geotime-v2__qc-v1');
tall=fullfile(tallroot,'2007','01','01','T_all_20070101.mat');
assert(isfile(tall)&&isfile(fullfile(fileparts(tall),'_SUCCESS')),'Tallv2:Input','Formal corrected T_all missing.');
clearroot=fullfile(root,'products','chapter5','clear_air_stats_v2','clear__ap-final-v1__geotime-v2');
switch stage
 case 'clear'
  addpath(fullfile(root,'code','utils','chapter5','chapter5v2'));
  runroot=fullfile(root,'runs','produce','run_20070101_Tallv2_clear_001');mkdir_if(runroot);
  out=fullfile(runroot,['CLEAR_AIR_STATS_' tag '.mat']);
  final=fullfile(clearroot,'2007','01','01','CLEAR_AIR_STATS_20070101.mat');
  if isfile(fullfile(fileparts(final),'_SUCCESS')),fprintf('Tallv2_CLEAR_EXISTING\n');return;end
  if ~isfile(out),build_clear_air_stats_day('2007-01-01','Z:/CALIPSO_MAT_FINAL/CHAPTER5_AP/05kmAP/2007/2007_01_01.mat',out);end
  S=load_with_nas_retry(out,'CLEAR_STATS','processed_files');assert(S.processed_files==29&&isequal(size(S.CLEAR_STATS.grid),[36 72]),'Tallv2:Clear','Incomplete clear candidate.');clear S;
  publish_test_base(out,final,'clear__ap-final-v1__geotime-v2','Z:/CALIPSO_MAT_FINAL/CHAPTER5_AP/05kmAP/2007/2007_01_01.mat');
 case 'ccn'
  addpath(genpath(fullfile(root,'code','utils','ccn','ccnv2')));
  addpath(fullfile(root,'code','test','ccn','ccnv2'));
  runroot=fullfile(root,'runs','ccn',['run_' tag '_001']);mkdir_if(fullfile(runroot,'intermediate'));mkdir_if(fullfile(runroot,'reports'));
  out=fullfile(runroot,'intermediate',['CCN_GRID_' tag '.mat']);
  prior=fullfile(root,'inputs','priors','ccn_v2','omcam_v2__acp-table4-unitgate-v1');
  if ~isfile(out),build_ccn_grid_day_v2(tall,prior,out);end
  test_ccn_v2_day_gate(out,fullfile(runroot,'reports',['day_gate_' tag '.csv']));
  % Existing daily sums/counts have the same plotting interface; no duplicate MAT.
  plot_ccn_v2_monthly_diagnostics(out,fullfile(runroot,'plots'),'smooth_surface','2007-01-01 only | Tallv2');tag_outputs(fullfile(runroot,'plots'),tag);
 case 'chapter5'
  addpath(genpath(fullfile(root,'code','utils','chapter5','chapter5v2')));
  addpath(fullfile(root,'code','test','chapter5','chapter5v2'));
  runroot=fullfile(root,'runs','chapter5',['run_' tag '_001']);mkdir_if(fullfile(runroot,'reports'));
  daily=fullfile(runroot,'intermediate','day_20070101','stats_ch5_v2_day_Tallv2');mkdir_if(daily);
  out=fullfile(daily,['CALIPSO_STATS_CH5_V2_' tag '.mat']);
  if ~isfile(out),build_calipso_stats_ch5_v2_day(tall,out);end
  inv=table("2007-01-01","READY","Tallv2_single_day_test",'VariableNames',{'date','status','reason'});
  invpath=fullfile(runroot,'reports',['inventory_' tag '.csv']);writetable(inv,invpath);
  map=fullfile(runroot,'intermediate',['CHAPTER5_MAP_STATS_' tag '.mat']);
  if ~isfile(map),build_chapter5_map_stats_v2_month(2007,1,fullfile(runroot,'intermediate'),clearroot,invpath,map);end
  setenv('CHAPTER5_MAP_STATS_INPUT',map);setenv('CHAPTER5_OUTPUT_DIR',fullfile(runroot,'plots'));setenv('CHAPTER5_PLOT_LABEL','2007-01-01 only | Tallv2');
  isolated_script(fullfile(root,'plots','chapter5','plot_chapter5_map_stats.m'));tag_outputs(fullfile(runroot,'plots'),tag);
 case 'chapter4'
  setenv('CHAPTER4_RUN_ID',['run_' tag '_001']);setenv('CHAPTER4_YEAR','2007');setenv('CHAPTER4_MONTH','1');setenv('CHAPTER4_FILE_TAG',tag);
  setenv('CHAPTER4_TALL_ROOT',tallroot);setenv('CHAPTER4_TALL_DATES','20070101');
  isolated_script(fullfile(root,'code','run','chapter4','current','run_chapter4_month.m'));
  runroot=fullfile(root,'runs','chapter4',['run_' tag '_001']);tag_outputs(fullfile(runroot,'plots','chapter4'),tag);
 otherwise,error('Tallv2:Stage','Unknown stage');
end
fprintf('Tallv2_STAGE_COMPLETE %s\n',stage);
end
function isolated_script(p)
run(p);
end
function mkdir_if(p)
if ~isfolder(p),mkdir(p);end
end
function tag_outputs(p,tag)
f=dir(p);for k=1:numel(f)
 if f(k).isdir||contains(f(k).name,'Tallv2'),continue;end
 [~,s,e]=fileparts(f(k).name);dst=fullfile(p,[s '_' tag e]);assert(~isfile(dst));movefile(fullfile(p,f(k).name),dst);
end
end
function publish_test_base(src,dst,key,input)
folder=fileparts(dst);assert(~isfolder(folder),'Tallv2:Overwrite','Publication directory exists.');mkdir(folder);
info=dir(input);writetable(table(string(input),info.bytes,'VariableNames',{'path','bytes'}),fullfile(folder,'input_inventory.csv'));
fid=fopen(fullfile(folder,'manifest.txt'),'w');assert(fid>=0);fprintf(fid,'product_key=%s\ndate=2007-01-01\ngeolocation=native-profile-center-v2\nleapsecond_adjustment=not_applied_user_accepted\n',key);fclose(fid);
[ok,msg]=movefile(src,dst);assert(ok,'Tallv2:Move','%s',msg);
fid=fopen(fullfile(folder,'_SUCCESS'),'w');assert(fid>=0);fprintf(fid,'PASS\n');fclose(fid);
end
