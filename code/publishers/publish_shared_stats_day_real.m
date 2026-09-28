function final_mat = publish_shared_stats_day_real(date_str)
%PUBLISH_SHARED_STATS_DAY_REAL Publish a staged ERA5-real CALIPSO_STATS day.
%   The publisher accepts only a complete new-root T_all source and writes an
%   immutable product beneath products\calipso_stats.

    date_str = char(string(date_str));
    dt = datetime(date_str, 'InputFormat', 'yyyy-MM-dd');
    publisher_dir = fileparts(mfilename('fullpath'));
    code_root = fileparts(publisher_dir);
    addpath(fullfile(code_root, 'config'));
    cfg = data_roots();
    v = product_versions();

    yyyy = datestr(dt, 'yyyy'); mm = datestr(dt, 'mm'); dd = datestr(dt, 'dd');
    yyyymmdd = datestr(dt, 'yyyymmdd');
    tall_key = sprintf('tall__%s__era5-real__%s__%s', ...
        v.AP_VERSION, v.TALL_ADAPTER_VERSION, v.TALL_QC_VERSION);
    stats_key = sprintf('stats__%s__era5-real__%s__%s__stats-v1', ...
        v.AP_VERSION, v.TALL_ADAPTER_VERSION, v.TALL_QC_VERSION);
    tall_mat = fullfile(cfg.SHARED_TALL_ROOT, tall_key, yyyy, mm, dd, ...
        sprintf('T_all_%s.mat', yyyymmdd));
    tall_success = fullfile(fileparts(tall_mat), '_SUCCESS');
    stage_dir = fullfile(cfg.SHARED_STATS_ROOT, stats_key, '_staging', yyyy, mm, dd);
    stage_mat = fullfile(stage_dir, sprintf('CALIPSO_STATS_%s.mat', yyyymmdd));
    final_dir = fullfile(cfg.SHARED_STATS_ROOT, stats_key, yyyy, mm, dd);
    success_file = fullfile(final_dir, '_SUCCESS');

    if ~isfile(tall_mat) || ~isfile(tall_success)
        error('publish_shared_stats_day_real:MissingPublishedTAll', ...
            'New-root published T_all is required: %s', tall_mat);
    end
    if ~isfile(stage_mat)
        error('publish_shared_stats_day_real:MissingStage', ...
            'Staged CALIPSO_STATS is required: %s', stage_mat);
    end
    if isfile(success_file)
        error('publish_shared_stats_day_real:AlreadyPublished', ...
            'Successful CALIPSO_STATS product is immutable: %s', final_dir);
    end
    if isfolder(final_dir)
        error('publish_shared_stats_day_real:ExistingIncompleteFinal', ...
            'Refusing to overwrite incomplete final directory: %s', final_dir);
    end

    final_parent = fileparts(final_dir);
    if ~isfolder(final_parent), mkdir(final_parent); end
    tmp_dir = tempname(final_parent); mkdir(tmp_dir);
    cleanup = onCleanup(@() cleanup_tmp(tmp_dir)); %#ok<NASGU>
    final_mat = fullfile(tmp_dir, sprintf('CALIPSO_STATS_%s.mat', yyyymmdd));
    copyfile(stage_mat, final_mat);
    tall_info = dir(tall_mat);
    inventory = table({'T_all'}, {tall_mat}, tall_info.bytes, {tall_info.date}, ...
        'VariableNames', {'Kind','Path','Bytes','LastModified'});
    writetable(inventory, fullfile(tmp_dir, 'input_inventory.csv'));
    fid = fopen(fullfile(tmp_dir, 'manifest.txt'), 'w');
    if fid < 0, error('publish_shared_stats_day_real:ManifestWrite', 'Cannot write manifest.'); end
    fprintf(fid, ['manifest_version=manifest-v1\nproduct_type=CALIPSO_STATS\nproduct_key=%s\n' ...
        'status=PASS\ndate=%s\nscenario=era5_real\nproducer=build_calipso_stats.m\n' ...
        'source_tall=%s\nsource_tall_status=published\nbelow_ground_mask=none\n' ...
        'surface_pressure_used=false\nformal_science_product=true\nschema_version=stats-v1\n' ...
        'success_marker=_SUCCESS\n'], stats_key, date_str, tall_mat);
    fclose(fid);
    movefile(tmp_dir, final_dir);
    cleanup = [];
    final_mat = fullfile(final_dir, sprintf('CALIPSO_STATS_%s.mat', yyyymmdd));
    fid = fopen(success_file, 'w');
    fprintf(fid, 'status=PASS\nproduct_key=%s\ndate=%s\npublished_time=%s\n', ...
        stats_key, date_str, char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
    fclose(fid);
    fprintf('SHARED CALIPSO_STATS PUBLISHED\nfinal=%s\n_SUCCESS=PASS\n', final_mat);
end

function cleanup_tmp(path_value)
    if isfolder(path_value), rmdir(path_value, 's'); end
end
