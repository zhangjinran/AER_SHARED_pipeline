function meta = derive_ERA5_meta_from_hourly(ERA5_DIR)
%DERIVE_ERA5_META_FROM_HOURLY Reconstruct adapter metadata from hourly MATs.
files = dir(fullfile(ERA5_DIR, 'ERA5_????????_??.mat'));
if isempty(files)
    error('derive_ERA5_meta_from_hourly:NoHourlyFiles', ...
        'No hourly ERA5 MAT files found in %s.', ERA5_DIR);
end
[~, order] = sort({files.name});
files = files(order);

first_path = fullfile(files(1).folder, files(1).name);
max_attempts = 5;
for attempt = 1:max_attempts
    try
        M = matfile(first_path);
        ERA5 = M.ERA5;
        if attempt > 1
            fprintf('[ERA5 META READ RETRY PASS] attempt=%d file=%s\n', ...
                attempt, first_path);
        end
        break;
    catch ME
        if attempt == max_attempts
            fprintf(2, '[ERA5 META READ RETRY FAILED] attempts=%d file=%s\n', ...
                max_attempts, first_path);
            rethrow(ME);
        end
        delay_seconds = 2 * attempt;
        fprintf(2, '[ERA5 META READ RETRY] attempt=%d/%d delay=%ds file=%s error=%s\n', ...
            attempt, max_attempts, delay_seconds, first_path, ME.message);
        pause(delay_seconds);
    end
end
required = {'lon','lat','lev','time','height','RH'};
missing = required(~isfield(ERA5, required));
if ~isempty(missing)
    error('derive_ERA5_meta_from_hourly:MissingFields', ...
        'Hourly MAT is missing ERA5 fields: %s', strjoin(missing, ', '));
end

meta.lon = ERA5.lon;
meta.lat = ERA5.lat;
meta.lev = ERA5.lev;
meta.time = nan(1, numel(files));
for k = 1:numel(files)
    token = regexp(files(k).name, '^ERA5_(\d{8})_(\d{2})\.mat$', ...
        'tokens', 'once');
    if isempty(token)
        error('derive_ERA5_meta_from_hourly:BadFilename', ...
            'Cannot parse ERA5 time from %s.', files(k).name);
    end
    meta.time(k) = datenum([token{1} token{2}], 'yyyymmddHH');
end
if numel(meta.lon) < 2 || numel(meta.lat) < 2
    error('derive_ERA5_meta_from_hourly:ShortCoordinates', ...
        'ERA5 longitude/latitude coordinates need at least two points.');
end
meta.dlon = abs(double(meta.lon(2)) - double(meta.lon(1)));
meta.dlat = abs(double(meta.lat(2)) - double(meta.lat(1)));
meta.g = 9.80665;
end
