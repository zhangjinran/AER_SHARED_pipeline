function cfg = data_roots()
%DATA_ROOTS Canonical paths for the unified CALIPSO-ERA5-AERONET-CCN pipeline.
%
% This file defines locations only.
% It does NOT validate scientific completeness and does NOT modify data.
%
% Architecture policy:
%   - Canonical inputs are read-only.
%   - T_all is a shared derived product.
%   - CALIPSO_STATS is currently a candidate shared product and will become
%     the unique shared statistics product only after Gate D passes.
%
% IMPORTANT:
%   ERA5_MAT_ROOT is currently the target normalized hourly interface.
%   Its full temporal completeness has NOT yet been established.

%% ------------------------------------------------------------------------
% Canonical input layer
% -------------------------------------------------------------------------

cfg.CALIPSO_AP_ROOT = ...
    'Z:\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP';

cfg.ERA5_RAW_ROOT = ...
    'Z:\ERA5\raw\pressure_levels';

cfg.ERA5_MAT_ROOT = ...
    'Z:\ERA5\mat';

cfg.AERONET_ROOT = ...
    'F:\AER_RETRA_CASE\areonet data\delivery\full_20070101_20221231_z05kmap_days';

cfg.PRIOR_ROOT = ...
    'F:\AER_SHARED_PIPELINE\inputs\priors';

%% ------------------------------------------------------------------------
% Unified pipeline
% -------------------------------------------------------------------------

cfg.PROJECT_ROOT = ...
    'F:\AER_SHARED_PIPELINE';

cfg.PIPELINE_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'code');

cfg.CONFIG_ROOT = ...
    fullfile(cfg.PIPELINE_ROOT, 'config');

cfg.ADAPTER_ROOT = ...
    fullfile(cfg.PIPELINE_ROOT, 'adapters');

cfg.SHARED_CODE_ROOT = ...
    fullfile(cfg.PIPELINE_ROOT, 'producers');

cfg.UTILS_ROOT = ...
    fullfile(cfg.PIPELINE_ROOT, 'common');

%% ------------------------------------------------------------------------
% Shared derived layer
% -------------------------------------------------------------------------

% Frozen shared product root.
cfg.SHARED_TALL_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'products','tall','t_all');

% Candidate shared product root.
% This becomes the unique shared CALIPSO_STATS location only after Gate D.
cfg.SHARED_STATS_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'products','chapter5','calipso_stats');

cfg.CCN_GRID_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'products','ccn','ccn_grid');

%% ------------------------------------------------------------------------
% Application-specific outputs
% -------------------------------------------------------------------------

cfg.CHAPTER4_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'runs', 'chapter4');

cfg.CHAPTER4_RUNS_ROOT = ...
    fullfile(cfg.CHAPTER4_ROOT, 'runs');

cfg.CHAPTER5_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'runs', 'chapter5');

cfg.CHAPTER5_RUNS_ROOT = ...
    fullfile(cfg.CHAPTER5_ROOT, 'runs');

cfg.CCN_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'runs', 'ccn');

cfg.CCN_RUNS_ROOT = ...
    fullfile(cfg.CCN_ROOT, 'runs');

%% ------------------------------------------------------------------------
% Documentation
% -------------------------------------------------------------------------

cfg.DOCS_ROOT = ...
    fullfile(cfg.PROJECT_ROOT, 'docs');

%% ------------------------------------------------------------------------
% Architectural metadata
% -------------------------------------------------------------------------

cfg.CALIPSO_AP_ROLE = 'canonical_read_only';
cfg.ERA5_RAW_ROLE   = 'canonical_read_only';
cfg.ERA5_MAT_ROLE   = 'target_normalized_interface_read_only';
cfg.AERONET_ROLE    = 'canonical_read_only';
cfg.PRIOR_ROLE      = 'canonical_read_only';

cfg.TALL_ROLE       = 'shared_derived_frozen';
cfg.STATS_ROLE      = 'candidate_shared_until_gate_d';

end
