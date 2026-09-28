function report = pool_ccn_v2_month_products(input_paths, output_path)
%POOL_CCN_V2_MONTH_PRODUCTS Pool monthly additive numerators and denominators.
% This creates a run-level diagnostic product; it does not publish or modify
% any formal monthly product.
if ischar(input_paths) || isstring(input_paths), input_paths=cellstr(input_paths); end
if numel(input_paths)<2, error('CCNv2:PoolInputs','At least two monthly products are required.'); end
for k=1:numel(input_paths)
    if ~isfile(input_paths{k}), error('CCNv2:PoolMissingInput','Missing input: %s',input_paths{k}); end
end
outdir=fileparts(output_path); if ~isfolder(outdir), mkdir(outdir); end

sum_component=[]; sum_total=[]; sample_count=[]; base_meta=[];
all_dates={}; source_months=cell(size(input_paths));
for k=1:numel(input_paths)
    S=load(input_paths{k},'sum_component','sum_total','sample_count','meta');
    required={'sum_component','sum_total','sample_count','meta'};
    for j=1:numel(required)
        if ~isfield(S,required{j}), error('CCNv2:PoolSchema','%s lacks %s.',input_paths{k},required{j}); end
    end
    if ~isfield(S.meta,'aggregation') || ~strcmp(char(string(S.meta.aggregation)),'pooled_sum_over_pooled_sample_count')
        error('CCNv2:PoolAggregation','Unsupported aggregation in %s.',input_paths{k});
    end
    if ~isfield(S.meta,'included_dates')
        error('CCNv2:PoolDates','included_dates missing in %s.',input_paths{k});
    end
    dates=cellstr(string(S.meta.included_dates(:))');
    if any(cellfun(@isempty,dates)), error('CCNv2:PoolDates','Empty date entry in %s.',input_paths{k}); end
    if numel(unique(dates))~=numel(dates), error('CCNv2:PoolDates','Duplicate date within %s.',input_paths{k}); end
    overlap=intersect(all_dates,dates);
    if ~isempty(overlap), error('CCNv2:PoolDates','Input month products overlap at %s.',overlap{1}); end
    all_dates=[all_dates dates]; %#ok<AGROW>
    if isfield(S.meta,'yyyymm'), source_months{k}=char(string(S.meta.yyyymm)); else, source_months{k}='unknown'; end
    if isempty(base_meta)
        base_meta=S.meta;
        sum_component=double(S.sum_component); sum_total=double(S.sum_total); sample_count=double(S.sample_count);
        expected=[90 72 133 5 3];
        if ~isequal(size(sum_component),expected) || ~isequal(size(sum_total),[90 72 133 3]) || ~isequal(size(sample_count),[90 72 133])
            error('CCNv2:PoolShape','Unexpected grid/level/component/branch dimensions.');
        end
    else
        if ~isequal(size(S.sum_component),size(sum_component)) || ~isequal(size(S.sum_total),size(sum_total)) || ~isequal(size(S.sample_count),size(sample_count))
            error('CCNv2:PoolShape','Monthly product array shapes differ.');
        end
        if isfield(base_meta,'clear_air_in_denominator') && isfield(S.meta,'clear_air_in_denominator') && ...
                ~isequal(base_meta.clear_air_in_denominator,S.meta.clear_air_in_denominator)
            error('CCNv2:PoolDenominator','clear_air_in_denominator differs across inputs.');
        end
        sum_component=sum_component+double(S.sum_component);
        sum_total=sum_total+double(S.sum_total);
        sample_count=sample_count+double(S.sample_count);
    end
    if any(~isfinite(double(S.sample_count(:)))) || any(double(S.sample_count(:))<0)
        error('CCNv2:PoolCounts','Invalid sample_count values in %s.',input_paths{k});
    end
end
if ~isequal(sort(source_months),{'200701','200702'})
    error('CCNv2:PoolMonths','This run is frozen for exactly 200701 and 200702 products.');
end

if any(~isfinite(sum_component(:))) || any(~isfinite(sum_total(:))) || any(~isfinite(sample_count(:)))
    error('CCNv2:PoolNonfinite','Non-finite pooled numerator or denominator.');
end
mean_total=nan(size(sum_total)); mean_component=nan(size(sum_component));
for b=1:3
    den=sample_count; ok=den>0;
    tmp=sum_total(:,:,:,b); tmp(ok)=tmp(ok)./den(ok); mean_total(:,:,:,b)=tmp;
    for q=1:5
        tmp=sum_component(:,:,:,q,b); tmp(ok)=tmp(ok)./den(ok); mean_component(:,:,:,q,b)=tmp;
    end
end
all_dates=sort(all_dates);
base_meta.schema_version='ccn-omcam-v2-pooled-months';
base_meta.product_status='RUN_DERIVED_DIAGNOSTIC';
base_meta.aggregation='pooled_sum_over_pooled_sample_count';
base_meta.yyyymm='200701_200702';
base_meta.period_label='2007-01 to 2007-02';
base_meta.included_dates=all_dates;
base_meta.source_month_products=input_paths;
base_meta.source_month_keys=source_months;
base_meta.note='Run-level pooled diagnostic; sums and counts pooled before recomputing means; not a formal product.';
meta=base_meta; %#ok<NASGU>
save(output_path,'sum_component','sum_total','sample_count','mean_component','mean_total','meta','-v7.3');
report=struct('output_path',output_path,'source_month_products',{input_paths}, ...
    'source_month_keys',{source_months},'included_dates',{all_dates}, ...
    'date_count',numel(all_dates),'sample_count_sum',sum(sample_count(:)), ...
    'aggregation','sum monthly numerators; sum monthly denominators; recompute pooled means');
end
