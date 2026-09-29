function run_Tallv2_base_month(year_value,month_value)
% Frozen monthly inventory; corrected T_all + global APro clear-air pair.
% Existing formal days are reused. Publication moves candidates, never copies.
root=fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));cd(root);
addpath(fullfile(root,'code','utils','shared','current'));addpath(fullfile(root,'code','utils','shared','config'));
addpath(fullfile(root,'code','utils','tall','tallv2'));
addpath(fullfile(root,'code','test','tall','tallv2'));
addpath(fullfile(root,'code','utils','chapter5','chapter5v2'));
cfg=data_roots();ym=sprintf('%04d%02d',year_value,month_value);
rr=fullfile(root,'runs','produce',['run_' ym '_Tallv2_base_001']);
if ~isfolder(rr),mkdir(rr);end
invpath=fullfile(rr,'date_inventory_Tallv2.csv');
if ~isfile(invpath)
 dates=(datetime(year_value,month_value,1):caldays(1):dateshift(datetime(year_value,month_value,1),'end','month'))';
 date=string(dates,'yyyy-MM-dd');status=repmat("READY",numel(dates),1);reason=strings(numel(dates),1);
 for k=1:numel(dates)
  raw=fullfile(cfg.CALIPSO_AP_ROOT,sprintf('%04d',year_value),[char(string(dates(k),'yyyy_MM_dd')) '.mat']);
  era=fullfile(cfg.ERA5_MAT_ROOT,sprintf('%04d',year_value),sprintf('%02d',month_value),char(string(dates(k),'dd')));
  % Check directory accessibility before classifying absence; NAS errors abort.
  assert(isfolder(fileparts(raw))&&isfolder(fileparts(era)),'Tallv2:NAS','Input parent inaccessible.');
  for attempt=1:3
   rawok=isfile(raw);hours=dir(fullfile(era,'*.mat'));
   if rawok&&numel(hours)>=24,break;end
   if attempt<3,pause(2);end
  end
  if ~rawok,status(k)="MISSING_APRO";reason(k)="global APro daily MAT absent";
  elseif numel(hours)<24,status(k)="MISSING_ERA5";reason(k)="fewer than 24 hourly MAT files";end
 end
 writetable(table(date,status,reason),invpath);
end
inv=readtable(invpath,'TextType','string');
fprintf('TALLV2_MONTH_FROZEN READY=%d MISSING=%d inventory=%s\n',nnz(inv.status=="READY"),nnz(inv.status~="READY"),invpath);
tk='tall__ap-final-v1__era5-real__geotime-v2__qc-v1';ck='clear__ap-final-v1__geotime-v2';
tr=fullfile(root,'products','tall','t_all_v2',tk);
cr=fullfile(root,'products','chapter5','clear_air_stats_v2',ck);
for k=1:height(inv)
 if inv.status(k)~="READY",fprintf('TALLV2_SKIP %s %s\n',inv.date(k),inv.status(k));continue;end
 d=datetime(inv.date(k),'InputFormat','yyyy-MM-dd');ymd=char(string(d,'yyyyMMdd'));ds=char(inv.date(k));
 parts={char(string(d,'yyyy')),char(string(d,'MM')),char(string(d,'dd'))};
 tall=fullfile(tr,parts{:},['T_all_' ymd '.mat']);clr=fullfile(cr,parts{:},['CLEAR_AIR_STATS_' ymd '.mat']);
 raw=fullfile(cfg.CALIPSO_AP_ROOT,parts{1},[char(string(d,'yyyy_MM_dd')) '.mat']);
 era=fullfile(cfg.ERA5_MAT_ROOT,parts{:});
 fprintf('TALLV2_DAY_START %s\n',ds);
 if ~published(tall)
  attemptroot=fullfile(rr,'staging',['day_' ymd]);
  if ~isfolder(attemptroot),mkdir(attemptroot);end
  rebuild_tall_geotime_day(ds,attemptroot);
  candidate=fullfile(attemptroot,'candidate_era5_real',ymd,['CALIPSO_results_' char(string(d,'yyyy_MM_dd')) '_mat.mat']);
  publish(candidate,tall,tk,ds,{raw;era});
 end
 if ~published(clr)
  out=fullfile(rr,'staging',['CLEAR_AIR_STATS_' ymd '_Tallv2.mat']);
  build_clear_air_stats_day(ds,raw,out);
  S=load_with_nas_retry(out,'CLEAR_STATS','processed_files');
  R=load_with_nas_retry(raw,'day');
  assert(S.processed_files==numel(R.day.files)&&isequal(size(S.CLEAR_STATS.grid),[36 72]),'Tallv2:ClearGate','Incomplete orbit coverage.');
  clear S R
  publish(out,clr,ck,ds,{raw});
 end
 assert(published(tall)&&published(clr),'Tallv2:PairGate','Daily pair incomplete.');
 fprintf('TALLV2_DAY_PAIR_PASS %s\n',ds);
end
fprintf('TALLV2_MONTH_BASE_COMPLETE %s READY=%d MISSING=%d\n',ym,nnz(inv.status=="READY"),nnz(inv.status~="READY"));
end
function yes=published(p)
folder=fileparts(p);yes=isfile(fullfile(folder,'_SUCCESS'));
if yes
 info=dir(p);assert(~isempty(info)&&info.bytes>0&&isfile(fullfile(folder,'manifest.txt'))&&isfile(fullfile(folder,'input_inventory.csv')),'Tallv2:Contract','Broken formal contract: %s',folder);
elseif isfolder(folder)
 error('Tallv2:PartialPublication','Inspect incomplete formal directory: %s',folder);
end
end
function publish(src,dst,key,date,inputs)
assert(isfile(src)&&~isfolder(fileparts(dst)),'Tallv2:Publish','Source missing or destination exists.');
mkdir(fileparts(dst));
writetable(table(string(inputs),'VariableNames',{'path'}),fullfile(fileparts(dst),'input_inventory.csv'));
fid=fopen(fullfile(fileparts(dst),'manifest.txt'),'w');assert(fid>=0);
fprintf(fid,'product_key=%s\ndate=%s\ngeolocation=native-profile-center-v2\nleapsecond_adjustment=not_applied_user_accepted\nstatus=PASS\n',key,date);fclose(fid);
[ok,msg]=movefile(src,dst);assert(ok,'Tallv2:Move','%s',msg);
fid=fopen(fullfile(fileparts(dst),'_SUCCESS'),'w');assert(fid>=0);fprintf(fid,'PASS\n');fclose(fid);
fprintf('TALLV2_PUBLISHED %s\n',dst);
end
