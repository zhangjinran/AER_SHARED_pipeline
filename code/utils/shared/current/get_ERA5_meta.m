function meta = get_ERA5_meta(ERA5_DIR)
%GET_ERA5_META Load a sidecar when present, otherwise derive from hourly MATs.
% Cache is keyed by directory so a multi-day batch cannot reuse yesterday's
% time axis accidentally.
persistent CACHED_DIR CACHED_META

ERA5_DIR = char(string(ERA5_DIR));
if isempty(CACHED_DIR) || ~strcmpi(CACHED_DIR, ERA5_DIR)
    sidecar = fullfile(ERA5_DIR, 'ERA5_meta.mat');
    if isfile(sidecar)
        S = load_with_nas_retry(sidecar, 'meta');
        if ~isfield(S, 'meta')
            error('get_ERA5_meta:MissingMetaVariable', ...
                '%s does not contain variable meta.', sidecar);
        end
        CACHED_META = S.meta;
    else
        CACHED_META = derive_ERA5_meta_from_hourly(ERA5_DIR);
    end
    CACHED_DIR = ERA5_DIR;
end

meta = CACHED_META;
end
