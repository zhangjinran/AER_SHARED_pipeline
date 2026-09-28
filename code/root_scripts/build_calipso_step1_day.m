function output_path = build_calipso_step1_day(date_str, source_type, varargin)
%BUILD_CALIPSO_STEP1_DAY Build the step-1 T_all table from HDF or day MAT.
%   Both source modes use the same calculation code after input adaptation.

    p = inputParser;
    addRequired(p, 'date_str', @(x) ischar(x) || isstring(x));
    addRequired(p, 'source_type', @(x) any(strcmp(x, {'hdf','mat'})));
    addParameter(p, 'HdfRoot', 'Z:\05kmAP', @(x) ischar(x) || isstring(x));
    addParameter(p, 'MatRoot', 'Z:\CALIPSO_MAT_DB\data\05kmAP', @(x) ischar(x) || isstring(x));
    addParameter(p, 'ERA5Dir', fullfile(fileparts(mfilename('fullpath')), 'ERA5_CACHE'), @(x) ischar(x) || isstring(x));
    addParameter(p, 'OutputDir', fullfile(fileparts(mfilename('fullpath')), 'output_integrated', 'adapter_equivalence'), @(x) ischar(x) || isstring(x));
    addParameter(p, 'MaxFiles', inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'StartFile', 1, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(p, 'Scenario', [], @(x) isempty(x) || isstruct(x));
    parse(p, date_str, source_type, varargin{:});
    opt = p.Results;

    script_dir = fileparts(mfilename('fullpath'));
    code_root = fileparts(script_dir);
    project_root = fileparts(code_root);
    addpath(fullfile(code_root, 'functions'));
    dt = datetime(date_str, 'InputFormat', 'yyyy-MM-dd');
    year_text = datestr(dt, 'yyyy');
    day_text = datestr(dt, 'yyyy_mm_dd');
    % RH scenario selection.  An omitted Scenario preserves legacy ERA5 behavior.
    if isempty(opt.Scenario)
        scenario = struct('rh_mode', 'legacy_era5', 'rh_source', 'ERA5');
    else
        scenario = opt.Scenario;
        if ~isfield(scenario, 'rh_mode')
            error('build_calipso_step1_day:InvalidScenario', ...
                'Scenario must contain field rh_mode.');
        end
    end
    rh_mode = lower(char(scenario.rh_mode));
    switch rh_mode
        case 'virtual_rh50'
            if ~isfield(scenario, 'rh_value') || ...
                    ~isscalar(scenario.rh_value) || ~isfinite(scenario.rh_value)
                error('build_calipso_step1_day:InvalidVirtualRH', ...
                    'virtual_rh50 requires a finite scalar scenario.rh_value.');
            end
            ERA5_DIR = '';
            meta = [];
        case {'era5_real', 'era5_flowtest', 'legacy_era5'}
            ERA5_DIR = char(opt.ERA5Dir);
            meta = get_ERA5_meta(ERA5_DIR);
        otherwise
            error('build_calipso_step1_day:UnknownRHMode', ...
                'Unsupported rh_mode: %s', rh_mode);
    end

    if strcmp(source_type, 'hdf')
        inputs = dir(fullfile(char(opt.HdfRoot), year_text, day_text, '*.hdf'));
        [~, order] = sort({inputs.name}); inputs = inputs(order);
        count = numel(inputs);
    else
        mat_path = fullfile(char(opt.MatRoot), year_text, [day_text '.mat']);
        loaded = load_with_nas_retry(mat_path, 'day'); day = loaded.day;
        [~, order] = sort(cellfun(@(x) char(x.filename), day.files, 'UniformOutput', false));
        day.files = day.files(order);
        inputs = day.files;
        count = numel(day.files);
    end
    first_file = min(count, floor(opt.StartFile));
    last_file = min(count, first_file + floor(opt.MaxFiles) - 1);
    if first_file > count, error('StartFile exceeds available inputs for %s', date_str); end
    inputs = inputs(first_file:last_file);
    count = numel(inputs);
    if strcmp(source_type, 'hdf')
        reader = @(i) read_calipso_apro_core(fullfile(inputs(i).folder, inputs(i).name), 'hdf');
    else
        reader = @(i) read_calipso_apro_core(inputs{i}, 'mat');
    end
    if count == 0, error('No inputs found for %s', date_str); end

    all_data = cell(count, 1);
    kept = false(count, 1);
    for i = 1:count
        raw = reader(i);
        T_file = core_to_table(raw, meta, ERA5_DIR, scenario);
        if ~isempty(T_file)
            all_data{i} = T_file;
            kept(i) = true;
        end
        fprintf('[%s %d/%d] %s: %d rows\n', upper(source_type), i, count, raw.filename, height(T_file));
    end
    if ~any(kept), error('No valid aerosol pixels were produced.'); end
    T_all = vertcat(all_data{kept}); %#ok<NASGU>
    T_all.Properties.UserData=struct('geolocation_contract','native-profile-center-v2', ...
        'time_order','native-profile-center','era5_spatial_index','actual-axis-periodic-longitude');

    output_dir = char(opt.OutputDir);
    if ~isfolder(output_dir), mkdir(output_dir); end
    output_path = fullfile(output_dir, sprintf('CALIPSO_results_%s_%s.mat', day_text, source_type));
    temp_path = [tempname(output_dir) '.mat'];
    temp_cleanup = onCleanup(@() delete_if_exists(temp_path)); %#ok<NASGU>
    save(temp_path, 'T_all', '-v7.3');
    [move_ok, move_msg] = movefile(temp_path, output_path, 'f');
    if ~move_ok
        error('build_calipso_step1_day:AtomicPublishFailed', ...
            'Could not move completed staging MAT to %s: %s', output_path, move_msg);
    end
    fprintf('Saved %d rows: %s\n', height(T_all), output_path);
end

function delete_if_exists(file_path)
if isfile(file_path)
    delete(file_path);
end
end

function T_file = core_to_table(raw, meta, ERA5_DIR, scenario)
    Ext = double(raw.Ext_raw(:,:,1)); Back = double(raw.Back_raw(:,:,1));
    Depol = double(raw.Depol_raw(:,:,1)); AVD = uint16(raw.AVD_raw(:,:,1));
    if size(Ext,1)==399, Ext=Ext'; end
    if size(Back,1)==399, Back=Back'; end
    if size(Depol,1)==399, Depol=Depol'; end
    if size(AVD,1)==399, AVD=AVD'; end
    N_prof = size(Ext,1); N_bin = 399;

    ext_1d=Ext(:); back_1d=Back(:); depol_1d=Depol(:); avd_1d=AVD(:);
    Lon_raw=double(raw.Lon_raw); Lat_raw=double(raw.Lat_raw); Time_raw=double(raw.Time_raw);
    Lon=calipso_profile_center(Lon_raw,N_prof);
    Lat=calipso_profile_center(Lat_raw,N_prof);
    Time_vec=calipso_profile_center(Time_raw,N_prof);
    utc_dn_prof=Time_vec/86400+datenum(1993,1,1);
    alt_axis=double(raw.alt_axis);
    lon_1d=reshape(repmat(Lon(:),1,N_bin),[],1);
    lat_1d=reshape(repmat(Lat(:),1,N_bin),[],1);
    time_1d=reshape(repmat(utc_dn_prof(:),1,N_bin),[],1);
    alt_1d=reshape(repmat(alt_axis(:)',N_prof,1),[],1);

    feature_type=bitand(avd_1d,uint16(7));
    type_1d=bitand(bitshift(avd_1d,-9),uint16(7));
    type_1d(feature_type~=3)=0; type_1d=double(type_1d);
    valid=(type_1d>0)&(ext_1d>0)&(back_1d>0)&(depol_1d>=0)& ...
        isfinite(ext_1d)&isfinite(back_1d)&isfinite(depol_1d);
    if ~any(valid), T_file=table(); return; end

    nv=sum(valid); T_file=table();
    T_file.FileName=repmat({raw.filename},nv,1);
    T_file.Lon=lon_1d(valid); T_file.Lat=lat_1d(valid); T_file.Height=alt_1d(valid);
    T_file.Ext=ext_1d(valid); T_file.Back=back_1d(valid); T_file.Depol=depol_1d(valid);
    T_file.LR=ext_1d(valid)./back_1d(valid); T_file.Type=type_1d(valid); T_file.UTC=time_1d(valid);
    if contains(raw.filename,'ZN')||contains(raw.filename,'Night')
        T_file.DayNight=repmat("Night",nv,1);
    else
        T_file.DayNight=repmat("Day",nv,1);
    end

    rh_mode = lower(char(scenario.rh_mode));
    if ~strcmp(rh_mode,'virtual_rh50')
        [era_lon_index,era_lat_index]=era5_spatial_indices(T_file.Lon,T_file.Lat,meta);
    end
    switch rh_mode
        case 'virtual_rh50'
            RH_v = repmat(double(scenario.rh_value), height(T_file), 1);
        case {'era5_real', 'legacy_era5'}
            RH_v=NaN(nv,1);
            t_idx=round(interp1(datenum(meta.time),1:numel(meta.time),T_file.UTC,'nearest','extrap'));
            for ut=unique(t_idx)'
                era_f=fullfile(ERA5_DIR,sprintf('ERA5_%s.mat',datestr(meta.time(ut),'yyyymmdd_HH')));
                if ~isfile(era_f), continue; end
                E=load_era5_hour_with_retry(era_f); pts=find(t_idx==ut);
                for ii=1:numel(pts)
                    idx=pts(ii);
                    lon_ix=era_lon_index(idx); lat_ix=era_lat_index(idx);
                    h_p=squeeze(E.ERA5.height(lon_ix,lat_ix,:)); r_p=squeeze(E.ERA5.RH(lon_ix,lat_ix,:));
                    % Formal ERA5 gate: no reordering/repair/extrapolation.
                    % Surface-pressure masking is intentionally not part of
                    % this adapter; valid profiles need finite, strictly
                    % increasing heights and at least two levels.
                    if numel(h_p)>=2 && all(isfinite(h_p)) && all(diff(h_p)>0)
                        RH_v(idx)=interp1(h_p,r_p,T_file.Height(idx)*1000,'linear',NaN);
                    end
                end
            end
        case 'era5_flowtest'
            RH_v=NaN(nv,1);
            diag=struct('query_total',0,'query_below_min',0,'query_above_max',0, ...
                'query_inside_range',0,'query_inside_but_nan',0,'query_finite_rh',0, ...
                'profiles_total',0,'profiles_trimmed',0,'levels_removed_negative',0, ...
                'profiles_nonmonotonic',0,'rh_nan_level_count',0, ...
                'profiles_with_rh_nan',0,'profiles_unusable',0);
            t_idx=round(interp1(datenum(meta.time),1:numel(meta.time),T_file.UTC,'nearest','extrap'));
            for ut=unique(t_idx)'
                era_f=fullfile(ERA5_DIR,sprintf('ERA5_%s.mat',datestr(meta.time(ut),'yyyymmdd_HH')));
                if ~isfile(era_f), continue; end
                E=load_era5_hour_with_retry(era_f); pts=find(t_idx==ut);
                for ii=1:numel(pts)
                    idx=pts(ii);
                    lon_ix=era_lon_index(idx); lat_ix=era_lat_index(idx);
                    h_p=squeeze(E.ERA5.height(lon_ix,lat_ix,:)); r_p=squeeze(E.ERA5.RH(lon_ix,lat_ix,:));
                    [h_use,r_use,pdiag]=prepare_era5_profile_flowtest(h_p,r_p);
                    diag.profiles_total=diag.profiles_total+1;
                    diag.profiles_trimmed=diag.profiles_trimmed+pdiag.trimmed;
                    diag.levels_removed_negative=diag.levels_removed_negative+pdiag.removed_negative;
                    diag.profiles_nonmonotonic=diag.profiles_nonmonotonic+double(pdiag.nonmonotonic);
                    diag.rh_nan_level_count=diag.rh_nan_level_count+pdiag.rh_nan_levels;
                    diag.profiles_with_rh_nan=diag.profiles_with_rh_nan+double(pdiag.has_rh_nan);
                    if numel(h_use)>=2
                        q=T_file.Height(idx)*1000;
                        below=q<h_use(1); above=q>h_use(end); inside=~(below|above);
                        rh_q=interp1(h_use,r_use,q,'linear',NaN);
                        diag.query_total=diag.query_total+1;
                        diag.query_below_min=diag.query_below_min+nnz(below);
                        diag.query_above_max=diag.query_above_max+nnz(above);
                        diag.query_inside_range=diag.query_inside_range+nnz(inside);
                        diag.query_inside_but_nan=diag.query_inside_but_nan+nnz(inside&~isfinite(rh_q));
                        diag.query_finite_rh=diag.query_finite_rh+nnz(isfinite(rh_q));
                        RH_v(idx)=rh_q;
                    else
                        diag.profiles_unusable=diag.profiles_unusable+1;
                    end
                end
            end
            fprintf(['FLOWTEST_DIAG profiles_total=%d profiles_trimmed=%d ' ...
                'levels_removed_negative=%d profiles_nonmonotonic=%d ' ...
                'profiles_with_rh_nan=%d rh_nan_level_count=%d profiles_unusable=%d query_total=%d ' ...
                'below_min=%d above_max=%d inside_range=%d inside_but_nan=%d finite_rh=%d\n'], ...
                diag.profiles_total,diag.profiles_trimmed,diag.levels_removed_negative, ...
                diag.profiles_nonmonotonic,diag.profiles_with_rh_nan,diag.rh_nan_level_count,diag.profiles_unusable, ...
                diag.query_total,diag.query_below_min,diag.query_above_max, ...
                diag.query_inside_range,diag.query_inside_but_nan,diag.query_finite_rh);
        otherwise
            error('build_calipso_step1_day:UnknownRHMode', ...
                'Unsupported rh_mode in core_to_table: %s', rh_mode);
        end
    T_file.RH=RH_v;
end

function E = load_era5_hour_with_retry(era_f)
% NAS-backed ERA5 MAT reads can fail transiently. Retry without changing
% file contents or scientific processing, then preserve the final error.
max_attempts = 5;
for attempt = 1:max_attempts
    try
        E = load_with_nas_retry(era_f, 'ERA5');
        if ~isfield(E, 'ERA5')
            error('build_calipso_step1_day:MissingERA5Variable', ...
                '%s does not contain variable ERA5.', era_f);
        end
        if attempt > 1
            fprintf('[ERA5 READ RETRY PASS] attempt=%d file=%s\n', attempt, era_f);
        end
        return;
    catch ME
        if attempt == max_attempts
            fprintf(2, '[ERA5 READ RETRY FAILED] attempts=%d file=%s\n', ...
                max_attempts, era_f);
            rethrow(ME);
        end
        delay_seconds = 2 * attempt;
        fprintf(2, '[ERA5 READ RETRY] attempt=%d/%d delay=%ds file=%s error=%s\n', ...
            attempt, max_attempts, delay_seconds, era_f, ME.message);
        pause(delay_seconds);
    end
end
end

function [h_use, r_use, pdiag] = prepare_era5_profile_flowtest(h_p, r_p)
% Flow-test rule: reject malformed profiles; never repair or reorder them.
    h=double(h_p(:)); r=double(r_p(:));
    pdiag=struct('trimmed',0,'removed_negative',0,'nonmonotonic',false, ...
        'unusable',false,'rh_nan_levels',nnz(~isfinite(r)), ...
        'has_rh_nan',any(~isfinite(r)));
    keep=isfinite(h) & h>=0;
    pdiag.removed_negative=nnz(~keep);
    h=h(keep); r=r(keep);
    pdiag.trimmed=pdiag.removed_negative>0;
    if numel(h)<2
        h_use=[]; r_use=[]; pdiag.unusable=true; return
    end
    if any(diff(h)<=0)
        h_use=[]; r_use=[];
        pdiag.nonmonotonic=true; pdiag.unusable=true; return
    end
    h_use=h; r_use=r;
end
