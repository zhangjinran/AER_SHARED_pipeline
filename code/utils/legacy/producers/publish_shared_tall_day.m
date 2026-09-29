function final_mat = publish_shared_tall_day(date_str, scenario_name)
%PUBLISH_SHARED_TALL_DAY Publish one validated immutable shared T_all day.

    shared_dir = fileparts(mfilename('fullpath'));
    pipeline_root = fileparts(shared_dir);
    project_root = fileparts(pipeline_root);
    old_path = path;
    path_cleanup = onCleanup(@() path(old_path)); %#ok<NASGU>
    addpath(fullfile(pipeline_root, 'config'));

    cfg = data_roots();
    v = product_versions();
    date_str = char(string(date_str));
    scenario_name = lower(char(string(scenario_name)));
    day_dt = datetime(date_str, 'InputFormat', 'yyyy-MM-dd');
    yyyy = datestr(day_dt, 'yyyy'); mm = datestr(day_dt, 'mm'); dd = datestr(day_dt, 'dd');
    yyyymmdd = datestr(day_dt, 'yyyymmdd'); yyyy_mm_dd = datestr(day_dt, 'yyyy_mm_dd');

    switch scenario_name
        case 'virtual_rh50', sc = scenario_virtual_rh50();
        case 'era5_real', sc = scenario_era5_real();
        otherwise
            error('publish_shared_tall_day:UnknownScenario', ...
                'Unsupported scenario: %s', scenario_name);
    end

    product_key = sprintf('tall__%s__%s__%s__%s', ...
        v.AP_VERSION, sc.product_tag, v.TALL_ADAPTER_VERSION, v.TALL_QC_VERSION);
    product_root = fullfile(cfg.SHARED_TALL_ROOT, product_key);
    final_dir = fullfile(product_root, yyyy, mm, dd);
    success_file = fullfile(final_dir, '_SUCCESS');
    if isfile(success_file)
        error('publish_shared_tall_day:AlreadyPublished', ...
            'Successful product is immutable.');
    end
    stage_dir = fullfile(product_root, '_staging', yyyy, mm, dd);
    stage_mat = fullfile(stage_dir, sprintf('CALIPSO_results_%s_mat.mat', yyyy_mm_dd));
    receipt_file = fullfile(stage_dir, '_BUILD_RECEIPT.mat');

    if ~isfile(receipt_file)
        error('publish_shared_tall_day:MissingReceipt', ...
            'Missing staging build receipt: %s', receipt_file);
    end
    R = load(receipt_file, 'receipt'); receipt = R.receipt;
    if ~receipt.full_day_requested
        error('publish_shared_tall_day:PartialBuild', ...
            'Refusing to publish a partial StartFile/MaxFiles build.');
    end
    if ~strcmp(receipt.date, date_str) || ~strcmp(receipt.scenario, scenario_name) || ...
            ~strcmp(receipt.product_key, product_key)
        error('publish_shared_tall_day:ReceiptMismatch', ...
            'Staging receipt does not match requested product.');
    end
    if ~strcmp(receipt.calipso_source_type, 'mat') || receipt.calipso_hdf_used
        error('publish_shared_tall_day:InvalidCALIPSOSource', ...
            'Shared product must originate from canonical MAT only.');
    end
    if ~isfile(stage_mat)
        error('publish_shared_tall_day:MissingStagingMAT', ...
            'Staging T_all not found: %s', stage_mat);
    end

    ap_file = fullfile(cfg.CALIPSO_AP_ROOT, yyyy, [yyyy_mm_dd '.mat']);
    A = load(ap_file, 'day');
    if ~isfield(A.day, 'meta') || ~isfield(A.day, 'files') || ...
            ~isfield(A.day.meta, 'status') || ...
            ~strcmpi(char(string(A.day.meta.status)), 'complete')
        error('publish_shared_tall_day:IncompleteCanonicalAP', ...
            'Canonical AP day is not marked complete.');
    end
    ap_file_count = numel(A.day.files);

    era5_files = {};
    if strcmp(scenario_name, 'era5_real')
        era5_day_dir = fullfile(cfg.ERA5_MAT_ROOT, yyyy, mm, dd);
        for hh = 0:23
            f = fullfile(era5_day_dir, sprintf('ERA5_%s_%02d.mat', yyyymmdd, hh));
            if ~isfile(f)
                error('publish_shared_tall_day:IncompleteERA5Day', ...
                    'Missing ERA5 UTC hour %02d.', hh);
            end
            era5_files{end+1,1} = f; %#ok<AGROW>
        end
    end

    S = load(stage_mat, 'T_all'); T = S.T_all;
    required = {'Ext','Back','Depol','Type','Lon','Lat','UTC','Height','RH','DayNight','LR'};
    missing = setdiff(required, T.Properties.VariableNames);
    if ~isempty(missing)
        error('publish_shared_tall_day:SchemaFailure', ...
            'Missing required T_all fields: %s', strjoin(missing, ', '));
    end
    if any(~isfinite(T.Ext)) || any(T.Ext <= 0) || ...
            any(~isfinite(T.Back)) || any(T.Back <= 0) || ...
            any(~isfinite(T.Depol)) || any(T.Depol < 0) || ...
            any(~ismember(T.Type, 1:7))
        error('publish_shared_tall_day:QCFailure', 'Frozen T_all QC contract failed.');
    end
    dn = unique(string(T.DayNight));
    if ~all(ismember(dn, ["Day", "Night"])), error('publish_shared_tall_day:QCFailure', 'DayNight contract failed.'); end
    lr_ref = T.Ext ./ T.Back; lr_mask = isfinite(T.LR) & isfinite(lr_ref);
    if ~all(T.LR(lr_mask) == lr_ref(lr_mask)), error('publish_shared_tall_day:QCFailure', 'LR != Ext ./ Back.'); end

    rh_nan_count = nnz(isnan(T.RH)); rh_finite_count = nnz(isfinite(T.RH));
    if strcmp(scenario_name, 'virtual_rh50')
        if ~all(isfinite(T.RH)) || ~all(T.RH == 50)
            error('publish_shared_tall_day:RHFailure', 'virtual_rh50 requires RH=50.');
        end
    elseif rh_finite_count == 0
        error('publish_shared_tall_day:RHFailure', 'era5_real produced no finite RH values.');
    end

    final_parent = fullfile(product_root, yyyy, mm);
    if ~isfolder(final_parent), mkdir(final_parent); end
    final_dir = fullfile(final_parent, dd); success_file = fullfile(final_dir, '_SUCCESS');
    if isfile(success_file), error('publish_shared_tall_day:AlreadyPublished', 'Successful product is immutable.'); end
    if isfolder(final_dir), error('publish_shared_tall_day:IncompleteExistingProduct', 'Final directory exists without _SUCCESS.'); end

    tmp_dir = tempname(final_parent); mkdir(tmp_dir);
    tmp_mat = fullfile(tmp_dir, sprintf('T_all_%s.mat', yyyymmdd));
    copyfile(stage_mat, tmp_mat);

    input_kind = {'CALIPSO_AP'}; input_path = {ap_file};
    d = dir(ap_file); input_bytes = d.bytes; input_modified = {d.date};
    for i = 1:numel(era5_files)
        d = dir(era5_files{i}); input_kind{end+1,1} = 'ERA5'; input_path{end+1,1} = era5_files{i};
        input_bytes(end+1,1) = d.bytes; input_modified{end+1,1} = d.date; %#ok<AGROW>
    end
    inventory = table(input_kind, input_path, input_bytes, input_modified, ...
        'VariableNames', {'Kind','Path','Bytes','LastModified'});
    writetable(inventory, fullfile(tmp_dir, 'input_inventory.csv'));

    manifest_file = fullfile(tmp_dir, 'manifest.txt'); fid = fopen(manifest_file, 'w');
    if fid < 0, error('publish_shared_tall_day:ManifestWriteFailed', 'Unable to write manifest.'); end
    fprintf(fid, 'manifest_version=%s\nproduct_type=T_all\nproduct_key=%s\nstatus=PASS\n', v.MANIFEST_VERSION, product_key);
    fprintf(fid, 'AP_VERSION=%s\nRH_SCENARIO=%s\nADAPTER_VERSION=%s\nQC_VERSION=%s\n', v.AP_VERSION, scenario_name, v.TALL_ADAPTER_VERSION, v.TALL_QC_VERSION);
    fprintf(fid, 'date_start=%s\ndate_end=%s\ncalipso_source_type=mat\ncalipso_hdf_used=false\n', date_str, date_str);
    fprintf(fid, 'calipso_product=05kmAP\ncalipso_input_file=%s\ncalipso_day_status=complete\ncalipso_file_count=%d\n', ap_file, ap_file_count);
    fprintf(fid, 'rh_source=%s\n', sc.rh_source);
    if strcmp(scenario_name, 'era5_real')
        fprintf(fid, 'below_ground_mask=none\nsurface_pressure_used=false\nvertical_profile_gate=finite_and_strictly_monotonic_height\nvertical_extrapolation=none\nmissing_rh_fallback=none\n');
    end
    if strcmp(scenario_name, 'virtual_rh50'), fprintf(fid, 'rh_value=50\nera5_required=false\nera5_complete=NOT_APPLICABLE\n');
    else, fprintf(fid, 'rh_value=\nera5_required=true\nera5_complete=true\n'); end
    fprintf(fid, 'output_rows=%d\noutput_columns=%d\nrh_finite_rows=%d\nrh_nan_rows=%d\n', height(T), width(T), rh_finite_count, rh_nan_count);
    if rh_finite_count > 0, finite_rh = T.RH(isfinite(T.RH)); fprintf(fid, 'rh_min=%.15g\nrh_max=%.15g\n', min(finite_rh), max(finite_rh)); end
    fprintf(fid, 'schema_version=tall-schema-v1\nsuccess_marker=_SUCCESS\n'); fclose(fid);

    movefile(tmp_dir, final_dir);
    fid = fopen(fullfile(final_dir, '_SUCCESS'), 'w');
    if fid < 0, error('publish_shared_tall_day:SuccessWriteFailed', 'Cannot write _SUCCESS.'); end
    fprintf(fid, 'status=PASS\nproduct_key=%s\ndate=%s\npublished_time=%s\n', product_key, date_str, char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
    fclose(fid);
    final_mat = fullfile(final_dir, sprintf('T_all_%s.mat', yyyymmdd));
    if isfolder(stage_dir), rmdir(stage_dir, 's'); end
    fprintf('\n=== SHARED T_ALL PRODUCT PUBLISHED ===\nproduct_key = %s\ndate = %s\nrows = %d\nfinal MAT = %s\n_SUCCESS = PASS\n', product_key, date_str, height(T), final_mat);
end
