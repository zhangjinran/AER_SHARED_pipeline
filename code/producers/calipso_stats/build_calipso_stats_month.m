function summary = build_calipso_stats_month(year_value, month_value, output_path, varargin)
%BUILD_CALIPSO_STATS_MONTH Merge published daily CALIPSO_STATS into one month.
%   This is a structural aggregation only: existing Type*.data tables are
%   concatenated unchanged. It performs no CALIPSO, ERA5, or microphysics
%   calculation. The output preserves the legacy CALIPSO_STATS.grid contract
%   consumed by Chapter 4.

    p = inputParser;
    p.addRequired('year_value', @(x) isnumeric(x) && isscalar(x));
    p.addRequired('month_value', @(x) isnumeric(x) && isscalar(x));
    p.addRequired('output_path', @(x) ischar(x) || isstring(x));
    p.addParameter('InputRoot', '', @(x) ischar(x) || isstring(x));
    p.addParameter('DateInventoryPath', '', @(x) ischar(x) || isstring(x));
    parse(p, year_value, month_value, output_path, varargin{:});
    output_path = char(p.Results.output_path);

    producer_dir = fileparts(mfilename('fullpath'));
    code_root = fileparts(fileparts(producer_dir));
    project_root = fileparts(code_root);
    input_root = char(p.Results.InputRoot);
    if isempty(input_root)
        input_root = fullfile(project_root, 'products','chapter5','calipso_stats', ...
            'stats__ap-final-v1__era5-real__adapter-v1__qc-v1__stats-v1');
    end

    yyyy = sprintf('%04d', year_value);
    mm = sprintf('%02d', month_value);
    month_names = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
    month_name = month_names{month_value};
    daynight_names = {'Day','Night'};
    inventory_path=char(p.Results.DateInventoryPath);
    if isempty(inventory_path)
        date_list=string(datestr(datetime(year_value,month_value,1):caldays(1):dateshift(datetime(year_value,month_value,1),'end','month'),'yyyy-MM-dd'))';
    else
        addpath(fullfile(project_root,'code','common'),'-begin');
        [date_list,~]=read_finalized_dates(inventory_path);
    end

    % Cells avoid repeatedly rebuilding the 36x72 struct while source days
    % are read one at a time. Each populated cell contains one unchanged table.
    buckets = cell(36, 72, 2, 7);
    processed_dates = strings(0,1);
    missing_dates = strings(0,1);
    input_paths = strings(0,1);

    for k = 1:numel(date_list)
        dtime=datetime(date_list(k),'InputFormat','yyyy-MM-dd');
        ymd = datestr(dtime,'yyyymmdd'); d=str2double(datestr(dtime,'dd'));
        stats_path = fullfile(input_root, yyyy, mm, sprintf('%02d',d), ...
            ['CALIPSO_STATS_' ymd '.mat']);
        success_path = fullfile(fileparts(stats_path), '_SUCCESS');
        if ~isfile(stats_path) || ~isfile(success_path)
            error('Coverage:MissingDailyStats','Frozen ready date lacks daily Stats: %s',ymd);
        end

        S = load_with_nas_retry(stats_path, 'CALIPSO_STATS');
        G = S.CALIPSO_STATS.grid;
        for i = 1:36
            for j = 1:72
                for dn_i = 1:2
                    dn = daynight_names{dn_i};
                    if ~isfield(G(i,j),dn) || ~isfield(G(i,j).(dn),month_name), continue; end
                    M = G(i,j).(dn).(month_name);
                    for type_i = 1:7
                        type_name = sprintf('Type%d', type_i);
                        if ~isfield(M,type_name) || ~isfield(M.(type_name),'data'), continue; end
                        T = M.(type_name).data;
                        if isempty(T), continue; end
                        if isempty(buckets{i,j,dn_i,type_i})
                            buckets{i,j,dn_i,type_i} = T;
                        else
                            buckets{i,j,dn_i,type_i} = [buckets{i,j,dn_i,type_i}; T]; %#ok<AGROW>
                        end
                    end
                end
            end
        end
        processed_dates(end+1,1) = string(ymd); %#ok<AGROW>
        input_paths(end+1,1) = string(stats_path); %#ok<AGROW>
        clear S G T M
        fprintf('[%d/%d] %s accumulated\n', k, numel(date_list), ymd);
    end

    CALIPSO_STATS = struct();
    CALIPSO_STATS.meta.grid_size = 5;
    CALIPSO_STATS.meta.daynight = daynight_names;
    CALIPSO_STATS.meta.months = month_names;
    CALIPSO_STATS.meta.aerosol_types = 1:7;
    CALIPSO_STATS.meta.period = sprintf('%04d-%02d', year_value, month_value);
    CALIPSO_STATS.meta.source_daily_product_root = input_root;
    CALIPSO_STATS.meta.processed_dates = processed_dates;
    CALIPSO_STATS.meta.missing_dates = missing_dates;
    CALIPSO_STATS.meta.schema_version = 'stats-monthly-v1';
    CALIPSO_STATS.grid(36,72) = struct();
    for i = 1:36
        for j = 1:72
            CALIPSO_STATS.grid(i,j).lat_range = [-90+(i-1)*5, -90+i*5];
            CALIPSO_STATS.grid(i,j).lon_range = [-180+(j-1)*5, -180+j*5];
            for dn_i = 1:2
                for type_i = 1:7
                    T = buckets{i,j,dn_i,type_i};
                    if isempty(T), continue; end
                    dn = daynight_names{dn_i};
                    type_name = sprintf('Type%d', type_i);
                    CALIPSO_STATS.grid(i,j).(dn).(month_name).(type_name).data = T;
                end
            end
        end
    end

    output_dir = fileparts(output_path);
    if ~isfolder(output_dir), mkdir(output_dir); end
    temp_path = [tempname(output_dir) '.mat'];
    cleanup = onCleanup(@() delete_if_present(temp_path)); %#ok<NASGU>
    save(temp_path, 'CALIPSO_STATS', '-v7.3');
    movefile(temp_path, output_path, 'f');

    summary = struct('output_path',output_path, 'processed_dates',processed_dates, ...
        'missing_dates',missing_dates, 'input_paths',input_paths);
    fprintf('MONTHLY_CALIPSO_STATS saved processed=%d missing=%d output=%s\n', ...
        numel(processed_dates), numel(missing_dates), output_path);
end

function delete_if_present(path_value)
    if isfile(path_value), delete(path_value); end
end
