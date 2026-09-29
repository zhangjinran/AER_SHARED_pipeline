function [AERONET_Data, Site_Info, Radius, manifest] = read_areonet_all_v3(extracted_root, date_start, date_end, valid_days)
%READ_AERONET_ALL_V3 Read AERONET V3 inversion ALL files into Chapter-4 inputs.
%   This reader is intentionally limited to the 22 dV/dlnr size-distribution
%   columns required by the existing AERONET_Data consumer.

    arguments
        extracted_root (1,:) char
        date_start (1,1) datetime
        date_end (1,1) datetime
        valid_days (:,1) datetime = datetime.empty(0,1)
    end

    if isempty(date_start.TimeZone), date_start.TimeZone = 'UTC'; end
    if isempty(date_end.TimeZone), date_end.TimeZone = 'UTC'; end
    if ~isempty(valid_days) && isempty(valid_days.TimeZone), valid_days.TimeZone = 'UTC'; end
    date_end = dateshift(date_end, 'end', 'day');

    files = dir(fullfile(extracted_root, '**', '*.all'));
    if isempty(files)
        error('AERONET:NoFiles', 'No .all files found below %s.', extracted_root);
    end

    Radius = [0.050000 0.065604 0.086077 0.112939 0.148184 0.194429 ...
              0.255105 0.334716 0.439173 0.576227 0.756052 0.991996 ...
              1.301571 1.707757 2.240702 2.939966 3.857452 5.061260 ...
              6.640745 8.713145 11.432287 15.000000];
    AERONET_Data = struct();
    raw_names = strings(0,1); field_names = strings(0,1);
    lonlat = zeros(0,2); rows = zeros(0,1); source_files = strings(0,1);

    for i = 1:numel(files)
        source_path = fullfile(files(i).folder, files(i).name);
        opts = detectImportOptions(source_path, 'FileType', 'text', ...
            'VariableNamingRule', 'preserve', 'Delimiter', ',');
        fid = fopen(source_path, 'r');
        if fid < 0, error('AERONET:OpenFailed', 'Cannot open %s.', source_path); end
        closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
        header = '';
        for header_line = 1:7, header = fgetl(fid); end
        header_names = string(strsplit(header, ','));
        opts.VariableNames = cellstr(header_names);
        opts.DataLines = [8 Inf];
        required = ["Site", "Date(dd:mm:yyyy)", "Time(hh:mm:ss)", ...
                    "Latitude(Degrees)", "Longitude(Degrees)", "Elevation(m)"];
        expected_radius_names = compose('%.6f', Radius);
        if ~all(ismember([required expected_radius_names], header_names))
            error('AERONET:RequiredField', '%s has an incompatible V3 ALL header.', source_path);
        end
        % Only 28 fields are relevant to the Chapter-4 input; avoid reading
        % the remaining inversion products from every long station record.
        opts.SelectedVariableNames = cellstr([required expected_radius_names]);
        opts = setvartype(opts, cellstr(required(1:3)), 'string');
        T = readtable(source_path, opts);
        if isempty(T), continue; end

        names = string(T.Properties.VariableNames);
        size_cols = find(ismember(names, compose('%.6f', Radius)));
        if numel(size_cols) ~= numel(Radius)
            error('AERONET:RadiusSchema', '%s does not contain the expected 22 radius columns.', source_path);
        end
        if ~all(ismember(required, names))
            error('AERONET:RequiredField', '%s has an incompatible V3 ALL header.', source_path);
        end

        time_utc = datetime(string(T{:,'Date(dd:mm:yyyy)'}) + " " + ...
            string(T{:,'Time(hh:mm:ss)'}), 'InputFormat', 'dd:MM:uuuu HH:mm:ss', ...
            'TimeZone', 'UTC');
        keep = time_utc >= date_start & time_utc <= date_end;
        if ~isempty(valid_days)
            keep = keep & ismember(dateshift(time_utc, 'start', 'day'), valid_days);
        end
        if ~any(keep), continue; end

        site_raw = string(T{find(keep,1,'first'),'Site'});
        base_field = string(matlab.lang.makeValidName(site_raw));
        field = base_field;
        suffix = 2;
        while isfield(AERONET_Data, field)
            if any(raw_names == site_raw), break; end
            field = base_field + "_" + suffix;
            suffix = suffix + 1;
        end
        if isfield(AERONET_Data, field)
            error('AERONET:DuplicateSource', 'The site %s occurs in multiple source files.', site_raw);
        end

        spectrum = double(T{keep, size_cols});
        spectrum(spectrum <= -999) = NaN;
        valid = all(isfinite(spectrum), 2);
        if ~any(valid), continue; end
        keep_idx = find(keep);
        keep_idx = keep_idx(valid);
        q = struct();
        q.Size_Distribution = spectrum(valid,:);
        q.time_UTC = datenum(time_utc(keep_idx));
        q.longitude = double(T{keep_idx(1),'Longitude(Degrees)'});
        q.latitude = double(T{keep_idx(1),'Latitude(Degrees)'});
        q.elevation = double(T{keep_idx,'Elevation(m)'});
        AERONET_Data.(field) = q;

        raw_names(end+1,1) = site_raw; %#ok<AGROW>
        field_names(end+1,1) = field; %#ok<AGROW>
        lonlat(end+1,:) = [q.longitude q.latitude]; %#ok<AGROW>
        rows(end+1,1) = size(q.Size_Distribution,1); %#ok<AGROW>
        source_files(end+1,1) = string(source_path); %#ok<AGROW>
    end

    Site_Info = struct('SiteName', {cellstr(field_names)}, 'LonLat', lonlat);
    manifest = table(raw_names, field_names, lonlat(:,1), lonlat(:,2), rows, source_files, ...
        'VariableNames', {'site_name_raw','matlab_field','longitude','latitude','record_count','source_file'});
end
