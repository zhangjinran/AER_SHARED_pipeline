function result=run_aod_month(year_value,month_value,run_root)
error('AOD:RetiredTAll','T_all AOD v1 retired. Use run_aod_apro_day for native-profile v2.');
%RUN_AOD_MONTH T_all -> daily AOD grids -> pooled monthly grid -> two plots.
% A new run directory is required. Existing formal products are reused only
% when their complete immutable contract and metadata validate.
if nargin<3||isempty(run_root),error('AOD:RunRoot','Pass a unique runs\\aod\\run_* directory.');end
cfg=aod_config(); run_root=char(run_root);
if isfolder(run_root),error('AOD:RunNoOverwrite','Run directory already exists: %s',run_root);end
mkdir(run_root); logdir=fullfile(run_root,'logs'); reportdir=fullfile(run_root,'reports'); stagedir=fullfile(run_root,'staging'); plotdir=fullfile(run_root,'plots');
mkdir(logdir);mkdir(reportdir);mkdir(stagedir);mkdir(plotdir);
logfile=fullfile(logdir,sprintf('aod_%04d%02d_matlab.log',year_value,month_value));
diary(logfile); diaryc=onCleanup(@()diary('off')); %#ok<NASGU>
try
    addpath(fullfile(cfg.project_root,'code','utils','shared','config'),'-begin');
    addpath(fullfile(cfg.code_root,'utils'),'-begin');
    addpath(fullfile(cfg.code_root,'science_core'),'-begin');addpath(fullfile(cfg.code_root,'producers'),'-begin');
    addpath(fullfile(cfg.code_root,'publishers'),'-begin');addpath(fullfile(cfg.code_root,'consumers'),'-begin');
    addpath(fullfile(cfg.project_root,'code','utils','ccn','ccnv2','science_core'),'-begin');
    addpath(fullfile(cfg.project_root,'plots','common'),'-begin');
    roots=data_roots();
    first=datetime(year_value,month_value,1); nd=day(dateshift(first,'end','month'));
    dates=strings(nd,1); status=strings(nd,1); reason=strings(nd,1); tall_paths=strings(nd,1); product_paths=strings(nd,1);
    for d=1:nd
        dt=first+caldays(d-1); ymd=char(string(dt,'yyyyMMdd')); dates(d)=string(ymd);
        tall_paths(d)=fullfile(roots.SHARED_TALL_ROOT,cfg.tall_product_key,char(string(dt,'yyyy')),char(string(dt,'MM')),char(string(dt,'dd')),['T_all_' ymd '.mat']);
        product_paths(d)=fullfile(cfg.daily_root,char(string(dt,'yyyy')),char(string(dt,'MM')),char(string(dt,'dd')),['AOD_GRID_' ymd '.mat']);
        if isfile(tall_paths(d))&&isfile(fullfile(fileparts(tall_paths(d)),'_SUCCESS')),status(d)="READY";reason(d)="";
        else,status(d)="MISSING_TALL";reason(d)="formal_T_all_or_SUCCESS_missing";end
    end
    inventory=table(dates,status,reason,tall_paths,product_paths,'VariableNames',{'date','status','reason','tall_path','aod_product_path'});
    inventory_path=fullfile(reportdir,sprintf('date_inventory_%04d%02d.csv',year_value,month_value));writetable(inventory,inventory_path);
    fprintf('AOD_INVENTORY_FROZEN month=%04d%02d ready=%d missing=%d\n',year_value,month_value,nnz(status=="READY"),nnz(status=="MISSING_TALL"));
    ready_paths=cell(0,1);ready_dates=cell(0,1);
    for d=1:nd
        if status(d)=="MISSING_TALL",fprintf('AOD_DAY_SKIP date=%s reason=%s\n',dates(d),reason(d));continue;end
        final_path=char(product_paths(d)); final_dir=fileparts(final_path);
        if isfile(final_path)&&has_contract(final_dir)
            Q=load_aod_mat_retry(final_path,'AOD_GRID');X=Q.AOD_GRID;
            if ~strcmp(X.meta.date,char(dates(d)))||~strcmp(X.meta.product_key,cfg.daily_key),error('AOD:ExistingMismatch','Existing daily product contract mismatch: %s',final_path);end
            fprintf('AOD_DAY_REUSE date=%s\n',dates(d)); status(d)="EXISTING_PASS";
        else
            if isfolder(final_dir),error('AOD:IncompleteExisting','Refusing to overwrite incomplete daily product: %s',final_dir);end
            candidate=fullfile(stagedir,['AOD_GRID_' char(dates(d)) '.mat']);
            build_aod_grid_day(char(tall_paths(d)),char(dates(d)),candidate);
            gate_daily(candidate,char(dates(d)));
            publish_aod_grid_day(candidate,char(tall_paths(d)),char(dates(d)));
            status(d)="GENERATED_PASS";
        end
        reason(d)="";inventory.status(d)=status(d);inventory.reason(d)=reason(d);writetable(inventory,inventory_path);
        ready_paths{end+1,1}=final_path;ready_dates{end+1,1}=char(dates(d)); %#ok<AGROW>
    end
    if isempty(ready_paths),error('AOD:NoReadyDays','No daily AOD products were available.');end
    ym=sprintf('%04d%02d',year_value,month_value);
    month_path=fullfile(cfg.monthly_root,sprintf('%04d',year_value),sprintf('%02d',month_value),['AOD_GRID_MONTH_' ym '.mat']);
    month_dir=fileparts(month_path);
    if isfile(month_path)&&has_contract(month_dir)
        Q=load_aod_mat_retry(month_path,'AOD_GRID_MONTH');X=Q.AOD_GRID_MONTH;
        if ~strcmp(X.meta.period,ym)||~strcmp(X.meta.product_key,cfg.monthly_key),error('AOD:ExistingMonthMismatch','Existing monthly product mismatch.');end
        fprintf('AOD_MONTH_REUSE period=%s\n',ym);
    else
        if isfolder(month_dir),error('AOD:IncompleteMonth','Refusing to overwrite incomplete monthly product: %s',month_dir);end
        candidate=fullfile(stagedir,['AOD_GRID_MONTH_' ym '.mat']);
        aggregate_aod_grid_month(ready_paths,ready_dates,candidate);
        Q=load(candidate,'AOD_GRID_MONTH');AOD_GRID_MONTH=Q.AOD_GRID_MONTH;
        AOD_GRID_MONTH.meta.missing_dates=dates(status=="MISSING_TALL");
        save(candidate,'AOD_GRID_MONTH','-v7.3');
        publish_aod_grid_month(candidate,year_value,month_value,ready_paths,inventory_path);
    end
    plots=plot_aod_grid_month(month_path,plotdir);
    fprintf('AOD_MONTH_PASS period=%s ready=%d missing=%d product=%s plots=%s|%s\n',ym,numel(ready_paths),nnz(status=="MISSING_TALL"),month_path,plots{1},plots{2});
    result=struct('status','PASS','monthly_product',month_path,'plots',{plots},'inventory',inventory_path,'run_root',run_root);
catch ME
    fprintf(2,'AOD_RUN_FAIL id=%s message=%s\n%s\n',ME.identifier,ME.message,getReport(ME,'extended','hyperlinks','off'));
    rethrow(ME);
end
end

function tf=has_contract(d)
tf=isfile(fullfile(d,'manifest.txt'))&&isfile(fullfile(d,'input_inventory.csv'))&&isfile(fullfile(d,'_SUCCESS'));
end
function gate_daily(p,ymd)
Q=load(p,'AOD_GRID');X=Q.AOD_GRID;
assert(strcmp(X.meta.date,ymd)&&isequal(size(X.mean_direct_ext),[36 72 8]),'AOD:DailyGate','Daily dimensions/date invalid.');
assert(all(X.count_direct_ext(:)>=0)&&all(X.count_component_reconstruction(:)>=0),'AOD:DailyGate','Negative profile counts.');
assert(all(isfinite(X.mean_direct_ext(isfinite(X.mean_direct_ext))))&&all(X.mean_direct_ext(isfinite(X.mean_direct_ext))>=0),'AOD:DailyGate','Invalid direct means.');
assert(all(isfinite(X.mean_component_reconstruction(isfinite(X.mean_component_reconstruction))))&&all(X.mean_component_reconstruction(isfinite(X.mean_component_reconstruction))>=0),'AOD:DailyGate','Invalid component means.');
end
