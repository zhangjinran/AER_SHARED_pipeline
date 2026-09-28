function meta = get_ERA5_meta(ERA5_DIR)
% Compatibility copy for the legacy non-ASCII function directory.
persistent CACHED_DIR CACHED_META
ERA5_DIR = char(string(ERA5_DIR));
if isempty(CACHED_DIR) || ~strcmpi(CACHED_DIR, ERA5_DIR)
    sidecar = fullfile(ERA5_DIR, 'ERA5_meta.mat');
    if isfile(sidecar)
        S = load(sidecar, 'meta');
        CACHED_META = S.meta;
    else
        function_root = fileparts(fileparts(mfilename('fullpath')));
        addpath(function_root);
        CACHED_META = derive_ERA5_meta_from_hourly(ERA5_DIR);
    end
    CACHED_DIR = ERA5_DIR;
end
meta = CACHED_META;
end
