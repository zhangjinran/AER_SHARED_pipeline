function output_path = build_calipso_stats_ch5_v2_day(tall_path, output_path)
%BUILD_CALIPSO_STATS_CH5_V2_DAY Build an unpublished Chapter5_v2 daily candidate.
% Input is an immutable formal T_all.  This function never writes products.

cfg = chapter5_v2_config();
if ~isfile(tall_path), error('Chapter5v2:MissingTAll','Missing T_all: %s',tall_path); end
if ~isfolder(fileparts(output_path)), mkdir(fileparts(output_path)); end
addpath(fullfile(cfg.project_root,'code','utils','shared','common'),'-begin');
addpath(fullfile(cfg.code_root,'science_core'),'-begin');

S = load_tall_with_nas_retry(tall_path);
if ~isfield(S,'T_all'), error('Chapter5v2:MissingVariable','T_all is absent from %s.',tall_path); end
T = S.T_all;
required = {'Lon','Lat','UTC','Height','DayNight','Ext','Back','Depol','Type','RH'};
if ~all(ismember(required,T.Properties.VariableNames))
    error('Chapter5v2:Schema','T_all lacks: %s.',strjoin(setdiff(required,T.Properties.VariableNames),', '));
end
T.sample_id = (1:height(T))';
E = load(cfg.extinction_file,'Extinction_N');
calc = compute_chapter5_sample_contributions_v2(T,E.Extinction_N,cfg);

nlat = numel(cfg.grid.lat_edges)-1; nlon = numel(cfg.grid.lon_edges)-1;
CALIPSO_STATS_CH5_V2 = struct();
CALIPSO_STATS_CH5_V2.meta = struct( ...
    'schema_version','calipso-stats-ch5-v2', ...
    'product_key',cfg.stats_product_key, ...
    'source_tall',tall_path, ...
    'prior_root',cfg.prior_root, ...
    'prior_manifest',cfg.prior_manifest, ...
    'volume_scale_conversion',cfg.volume_scale_conversion, ...
    'component_order',{cfg.component_names}, ...
    'provenance_contract',cfg.provenance_contract, ...
    'status','candidate_unpublished');
CALIPSO_STATS_CH5_V2.grid(nlat,nlon) = struct();
for i = 1:nlat
    for j = 1:nlon
        CALIPSO_STATS_CH5_V2.grid(i,j).lat_range = cfg.grid.lat_edges(i:i+1);
        CALIPSO_STATS_CH5_V2.grid(i,j).lon_range = cfg.grid.lon_edges(j:j+1);
    end
end

lat_idx = floor((double(T.Lat)+90)/5)+1;
lon_idx = floor((double(T.Lon)+180)/5)+1;
month_id = uint8(month(datetime(T.UTC,'ConvertFrom','datenum')));
dn_id = zeros(height(T),1,'uint8');
dn_id(string(T.DayNight)=="Day") = 1;
dn_id(string(T.DayNight)=="Night") = 2;
orig_type = double(T.Type);
keep = calc.valid & lat_idx>=1 & lat_idx<=nlat & lon_idx>=1 & lon_idx<=nlon & ...
    month_id>=1 & month_id<=12 & dn_id>0 & orig_type>=1 & orig_type<=7;

CALIPSO_STATS_CH5_V2.meta.input_rows = height(T);
CALIPSO_STATS_CH5_V2.meta.valid_rows = nnz(keep);
CALIPSO_STATS_CH5_V2.meta.invalid_rows = nnz(~keep);
CALIPSO_STATS_CH5_V2.meta.type_input_counts = arrayfun(@(x)nnz(orig_type==x),1:7);
CALIPSO_STATS_CH5_V2.meta.type_valid_counts = arrayfun(@(x)nnz(keep & orig_type==x),1:7);

bucket_id = sub2ind([nlat,nlon,2,12,7],lat_idx(keep),lon_idx(keep), ...
    double(dn_id(keep)),double(month_id(keep)),orig_type(keep));
source_rows = find(keep);
[bucket_sorted,order] = sort(bucket_id);
starts = [1;find(diff(bucket_sorted)~=0)+1];
stops = [starts(2:end)-1;numel(bucket_sorted)];
dn_names = string(cfg.daynight);
month_names = string(cfg.month_names);
for g = 1:numel(starts)
    rows = source_rows(order(starts(g):stops(g)));
    [i,j,dn_i,m_i,t_i] = ind2sub([nlat,nlon,2,12,7],bucket_sorted(starts(g)));
    dn_str = char(dn_names(dn_i)); mo_str = char(month_names(m_i)); tp_str = sprintf('Type%d',t_i);
    tab = table(T.Lon(rows),T.Lat(rows),T.UTC(rows),T.Height(rows), ...
        T.sample_id(rows),orig_type(rows),T.RH(rows),T.Ext(rows),T.Back(rows),T.Depol(rows), ...
        calc.n50_marine(rows),calc.n100_dust(rows),calc.n50_polluted_continental(rows), ...
        calc.n50_clean_continental(rows),calc.n50_elevated_smoke(rows), ...
        calc.chapter5_type_value_cm3(rows), ...
        'VariableNames',{'Lon','Lat','Time','Height','sample_id','original_type','ERA5_RH', ...
        'Extinction','Backscatter','Depolarization_Ratio','N50_marine','N100_dust', ...
        'N50_polluted_continental','N50_clean_continental','N50_elevated_smoke', ...
        'Nd_dry_OMCAM_v2'});
    if ~isfield(CALIPSO_STATS_CH5_V2.grid(i,j),dn_str)
        CALIPSO_STATS_CH5_V2.grid(i,j).(dn_str) = struct();
    end
    if ~isfield(CALIPSO_STATS_CH5_V2.grid(i,j).(dn_str),mo_str)
        CALIPSO_STATS_CH5_V2.grid(i,j).(dn_str).(mo_str) = struct();
    end
    CALIPSO_STATS_CH5_V2.grid(i,j).(dn_str).(mo_str).(tp_str).data = tab;
end
save(output_path,'CALIPSO_STATS_CH5_V2','-v7.3');
fprintf('CHAPTER5_V2_DAILY_CANDIDATE rows=%d valid=%d output=%s\n',height(T),nnz(keep),output_path);
end

function S = load_tall_with_nas_retry(mat_path)
% Keep the v2 producer independent of the legacy global load.m wrapper.
max_attempts = 5;
for attempt = 1:max_attempts
    try
        S = builtin('load',mat_path,'T_all');
        fprintf('CHAPTER5_V2_TALL_READ_PASS attempt=%d/%d\n',attempt,max_attempts);
        return
    catch ME
        if attempt == max_attempts
            rethrow(ME);
        end
        fprintf(2,'CHAPTER5_V2_TALL_READ_RETRY attempt=%d/%d error=%s\n', ...
            attempt,max_attempts,ME.message);
        pause(2*attempt);
    end
end
end
