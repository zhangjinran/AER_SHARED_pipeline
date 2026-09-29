function cfg=aod_apro_config()
% APro-only profile-first AOD contract; no T_all dependency.
cfg.project_root=fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
cfg.code_root=fullfile(cfg.project_root,'code','utils','aod','aodv2');
addpath(fullfile(cfg.project_root,'code','utils','shared','config'));
roots=data_roots(); cfg.input_root=roots.CALIPSO_AP_ROOT;
cfg.profile_key='aod-profile__global-apro__avd2__column-v2';
cfg.grid_key='aod-grid__global-apro__avd2__profile-mean__grid5deg-v2';
cfg.month_key='aod-month__global-apro__avd2__profile-pooled__grid5deg-v2';
cfg.month_root=fullfile(cfg.project_root,'products','aod','aod_grid_month',cfg.month_key);
cfg.profile_root=fullfile(cfg.project_root,'products','aod','aod_profile_day',cfg.profile_key);
cfg.grid_root=fullfile(cfg.project_root,'products','aod','aod_grid_day',cfg.grid_key);
cfg.channels={'Marine','Dust','Polluted Continental','Clean Continental', ...
    'Polluted Dust','Elevated Smoke','Dusty Marine','Total'};
cfg.lat_edges=-90:5:90; cfg.lon_edges=-180:5:180;
cfg.ext_max=1.25; cfg.back_max=0.05;
cfg.qc_accept=[0 1 16 18]; % Explicit project filter if source QC is present.
cfg.altitude_transition_km=20.2;
cfg.geometry_tolerance_km=1e-5;
addpath(fullfile(cfg.project_root,'code','utils','ccn','ccnv2','config'));
addpath(fullfile(cfg.project_root,'code','utils','ccn','ccnv2','science_core'));
cfg.ccn=ccn_v2_config();
cfg.averaging='common_valid_profiles_including_absent_type_zero';
cfg.reference='https://ntrs.nasa.gov/api/citations/20260000776/downloads/cal_lid_l2_pro_v5-00_desc_qs.pdf';
end
