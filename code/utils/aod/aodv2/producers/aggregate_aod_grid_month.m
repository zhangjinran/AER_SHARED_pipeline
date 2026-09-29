function AOD_GRID_MONTH = aggregate_aod_grid_month(daily_paths,dates_ymd,output_path)
%AGGREGATE_AOD_GRID_MONTH Pooled monthly sums/counts from gated daily grids.
cfg=aod_config(); addpath(fullfile(cfg.code_root,'utils'),'-begin');
if isfile(output_path), error('AOD:NoOverwrite','Refusing to overwrite month candidate: %s',output_path); end
if numel(daily_paths)~=numel(dates_ymd) || isempty(daily_paths), error('AOD:MonthInputs','Daily paths and dates must be non-empty and aligned.'); end
sd=[]; cd=[]; sc=[]; cc=[]; used=strings(0,1);
for k=1:numel(daily_paths)
    p=char(daily_paths{k});
    if ~isfile(p) || ~isfile(fullfile(fileparts(p),'_SUCCESS'))
        error('AOD:DailyGate','Daily AOD product is missing or not gated: %s',p);
    end
    Q=load_aod_mat_retry(p,'AOD_GRID'); X=Q.AOD_GRID;
    if ~strcmp(X.meta.date,char(dates_ymd{k})) || ~strcmp(X.meta.product_key,cfg.daily_key)
        error('AOD:DailyContract','Daily product metadata mismatch: %s',p);
    end
    if isempty(sd), sd=double(X.sum_direct_ext); cd=double(X.count_direct_ext); sc=double(X.sum_component_reconstruction); cc=double(X.count_component_reconstruction);
    else, sd=sd+double(X.sum_direct_ext); cd=cd+double(X.count_direct_ext); sc=sc+double(X.sum_component_reconstruction); cc=cc+double(X.count_component_reconstruction); end
    used(end+1,1)=string(dates_ymd{k}); %#ok<AGROW>
end
md=nan(size(sd)); mc=nan(size(sc));
for c=1:size(sd,3)
    q=cd(:,:,c)>0; z=md(:,:,c); a=sd(:,:,c); den=cd(:,:,c); z(q)=a(q)./den(q); md(:,:,c)=z;
    q=cc(:,:,c)>0; z=mc(:,:,c); a=sc(:,:,c); den=cc(:,:,c); z(q)=a(q)./den(q); mc(:,:,c)=z;
end
first=datetime(char(dates_ymd{1}),'InputFormat','yyyyMMdd'); ym=char(string(first,'yyyyMM'));
meta=struct('schema_version','aod-grid-month-v1','product_key',cfg.monthly_key,'period',ym, ...
    'grid','global_5x5deg','aggregation','pooled_profile_sum_over_pooled_profile_count', ...
    'processed_dates',used,'channels',{cfg.components},'source_daily_product_key',cfg.daily_key, ...
    'methods',{cfg.method_names});
AOD_GRID_MONTH=struct('meta',meta,'sum_direct_ext',sd,'profile_count_direct_ext',uint64(cd), ...
    'mean_direct_ext',md,'sum_component_reconstruction',sc, ...
    'profile_count_component_reconstruction',uint64(cc),'mean_component_reconstruction',mc, ...
    'lat_edges',cfg.grid.lat_edges,'lon_edges',cfg.grid.lon_edges);
outdir=fileparts(output_path); if ~isfolder(outdir),mkdir(outdir);end
save(output_path,'AOD_GRID_MONTH','-v7.3');
fprintf('AOD_MONTH_CANDIDATE_PASS period=%s days=%d output=%s\n',ym,numel(used),output_path);
end
