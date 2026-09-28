function cfg = ccn_v2_config()
%CCN_V2_CONFIG Frozen scientific and filesystem contract for CCN OMCAM v2.

cfg.schema_version = 'ccn-omcam-v2';
cfg.project_root = 'F:\AER_SHARED_PIPELINE';
cfg.code_root = fullfile(cfg.project_root, 'code', 'CCN_v2');
cfg.prior_root = fullfile(cfg.project_root, 'inputs', 'priors', 'ccn_v2');
cfg.day_product_root = fullfile(cfg.project_root, 'products','ccn','ccn_v2', 'ccn_grid_day');
cfg.month_product_root = fullfile(cfg.project_root, 'products','ccn','ccn_v2', 'ccn_grid_monthly');

cfg.product_key = 'ccnv2__tall-v1__era5-rh__omcam-v2__grid2x5-z60';
run_product_key = getenv('CCN_V2_PRODUCT_KEY');
if ~isempty(run_product_key), cfg.product_key = run_product_key; end
cfg.product_name = 'CCN OMCAM v2 from project T_all';
cfg.strict_essd_reproduction = false;
cfg.rh_source = 'ERA5';
cfg.clear_air_in_denominator = false;
cfg.averaging_definition = 'conditional_mean_over_retained_aerosol_samples';

cfg.component_names = { ...
    'marine', 'dust', 'polluted_continental', ...
    'clean_continental', 'elevated_smoke'};
cfg.component_ids = struct( ...
    'marine', 1, 'dust', 2, 'polluted_continental', 3, ...
    'clean_continental', 4, 'elevated_smoke', 5);

cfg.depol_nondust = 0.05;
cfg.depol_dust = 0.31;
cfg.lidar_ratio = struct('dust', 44, ...
    'polluted_continental', 70, 'marine', 23);
cfg.cutoff_um = struct('dust', 0.10, 'nondust', 0.05);
cfg.radius_max_um = 15;
cfg.supersaturation_percent = [0.20, 0.25, 0.40];
cfg.supersaturation_factor = [1.00, 1.35, 1.70];

cfg.grid.lat_edges = -90:2:90;
cfg.grid.lon_edges = -180:5:180;
cfg.grid.altitude_min_km = 0;
cfg.grid.altitude_max_km = 8;
cfg.grid.expected_altitude_levels = 133;
cfg.grid.altitude_source = 'canonical_CALIPSO_Lidar_Data_Altitudes';

% Validated by Phase-1 ACP Table-4 conversion-factor Unit Gate on 2026-09-21.
% Converts CALIPSO alpha [km^-1] / normalized alpha [Mm^-1] to the
% volume scale used by the OMCAM number integral.
cfg.units.volume_scale_conversion = 1e9;
cfg.units.normalized_extinction = 'Mm^-1';
cfg.units.calipso_extinction = 'km^-1';
cfg.units.status = 'VALIDATED_UNIT_GATE_V1';

cfg.parameters = component_parameters();
end

function p = component_parameters()
p = struct();
p.marine = make_component([0.14 0.86], [0.1137 1.8756], ...
    [1.6487 2.0544], [1.5478 1.4108], [0.0053 0], 0.7, 'sphere');
p.dust = make_component([0.223 0.777], [0.1165 2.8329], ...
    [1.4813 1.9078], [1.414 1.414], [0.0036 0.0036], 0, 'spheroid');
p.polluted_continental = make_component([0.531 0.469], [0.1577 3.547], ...
    [1.5257 2.065], [1.404 1.404], [0.0063 0.0063], 0.3, 'sphere');
p.clean_continental = make_component([0.050 0.950], [0.20556 2.6334], ...
    [1.61 1.8987], [1.380 1.455], [0.0001 0.0034], 0.3, 'sphere');
p.elevated_smoke = make_component([0.329 0.671], [0.1436 3.726], ...
    [1.5624 2.1426], [1.517 1.517], [0.0234 0.0234], 0.3, 'sphere');
end

function s = make_component(v, r, gsd, mr, mi, kappa, shape)
s = struct('volume_fraction', v, 'mean_radius_um', r, ...
    'geometric_std', gsd, 'ri_real', mr, 'ri_imag', mi, ...
    'kappa', kappa, 'shape', shape);
end
