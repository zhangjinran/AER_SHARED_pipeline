function cfg = aod_config()
%AOD_CONFIG Isolated configuration for T_all-based APro column AOD.
cfg.project_root = 'F:\AER_SHARED_PIPELINE';
cfg.tall_product_key = 'tall__ap-final-v1__era5-real__adapter-v1__qc-v1';
cfg.code_root = fullfile(cfg.project_root,'code','aod');
cfg.daily_key = 'aod__tall-apro-v1__ext-direct-ch5ccn-components-v1__grid5deg-v1';
cfg.monthly_key = 'aod-month__tall-apro-v1__ext-direct-ch5ccn-components-v1__grid5deg-pooled-v1';
cfg.daily_root = fullfile(cfg.project_root,'products','aod','aod_grid_day',cfg.daily_key);
cfg.monthly_root = fullfile(cfg.project_root,'products','aod','aod_grid_month',cfg.monthly_key);
cfg.run_root = fullfile(cfg.project_root,'runs','aod');
cfg.grid.lat_edges = -90:5:90;
cfg.grid.lon_edges = -180:5:180;
cfg.vertical_uniform_tolerance_km = 1e-5;
% Value-domain gates copied from the inspected APro product metadata/source
% AOD routine; they are QA bounds, not aerosol priors.
cfg.extinction_max_km_inv = 1.25;
cfg.backscatter_max_km_inv_sr = 0.05;
cfg.depolarization_range = [0 1];
cfg.components = {'Marine','Dust','Polluted_Continental','Clean_Continental', ...
    'Polluted_Dust','Elevated_Smoke','Dusty_Marine','Total'};
cfg.method_names = {'Direct_APro_Extinction','Chapter5_CCN_Component_Reconstruction'};
addpath(fullfile(cfg.project_root,'code','CCN_v2','config'),'-begin');
cfg.ccn_v2 = ccn_v2_config();
cfg.lidar_ratio = cfg.ccn_v2.lidar_ratio;
cfg.depol_nondust = cfg.ccn_v2.depol_nondust;
cfg.depol_dust = cfg.ccn_v2.depol_dust;
end
