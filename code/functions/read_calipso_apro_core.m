function data = read_calipso_apro_core(source, source_type)
%READ_CALIPSO_APRO_CORE Read the fields used by the Nd pipeline.
%   DATA = READ_CALIPSO_APRO_CORE(HDF_PATH, 'hdf') reads one source HDF.
%   DATA = READ_CALIPSO_APRO_CORE(MAT_STRUCT, 'mat') reads one entry from
%   day.files and normalizes it to exactly the shapes returned by hdfread.
%
%   This adapter is deliberately read-only. It does not modify the MAT
%   database or the HDF-to-MAT conversion process.

    arguments
        source
        source_type (1,:) char {mustBeMember(source_type, {'hdf','mat'})}
    end

    switch source_type
        case 'hdf'
            data.filename = get_filename(source);
            data.Ext_raw = hdfread(source, '/Extinction_Coefficient_532');
            data.Back_raw = hdfread(source, '/Total_Backscatter_Coefficient_532');
            data.Depol_raw = hdfread(source, '/Particulate_Depolarization_Ratio_Profile_532');
            data.AVD_raw = hdfread(source, '/Atmospheric_Volume_Description');
            data.Lon_raw = hdfread(source, '/Longitude');
            data.Lat_raw = hdfread(source, '/Latitude');
            data.Time_raw = hdfread(source, '/Profile_Time');
            meta_h = hdfread(source, '/metadata', 'Fields', 'Lidar_Data_Altitudes');
            data.alt_axis = meta_h{1};
            if has_hdf_dataset(source, 'Temperature')
                data.Temp_raw = hdfread(source, '/Temperature');
            end

        case 'mat'
            require_fields(source, {
                'filename', 'Extinction_Coefficient_532', ...
                'Total_Backscatter_Coefficient_532', ...
                'Particulate_Depolarization_Ratio_Profile_532', ...
                'Atmospheric_Volume_Description', 'Longitude', ...
                'Latitude', 'Profile_Time', 'Lidar_Data_Altitudes'});

            data.filename = char(source.filename);
            data.Ext_raw = normalize_2d(source.Extinction_Coefficient_532, 399);
            data.Back_raw = normalize_2d(source.Total_Backscatter_Coefficient_532, 399);
            data.Depol_raw = normalize_2d(source.Particulate_Depolarization_Ratio_Profile_532, 399);
            data.AVD_raw = normalize_avd(source.Atmospheric_Volume_Description);
            data.Lon_raw = normalize_profile_triplet(source.Longitude);
            data.Lat_raw = normalize_profile_triplet(source.Latitude);
            data.Time_raw = normalize_profile_triplet(source.Profile_Time);
            data.alt_axis = source.Lidar_Data_Altitudes(:);
            if isfield(source, 'Temperature')
                data.Temp_raw = normalize_2d(source.Temperature, 399);
            end
    end
end

function value = normalize_2d(value, nbin)
    if ismatrix(value) && size(value, 1) == nbin && size(value, 2) ~= nbin
        value = value';
    end
end

function value = normalize_profile_triplet(value)
    if ismatrix(value) && size(value, 1) == 3 && size(value, 2) ~= 3
        value = value';
    end
end

function value = normalize_avd(value)
    % Production MAT layout is [plane, altitude, profile], whereas hdfread
    % returns [profile, altitude, plane].
    if ndims(value) == 3 && size(value, 1) == 2 && size(value, 2) == 399
        value = permute(value, [3 2 1]);
    elseif ndims(value) == 2 && size(value, 1) == 399
        value = value';
    end
end

function require_fields(s, names)
    missing = names(~isfield(s, names));
    if ~isempty(missing)
        error('CALIPSO:MissingMatFields', 'MAT entry %s is missing: %s', ...
            get_mat_filename(s), strjoin(missing, ', '));
    end
end

function name = get_mat_filename(s)
    if isfield(s, 'filename'), name = char(s.filename); else, name = '<unknown>'; end
end

function name = get_filename(path)
    [~, stem, ext] = fileparts(path);
    name = [stem ext];
end

function yes = has_hdf_dataset(path, dataset_name)
    info = hdfinfo(path);
    names = cellfun(@(x) x.Name, num2cell(info.SDS), 'UniformOutput', false);
    yes = any(strcmp(names, dataset_name));
end
