function run_chapter5_n50_column_month(year_value,month_value,run_root)
% One-month Chapter5 type-specific number-column workflow.
if nargin<3 || isempty(run_root), error('CH5ColumnMonth:RunRoot','Pass a unique run_root.'); end
first=datetime(year_value,month_value,1); ndays=day(dateshift(first,'end','month'));
code_dir=fileparts(fileparts(fileparts(mfilename('fullpath')))); project_root=fileparts(code_dir);
addpath(fullfile(code_dir,'config'),'-begin');
addpath(fullfile(code_dir,'Chapter5_v2','config'),'-begin');
addpath(fullfile(code_dir,'Chapter5_v2','n50_column'),'-begin');
addpath(fullfile(project_root,'plots','common'),'-begin');
roots=data_roots(); cfg=chapter5_v2_config();
stats_root=fullfile(project_root,'products','chapter5','calipso_stats_chapter5_v2',cfg.stats_product_key);
daily_key='ch5-number-column__stats-ch5v2__omcam-v2__grid5deg__z0-10km-v1';
month_key='ch5-number-column__stats-ch5v2__omcam-v2__grid5deg__z0-10km-month-pooled-v1';
daily_root=fullfile(project_root,'products','chapter5','chapter5_n50_column',daily_key);
month_root=fullfile(project_root,'products','chapter5','chapter5_n50_column',month_key);
log_dir=fullfile(run_root,'logs','chapter5_n50_column'); plot_dir=fullfile(run_root,'chapter5','plots');
if ~isfolder(log_dir),mkdir(log_dir);end; if ~isfolder(plot_dir),mkdir(plot_dir);end
log_path=fullfile(log_dir,sprintf('n50_column_%04d%02d_month_matlab.log',year_value,month_value));
if isfile(log_path),error('CH5ColumnMonth:NoOverwrite','Refusing to overwrite %s',log_path);end
diary(log_path); diary_cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('CH5_COLUMN_MONTH_START period=%04d-%02d run=%s\n',year_value,month_value,run_root);

dates=strings(ndays,1); stats=strings(ndays,1); ap=strings(ndays,1); products=strings(ndays,1);
status=strings(ndays,1); reason=strings(ndays,1);
for d=1:ndays
    dt=first+caldays(d-1); dates(d)=string(dt,'yyyy-MM-dd'); ymd=char(string(dt,'yyyyMMdd'));
    stats(d)=fullfile(stats_root,datestr(dt,'yyyy'),datestr(dt,'mm'),datestr(dt,'dd'),['CALIPSO_STATS_CH5_V2_' ymd '.mat']);
    ap(d)=fullfile(roots.CALIPSO_AP_ROOT,datestr(dt,'yyyy'),[datestr(dt,'yyyy_mm_dd') '.mat']);
    products(d)=fullfile(daily_root,datestr(dt,'yyyy'),datestr(dt,'mm'),datestr(dt,'dd'),['N50_COLUMN_CH5_V2_' ymd '.mat']);
    if isfile(stats(d)) && isfile(fullfile(fileparts(stats(d)),'_SUCCESS')) && isfile(ap(d))
        status(d)="READY"; reason(d)="";
    else
        status(d)="MISSING_INPUT"; missing=strings(0,1);
        if ~isfile(stats(d)) || ~isfile(fullfile(fileparts(stats(d)),'_SUCCESS')),missing(end+1)="chapter5v2_stats";end %#ok<AGROW>
        if ~isfile(ap(d)),missing(end+1)="global_ap_day_mat";end %#ok<AGROW>
        reason(d)=strjoin(missing,"+");
    end
end
inventory=table(dates,status,reason,stats,ap,products,'VariableNames', ...
    {'date','status','reason','stats_path','global_ap_path','column_product_path'});
run_inventory=fullfile(run_root,'chapter5','frozen_month_inventory.csv');
if isfile(run_inventory),error('CH5ColumnMonth:NoOverwrite','Frozen inventory exists: %s',run_inventory);end
writetable(inventory,run_inventory); fprintf('CH5_COLUMN_MONTH_INVENTORY ready=%d missing=%d\n',nnz(status=="READY"),nnz(status=="MISSING_INPUT"));
status_path=fullfile(run_root,'chapter5','daily_status.csv'); writetable(inventory,status_path);

for d=1:ndays
    if status(d)=="MISSING_INPUT"
        fprintf('CH5_COLUMN_DAY_SKIP date=%s reason=%s\n',dates(d),reason(d)); continue
    end
    pdir=fileparts(products(d));
    if isfile(products(d)) && isfile(fullfile(pdir,'manifest.txt')) && isfile(fullfile(pdir,'input_inventory.csv')) && isfile(fullfile(pdir,'_SUCCESS'))
        Q=builtin('load',products(d),'N50_COLUMN_CH5_V2'); X=Q.N50_COLUMN_CH5_V2;
        if ~strcmp(X.meta.product_key,daily_key) || ~strcmp(X.meta.date,char(dates(d)))
            error('CH5ColumnMonth:ExistingProductMismatch','Existing product contract mismatch: %s',products(d));
        end
        status(d)="EXISTING_PASS"; reason(d)="reused_no_rebuild";
        fprintf('CH5_COLUMN_DAY_REUSE date=%s\n',dates(d));
        inventory.status(d)=status(d); inventory.reason(d)=reason(d); writetable(inventory,status_path); continue
    elseif isfolder(pdir)
        error('CH5ColumnMonth:IncompleteProduct','Refusing to overwrite incomplete daily product: %s',pdir);
    end
    try
        mkdir(pdir); build_chapter5_type_number_column_day(char(stats(d)),char(ap(d)),char(products(d)));
        Q=builtin('load',products(d),'N50_COLUMN_CH5_V2'); X=Q.N50_COLUMN_CH5_V2;
        assert(strcmp(X.meta.date,char(dates(d))) && X.meta.unmatched_height_rows_below_10km==0 && X.meta.duplicate_profile_height_rows==0);
        ds=dir(stats(d)); da=dir(ap(d)); invd=table(string({'CHAPTER5_STATS';'GLOBAL_AP_METADATA'}),[stats(d);ap(d)], ...
            [uint64(ds.bytes);uint64(da.bytes)],'VariableNames',{'role','path','bytes'});
        writetable(invd,fullfile(pdir,'input_inventory.csv'));
        fid=fopen(fullfile(pdir,'manifest.txt'),'w'); fprintf(fid,'product_type=CHAPTER5_TYPE_NUMBER_COLUMN\nproduct_key=%s\nstatus=TEST_CANDIDATE_PASS\ndate=%s\ngrid=5x5deg\naltitude_km=0_to_10\nunits=cm-2\n',daily_key,dates(d));
        fprintf(fid,'Type5=dust_N100+PC_N50_within_original_sample\nType7=dust_N100+marine_N50_within_original_sample\n'); fclose(fid);
        fid=fopen(fullfile(pdir,'_SUCCESS'),'w'); fprintf(fid,'status=TEST_CANDIDATE_PASS\ndate=%s\n',dates(d)); fclose(fid);
        status(d)="GENERATED_PASS"; reason(d)=""; inventory.status(d)=status(d); inventory.reason(d)=reason(d);
        writetable(inventory,status_path);
        fprintf('CH5_COLUMN_DAY_PASS date=%s profiles=%d\n',dates(d),sum(X.profile_count(:)));
    catch ME
        status(d)="FAILED"; reason(d)=string(ME.identifier)+":"+string(ME.message); inventory.status(d)=status(d); inventory.reason(d)=reason(d); writetable(inventory,status_path);
        fprintf(2,'CH5_COLUMN_DAY_FAIL date=%s id=%s message=%s\n%s\n',dates(d),ME.identifier,ME.message,getReport(ME,'extended','hyperlinks','off'));
        rethrow(ME);
    end
end

ready=status=="EXISTING_PASS" | status=="GENERATED_PASS";
if nnz(ready)~=nnz(status=="READY" | status=="EXISTING_PASS" | status=="GENERATED_PASS")
    error('CH5ColumnMonth:DailyGate','Not all frozen READY dates passed.');
end
ready_dates=dates(ready); ready_products=products(ready);
month_mat=fullfile(month_root,datestr(first,'yyyy'),datestr(first,'mm'),sprintf('N50_COLUMN_CH5_V2_%04d%02d.mat',year_value,month_value));
month_dir=fileparts(month_mat); if isfolder(month_dir),error('CH5ColumnMonth:NoOverwrite','Monthly product exists: %s',month_dir);end; mkdir(month_dir);
aggregate_chapter5_type_number_column_month(cellstr(ready_products),ready_dates,month_mat);
Q=builtin('load',month_mat,'N50_COLUMN_CH5_V2'); X=Q.N50_COLUMN_CH5_V2;
X.meta.missing_dates=dates(status=="MISSING_INPUT"); X.meta.frozen_inventory=run_inventory; X.meta.ready_days=numel(ready_dates);
N50_COLUMN_CH5_V2=X; save(month_mat,'N50_COLUMN_CH5_V2','-v7.3'); writetable(inventory,fullfile(month_dir,'input_inventory.csv'));
fid=fopen(fullfile(month_dir,'manifest.txt'),'w'); fprintf(fid,'product_type=CHAPTER5_TYPE_NUMBER_COLUMN_MONTH\nproduct_key=%s\nstatus=TEST_CANDIDATE_PASS\nperiod=%04d-%02d\nready_days=%d\nmissing_days=%d\naggregation=pooled_daily_sum_divided_by_pooled_profile_count\nunits=cm-2\n',month_key,year_value,month_value,numel(ready_dates),nnz(status=="MISSING_INPUT")); fclose(fid);
plot_path=plot_chapter5_type_number_column_day(month_mat,plot_dir,sprintf('Figure_N50_Column_%04d%02d.png',year_value,month_value));
fid=fopen(fullfile(month_dir,'_SUCCESS'),'w'); fprintf(fid,'status=TEST_CANDIDATE_PASS\nperiod=%04d-%02d\nready_days=%d\nmissing_days=%d\n',year_value,month_value,numel(ready_dates),nnz(status=="MISSING_INPUT")); fclose(fid);
fprintf('CH5_COLUMN_MONTH_PASS ready=%d missing=%d product=%s plot=%s\n',numel(ready_dates),nnz(status=="MISSING_INPUT"),month_mat,plot_path);
end
