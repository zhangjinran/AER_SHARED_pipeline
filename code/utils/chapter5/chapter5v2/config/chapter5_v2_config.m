function cfg = chapter5_v2_config()
%CHAPTER5_V2_CONFIG Frozen Chapter 5 OMCAM-v2 contract.
% References the immutable CCN_v2 priors; it never copies them.

cfg.schema_version = 'chapter5-omcam-v2';
cfg.project_root = 'F:\AER_SHARED_PIPELINE';
cfg.code_root = fullfile(cfg.project_root,'code','utils','chapter5','chapter5v2');
cfg.ccn_v2_root = fullfile(cfg.project_root,'code','utils','ccn','ccnv2');
cfg.prior_root = fullfile(cfg.project_root,'inputs','priors','ccn_v2', ...
    'omcam_v2__acp-table4-unitgate-v1');
cfg.parameter_file = fullfile(cfg.prior_root,'Parameter_OMCAM_v2.mat');
cfg.extinction_file = fullfile(cfg.prior_root,'Extinction_Normalized_v2.mat');
cfg.prior_manifest = fullfile(cfg.prior_root,'manifest.txt');
cfg.stats_product_key = 'stats-ch5v2__tall-v1__era5-rh__omcam-v2__grid5deg__stats-v2';
cfg.map_product_key = 'ch5map__stats-ch5v2__clear-v1__grid5deg__z10km__map-v2';
run_stats_key = getenv('CHAPTER5_V2_STATS_PRODUCT_KEY');
run_map_key = getenv('CHAPTER5_V2_MAP_PRODUCT_KEY');
if ~isempty(run_stats_key), cfg.stats_product_key = run_stats_key; end
if ~isempty(run_map_key), cfg.map_product_key = run_map_key; end
cfg.stats_product_root = fullfile(cfg.project_root,'products','chapter5','calipso_stats_chapter5_v2',cfg.stats_product_key);
cfg.map_product_root = fullfile(cfg.project_root,'products','chapter5','chapter5_map_stats_v2',cfg.map_product_key);
cfg.grid.lat_edges = -90:5:90;
cfg.grid.lon_edges = -180:5:180;
cfg.grid.altitude_limit_km = 10;
cfg.daynight = {'Day','Night'};
cfg.month_names = {'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};

addpath(fullfile(cfg.ccn_v2_root,'config'),'-begin');
base = ccn_v2_config();
cfg.ccn_v2 = base;
cfg.component_names = base.component_names;
cfg.component_ids = base.component_ids;
cfg.depol_nondust = base.depol_nondust;
cfg.depol_dust = base.depol_dust;
cfg.lidar_ratio = base.lidar_ratio;
cfg.cutoff_um = base.cutoff_um;
cfg.radius_max_um = base.radius_max_um;
cfg.volume_scale_conversion = base.units.volume_scale_conversion;
cfg.parameters = base.parameters;
cfg.rh_min = 0;
cfg.rh_max = 99;
cfg.clear_air_in_denominator = true;
cfg.averaging_definition = 'sum_Nd_over_valid_aerosol_plus_clear_air_samples';
cfg.provenance_contract = 'sample_id_and_original_type_retained_until_type_aggregation';
end
