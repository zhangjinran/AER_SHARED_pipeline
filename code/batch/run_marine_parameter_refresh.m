%RUN_MARINE_PARAMETER_REFRESH Rebuild parameter-dependent products and plots.
% Inputs are supplied through environment variables so the launcher is fully logged.
project = 'F:\AER_SHARED_PIPELINE';
run_root = getenv('MARINE_REFRESH_RUN_ROOT');
prior_root = getenv('MARINE_REFRESH_PRIOR_ROOT');
if isempty(run_root) || isempty(prior_root), error('MarineRefresh:Config','MARINE_REFRESH_RUN_ROOT/PRIOR_ROOT required'); end
addpath(fullfile(project,'code','functions'),'-begin');
addpath(fullfile(project,'code','config'),'-begin');
addpath(fullfile(project,'code','producers','calipso_stats'),'-begin');
addpath(fullfile(project,'code','producers','ccn_grid'),'-begin');
addpath(fullfile(project,'code','producers','chapter5'),'-begin');
clear build_calipso_stats build_ccn_grid_from_shared_tall build_calipso_stats_month build_ccn_grid_monthly_from_daily build_chapter5_map_stats_month;
addpath(fullfile(project,'plots','chapter5'),'-begin');
addpath(fullfile(project,'code','consumers','ccn'),'-begin');
stats_key='stats__ap-final-v1__era5-real__adapter-v1__qc-v1__stats-v1';
clear_key='clear__ap-final-v1__grid5deg__z60m__clear-v1';
tall_key='tall__ap-final-v1__era5-real__adapter-v1__qc-v1';
tall_root=fullfile(project,'products','tall','t_all',tall_key);
clear_root=fullfile(project,'products','chapter5','clear_air_stats',clear_key);
aroot='F:\AER_RETRA_CASE\areonet data\delivery\full_20070101_20221231_z05kmap_days';
aeronet_file=fullfile(aroot,'AERONET_Data_INVL15_20070101_20221231_Z05kmAP.mat');
site_file=fullfile(aroot,'AERONET_Site_Info_INV15_20070101_20221231_Z05kmAP.mat');
months=[1 2]; year_value=2007;
for m=months
    ym=sprintf('%04d%02d',year_value,m); fprintf('\n===== MARINE REFRESH %s =====\n',ym);
    month_root=fullfile(run_root,'intermediate',ym); stats_daily=fullfile(month_root,'calipso_stats_daily'); ccn_daily=fullfile(month_root,'ccn_daily');
    if ~isfolder(stats_daily),mkdir(stats_daily);end; if ~isfolder(ccn_daily),mkdir(ccn_daily);end
    dates=discover_dates(tall_root,clear_root,year_value,m);
    if isempty(dates), error('MarineRefresh:NoDates','No finalized daily T_all/CLEAR dates for %s',ym); end
    inv=fullfile(month_root,['date_inventory_' ym '.csv']); write_inventory(inv,dates);
    fprintf('DATES %s count=%d\n',ym,numel(dates));
    for k=1:numel(dates)
        d=dates(k); ymd=char(string(d,'yyyyMMdd')); yy=char(string(d,'yyyy')); mm=char(string(d,'MM')); dd=char(string(d,'dd'));
        tp=fullfile(tall_root,yy,mm,dd,['T_all_' ymd '.mat']);
        if ~isfile(tp), tp=fullfile(tall_root,yy,mm,dd,['T_all_' ymd '_final.mat']); end
        sp=fullfile(stats_daily,yy,mm,dd,['CALIPSO_STATS_' ymd '.mat']); cp=fullfile(ccn_daily,yy,mm,dd,['CCN_GRID_' ymd '.mat']);
        ensure_parent(sp); ensure_parent(cp);
        fprintf('DAY %d/%d %s\n',k,numel(dates),ymd);
        if ~isfile(sp) || ~isfile(fullfile(fileparts(sp),'_SUCCESS')), build_calipso_stats(tp,sp,'PriorRoot',prior_root); write_success(fileparts(sp),ymd,'marine-candidate-stats-v2'); else, fprintf('  STATS_ALREADY_READY %s\n',ymd); end
        if ~isfile(cp) || ~isfile(fullfile(fileparts(cp),'_SUCCESS')), build_ccn_grid_from_shared_tall(tp,cp,'PriorRoot',prior_root); write_success(fileparts(cp),ymd,'marine-candidate-ccn-v2'); else, fprintf('  CCN_ALREADY_READY %s\n',ymd); end
    end
    stats_month=fullfile(month_root,['CALIPSO_STATS_Monthly_' ym '_marine_v2.mat']);
    ccn_month=fullfile(month_root,['CCN_GRID_Monthly_' ym '_marine_v2.mat']);
    if ~isfile(stats_month), build_calipso_stats_month(year_value,m,stats_month,'InputRoot',stats_daily,'DateInventoryPath',inv); else, fprintf('  MONTHLY_STATS_ALREADY_READY %s\n',ym); end
    if ~isfile(ccn_month), build_ccn_grid_monthly_from_daily(year_value,m,ccn_month,inv,'InputRoot',ccn_daily); else, fprintf('  MONTHLY_CCN_ALREADY_READY %s\n',ym); end
    ch5_month=fullfile(month_root,['CHAPTER5_MAP_STATS_' ym '_marine_v2.mat']);
    if ~isfile(ch5_month), build_chapter5_map_stats_month(year_value,m,ch5_month,inv,'StatsRoot',stats_daily,'ClearRoot',clear_root); else, fprintf('  CHAPTER5_MONTH_ALREADY_READY %s\n',ym); end
    fig5=fullfile(run_root,'plots','chapter5',ym); if ~isfolder(fig5),mkdir(fig5);end
    setenv('CHAPTER5_MAP_STATS_INPUT',ch5_month); setenv('CHAPTER5_OUTPUT_DIR',fig5); setenv('CHAPTER5_PLOT_LABEL',[ym ' marine-v2']);
    run(fullfile(project,'plots','chapter5','plot_chapter5_map_stats.m'));
    figccn=fullfile(run_root,'plots','ccn',ym); if ~isfolder(figccn),mkdir(figccn);end
    plot_ccn_monthly_pretty(ccn_month,figccn,[ym ' marine-v2']);
    ch4=fullfile(run_root,'intermediate','chapter4',ym); if ~isfolder(ch4),mkdir(ch4);end
    run_chapter4_candidate_month(project,prior_root,stats_month,aeronet_file,site_file,ch4,ym);
    col=fullfile(ch4,['AERONET_CALIPSO_Column_Integrated_DB_' ym '_marine_v2.mat']);
    fig4=fullfile(run_root,'plots','chapter4',ym); if ~isfolder(fig4),mkdir(fig4);end
    setenv('CHAPTER4_PROJECT_DIR',run_root); setenv('CHAPTER4_COLUMN_INPUT_FILE',col); setenv('CHAPTER4_FIG_DIR',fig4); set(0,'DefaultFigureVisible','off');
    setenv('CHAPTER4_PLOT_PARAMETER','1'); run(fullfile(project,'code','consumers','chapter4','画图代码','figure_4_1and4_2.m'));
    setenv('CHAPTER4_PLOT_PARAMETER','2'); run(fullfile(project,'code','consumers','chapter4','画图代码','figure_4_1and4_2.m'));
    run(fullfile(project,'code','consumers','chapter4','画图代码','figure_4_3.m')); run(fullfile(project,'code','consumers','chapter4','画图代码','figure_4_4.m')); run(fullfile(project,'code','consumers','chapter4','画图代码','figure_4_5.m'));
    fprintf('MONTH_PASS %s\n',ym);
end
fprintf('MARINE_PARAMETER_REFRESH_PASS run=%s\n',run_root);

function dates=discover_dates(tall_root,clear_root,y,m)
    dates=datetime.empty(0,1); base=fullfile(tall_root,sprintf('%04d',y),sprintf('%02d',m)); ds=dir(fullfile(base,'*')); for i=1:numel(ds)
        if ~ds(i).isdir || isempty(regexp(ds(i).name,'^\d{2}$','once')),continue;end; dd=ds(i).name; d=datetime(y,m,str2double(dd));
        t=dir(fullfile(base,dd,'T_all_*.mat')); c=dir(fullfile(clear_root,sprintf('%04d',y),sprintf('%02d',m),dd,'CLEAR_AIR_STATS_*.mat'));
        if ~isempty(t)&&~isempty(c)&&isfile(fullfile(base,dd,'_SUCCESS'))&&isfile(fullfile(clear_root,sprintf('%04d',y),sprintf('%02d',m),dd,'_SUCCESS')),dates(end+1)=d;end
    end; dates=sort(dates);
end
function write_inventory(p,dates), fid=fopen(p,'w'); fprintf(fid,'Date,Status\n'); for i=1:numel(dates),fprintf(fid,'%s,ready\n',char(string(dates(i),'yyyy-MM-dd')));end; fclose(fid);end
function ensure_parent(p), d=fileparts(p); if ~isfolder(d),mkdir(d);end;end
function write_success(d,ymd,schema), fid=fopen(fullfile(d,'_SUCCESS'),'w'); fprintf(fid,'status=PASS\nproduct_date=%s\nschema=%s\n',ymd,schema); fclose(fid);end
