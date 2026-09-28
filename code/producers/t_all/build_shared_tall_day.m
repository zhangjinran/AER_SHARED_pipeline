function output_path = build_shared_tall_day(date_str, scenario_name, varargin)
%BUILD_SHARED_TALL_DAY Canonical MAT-only T_all adapter.
%
% Unified-pipeline entry point for shared T_all construction.  Final
% publication, manifest, _SUCCESS and immutability belong to Patch 06-3.

    p = inputParser;
    addRequired(p, 'date_str', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addRequired(p, 'scenario_name', @(x) ischar(x) || (isstring(x) && isscalar(x)));
    addParameter(p, 'StartFile', 1, @(x) isnumeric(x) && isscalar(x) && ...
        isfinite(x) && x >= 1 && fix(x) == x);
    addParameter(p, 'MaxFiles', Inf, @(x) isnumeric(x) && isscalar(x) && ...
        ((isinf(x) && x > 0) || (isfinite(x) && x >= 1 && fix(x) == x)));
    parse(p, date_str, scenario_name, varargin{:});
    opt = p.Results;

    date_str = char(string(opt.date_str));
    scenario_name = lower(char(string(opt.scenario_name)));

    producer_dir = fileparts(mfilename('fullpath'));
    code_root = fileparts(fileparts(producer_dir));
    project_root = fileparts(code_root);
    config_dir = fullfile(code_root, 'config');
    previous_dir=pwd;
    directory_cleanup=onCleanup(@()cd(previous_dir)); %#ok<NASGU>
    cd(project_root); % Old current-directory scripts override addpath otherwise.

    old_path = path;
    path_cleanup = onCleanup(@() path(old_path)); %#ok<NASGU>
    addpath(config_dir);
    addpath(fullfile(code_root, 'root_scripts'));
    assert(strcmpi(which('build_calipso_step1_day'),fullfile(code_root,'root_scripts','build_calipso_step1_day.m')), ...
        'CALIPSO:ShadowedProducer','Wrong T_all producer on MATLAB path.');

    cfg = data_roots();
    v = product_versions();

    try
        day_dt = datetime(date_str, 'InputFormat', 'yyyy-MM-dd');
    catch ME
        error('build_shared_tall_day:InvalidDate', ...
            'date_str must use yyyy-MM-dd. Original error: %s', ME.message);
    end

    yyyy = datestr(day_dt, 'yyyy');
    mm = datestr(day_dt, 'mm');
    dd = datestr(day_dt, 'dd');
    yyyymmdd = datestr(day_dt, 'yyyymmdd');
    yyyy_mm_dd = datestr(day_dt, 'yyyy_mm_dd');

    switch scenario_name
        case 'virtual_rh50'
            sc = scenario_virtual_rh50();
        case 'era5_real'
            sc = scenario_era5_real();
        case 'era5_flowtest'
            sc = scenario_era5_flowtest();
        otherwise
            error('build_shared_tall_day:UnknownScenario', ...
                'Unsupported scenario: %s', scenario_name);
    end

    if ~isfield(sc, 'name') || ~strcmp(sc.name, scenario_name)
        error('build_shared_tall_day:ScenarioContractMismatch', ...
            'Scenario name does not match requested scenario.');
    end
    if ~isfield(sc, 'product_tag') || isempty(sc.product_tag)
        error('build_shared_tall_day:ScenarioContractMismatch', ...
            'Scenario must define product_tag.');
    end

    if strcmp(scenario_name, 'virtual_rh50')
        if sc.require_era5 || sc.allow_era5_access
            error('build_shared_tall_day:ScenarioContractMismatch', ...
                'virtual_rh50 must forbid ERA5 access.');
        end
        if ~isfield(sc, 'rh_value') || sc.rh_value ~= 50
            error('build_shared_tall_day:ScenarioContractMismatch', ...
                'virtual_rh50 must explicitly define RH=50.');
        end
    elseif strcmp(scenario_name, 'era5_real') || strcmp(scenario_name, 'era5_flowtest')
        if ~sc.require_era5 || ~sc.allow_era5_access
            error('build_shared_tall_day:ScenarioContractMismatch', ...
                'era5_real must require and allow ERA5 access.');
        end
    end

    ap_file = fullfile(cfg.CALIPSO_AP_ROOT, yyyy, [yyyy_mm_dd '.mat']);
    if ~isfile(ap_file)
        error('build_shared_tall_day:MissingCanonicalAP', ...
            'Canonical AP MAT not found: %s', ap_file);
    end

    product_key = sprintf('tall__%s__%s__%s__%s', ...
        v.AP_VERSION, sc.product_tag, v.TALL_ADAPTER_VERSION, v.TALL_QC_VERSION);

    stage_dir = fullfile(cfg.SHARED_TALL_ROOT, product_key, '_staging', yyyy, mm, dd);
    if ~isfolder(stage_dir), mkdir(stage_dir); end

    common_args = {'MatRoot', cfg.CALIPSO_AP_ROOT, ...
        'OutputDir', stage_dir, 'StartFile', opt.StartFile, ...
        'MaxFiles', opt.MaxFiles, 'Scenario', sc};

    switch scenario_name
        case 'virtual_rh50'
            output_path = build_calipso_step1_day(date_str, 'mat', common_args{:});
        case {'era5_real', 'era5_flowtest'}
            era5_day_dir = fullfile(cfg.ERA5_MAT_ROOT, yyyy, mm, dd);
            if ~isfolder(era5_day_dir)
                error('build_shared_tall_day:MissingERA5Day', ...
                    'ERA5 day directory not found: %s', era5_day_dir);
            end
            missing_hours = [];
            for hh = 0:23
                era5_file = fullfile(era5_day_dir, ...
                    sprintf('ERA5_%s_%02d.mat', yyyymmdd, hh));
                if ~isfile(era5_file), missing_hours(end+1) = hh; %#ok<AGROW>
                end
            end
            if ~isempty(missing_hours)
                missing_text = sprintf('%02d ', missing_hours);
                error('build_shared_tall_day:IncompleteERA5Day', ...
                    'ERA5 day is incomplete for %s. Missing UTC hours: %s', ...
                    date_str, strtrim(missing_text));
            end
            output_path = build_calipso_step1_day(date_str, 'mat', ...
                common_args{:}, 'ERA5Dir', era5_day_dir);
    end

    fprintf('\n=== SHARED T_ALL STAGING BUILD ===\n');
    fprintf('date             = %s\n', date_str);
    fprintf('scenario         = %s\n', scenario_name);
    fprintf('CALIPSO source   = MAT only\n');
    fprintf('canonical AP     = %s\n', ap_file);
    fprintf('product_key      = %s\n', product_key);
    fprintf('staging output   = %s\n', output_path);

    % Staging build receipt.  Patch 06-3 publisher requires this receipt
    % before any staging output can become a formal shared product.
    receipt = struct();
    receipt.date = date_str;
    receipt.scenario = scenario_name;
    receipt.product_key = product_key;
    receipt.calipso_source_type = 'mat';
    receipt.calipso_hdf_used = false;
    receipt.canonical_ap_file = ap_file;
    receipt.start_file = opt.StartFile;
    receipt.max_files = opt.MaxFiles;
    receipt.full_day_requested = (opt.StartFile == 1) && isinf(opt.MaxFiles);
    receipt.output_path = output_path;
    receipt.ap_version = v.AP_VERSION;
    receipt.adapter_version = v.TALL_ADAPTER_VERSION;
    receipt.qc_version = v.TALL_QC_VERSION;
    receipt.rh_mode = sc.rh_mode;
    receipt.rh_source = sc.rh_source;
    receipt.created_time = char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
    if strcmp(scenario_name, 'era5_real')
        receipt.era5_required = true;
        receipt.era5_day_dir = era5_day_dir;
        receipt.era5_complete = true;
    else
        receipt.era5_required = false;
        receipt.era5_day_dir = '';
        receipt.era5_complete = false;
    end

    save(fullfile(stage_dir, '_BUILD_RECEIPT.mat'), 'receipt');
    receipt_txt = fullfile(stage_dir, '_BUILD_RECEIPT.txt');
    fid = fopen(receipt_txt, 'w');
    if fid < 0
        error('build_shared_tall_day:ReceiptWriteFailed', ...
            'Cannot write staging receipt.');
    end
    receipt_cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, 'date=%s\n', receipt.date);
    fprintf(fid, 'scenario=%s\n', receipt.scenario);
    fprintf(fid, 'product_key=%s\n', receipt.product_key);
    fprintf(fid, 'calipso_source_type=mat\n');
    fprintf(fid, 'calipso_hdf_used=false\n');
    fprintf(fid, 'canonical_ap_file=%s\n', receipt.canonical_ap_file);
    fprintf(fid, 'start_file=%d\n', receipt.start_file);
    if isinf(receipt.max_files)
        fprintf(fid, 'max_files=Inf\n');
    else
        fprintf(fid, 'max_files=%d\n', receipt.max_files);
    end
    fprintf(fid, 'full_day_requested=%d\n', receipt.full_day_requested);
    fprintf(fid, 'rh_mode=%s\n', receipt.rh_mode);
    fprintf(fid, 'rh_source=%s\n', receipt.rh_source);
    fprintf(fid, 'era5_required=%d\n', receipt.era5_required);
    fprintf(fid, 'era5_complete=%d\n', receipt.era5_complete);
    fprintf(fid, 'output_path=%s\n', receipt.output_path);
    fprintf(fid, 'created_time=%s\n', receipt.created_time);
end
