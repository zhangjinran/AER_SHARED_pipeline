function output_path = aggregate_chapter5_type_number_column_month(daily_paths,dates,output_path)
%AGGREGATE_CHAPTER5_TYPE_NUMBER_COLUMN_MONTH Pool daily column sums/counts.
if numel(daily_paths)~=numel(dates) || isempty(dates)
    error('CH5ColumnMonth:Inputs','Daily product paths and dates must align and be nonempty.');
end
sum_all=zeros(36,72,2,8); profiles=zeros(36,72,2);
type_profiles=zeros(36,72,2,7); samples=zeros(36,72,2,7);
for k=1:numel(daily_paths)
    S=load_retry(daily_paths{k},'N50_COLUMN_CH5_V2'); X=S.N50_COLUMN_CH5_V2;
    if ~strcmp(X.meta.date,char(dates(k)))
        error('CH5ColumnMonth:DateMismatch','Daily product/date mismatch: %s vs %s.',X.meta.date,dates(k));
    end
    if ~isequal(size(X.column_sum_cm2),[36 72 2 8])
        error('CH5ColumnMonth:GridMismatch','Daily product has unexpected dimensions: %s',daily_paths{k});
    end
    sum_all=sum_all+X.column_sum_cm2;
    profiles=profiles+X.profile_count;
    type_profiles=type_profiles+X.type_profile_count;
    samples=samples+X.sample_count;
end
means=nan(size(sum_all));
for d=1:2
    den=profiles(:,:,d); valid=den>0;
    for t=1:8
        x=sum_all(:,:,d,t); x(valid)=x(valid)./den(valid); x(~valid)=NaN;
        means(:,:,d,t)=x;
    end
end
period_start=datetime(dates(1),'InputFormat','yyyy-MM-dd');
period_end=datetime(dates(end),'InputFormat','yyyy-MM-dd');
meta=struct('schema_version','chapter5-type-number-column-month-v1', ...
    'product_key','ch5-number-column__stats-ch5v2__omcam-v2__grid5deg__z0-10km-month-pooled-v1', ...
    'period_start',char(period_start),'period_end',char(period_end), ...
    'period_label',datestr(period_start,'yyyy-mm'), 'grid_lat_deg',5,'grid_lon_deg',5, ...
    'altitude_min_km',0,'altitude_max_km',10,'output_units','cm-2', ...
    'aggregation','pooled daily column_sum_cm2 divided by pooled profile_count; no averaging of daily means', ...
    'denominator','aerosol-bearing profiles only; clear-only profiles excluded', ...
    'type_semantics','Type1 marine N50; Type2 dust N100; Type3 PC N50; Type4 CC N50; Type5 dust N100+PC N50 per original sample; Type6 smoke N50; Type7 dust N100+marine N50 per original sample', ...
    'is_uniform_N50',false,'processed_dates',dates(:), ...
    'daily_product_paths',{daily_paths(:)},'daynight',{{'Day','Night'}}, ...
    'component_order',{{'Type1','Type2','Type3','Type4','Type5','Type6','Type7','Total'}});
N50_COLUMN_CH5_V2=struct('meta',meta,'column_sum_cm2',sum_all, ...
    'column_mean_cm2',means,'profile_count',profiles, ...
    'type_profile_count',type_profiles,'sample_count',samples); %#ok<NASGU>
if ~isfolder(fileparts(output_path)),mkdir(fileparts(output_path));end
if isfile(output_path), error('CH5ColumnMonth:NoOverwrite','Refusing to overwrite %s',output_path); end
save(output_path,'N50_COLUMN_CH5_V2','-v7.3');
fprintf('CH5_COLUMN_MONTH_POOL_PASS days=%d profiles=%d output=%s\n',numel(dates),sum(profiles(:)),output_path);
end

function S=load_retry(path,varname)
for k=1:5
    try
        S=builtin('load',path,varname); return
    catch ME
        if k==5, rethrow(ME); end
        fprintf(2,'MONTH_READ_RETRY attempt=%d/5 file=%s error=%s\n',k,path,ME.message);
        pause(2*k);
    end
end
end
