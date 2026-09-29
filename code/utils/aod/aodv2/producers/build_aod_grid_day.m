function AOD_GRID = build_aod_grid_day(tall_path,date_ymd,output_path)
error('AOD:RetiredTAll','T_all AOD v1 retired. Use build_aod_profile_day then build_aod_apro_grid_day.');
%BUILD_AOD_GRID_DAY Build a staging daily 5x5-degree AOD grid from T_all.
cfg = aod_config();
if ~isfile(tall_path), error('AOD:MissingTAll','Missing T_all: %s',tall_path); end
if isfile(output_path), error('AOD:NoOverwrite','Refusing to overwrite candidate: %s',output_path); end
addpath(fullfile(cfg.code_root,'utils'),'-begin');
S = load_aod_mat_retry(tall_path,'T_all');
if ~isfield(S,'T_all'), error('AOD:MissingVariable','Input MAT has no T_all variable.'); end
P = integrate_aod_tall_profiles(S.T_all,cfg);

nlat = numel(cfg.grid.lat_edges)-1; nlon = numel(cfg.grid.lon_edges)-1; nch=8;
sum_direct=zeros(nlat,nlon,nch); count_direct=zeros(nlat,nlon,nch,'uint32');
sum_component=zeros(nlat,nlon,nch); count_component=zeros(nlat,nlon,nch,'uint32');
ii=floor((P.profile_lat+90)/5)+1; jj=floor((P.profile_lon+180)/5)+1;
ii(P.profile_lat==90)=nlat; jj(P.profile_lon==180)=nlon;
inside=isfinite(ii)&isfinite(jj)&ii>=1&ii<=nlat&jj>=1&jj<=nlon;
for c=1:nch
    use=inside & P.direct_profile_count_by_channel(:,c);
    ix=[ii(use),jj(use)];
    sum_direct(:,:,c)=accumarray(ix,P.direct_profile_aod(use,c),[nlat nlon],@sum,0);
    count_direct(:,:,c)=uint32(accumarray(ix,1,[nlat nlon],@sum,0));
    use=inside & P.component_profile_count_by_channel(:,c);
    ix=[ii(use),jj(use)];
    sum_component(:,:,c)=accumarray(ix,P.component_profile_aod(use,c),[nlat nlon],@sum,0);
    count_component(:,:,c)=uint32(accumarray(ix,1,[nlat nlon],@sum,0));
end
mean_direct=nan(nlat,nlon,nch); mean_component=nan(nlat,nlon,nch);
for c=1:nch
    q=count_direct(:,:,c)>0; tmp=nan(nlat,nlon); z=sum_direct(:,:,c); cnt=double(count_direct(:,:,c)); tmp(q)=z(q)./cnt(q); mean_direct(:,:,c)=tmp;
    q=count_component(:,:,c)>0; tmp=nan(nlat,nlon); z=sum_component(:,:,c); cnt=double(count_component(:,:,c)); tmp(q)=z(q)./cnt(q); mean_component(:,:,c)=tmp;
end
meta=struct('schema_version','aod-grid-v1','product_key',cfg.daily_key,'date',date_ymd, ...
    'grid','global_5x5deg','vertical_integration','sum(alpha_km_inv .* layer_thickness_km)', ...
    'method_direct','APro Ext integrated over retained T_all rows', ...
    'method_component','pure types use APro Ext; Type5/7 use frozen CCN-v2 beta split and lidar ratios', ...
    'mixed_type_policy','Type5 dust+polluted_continental; Type7 dust+marine, within profile', ...
    'depol_nondust',cfg.depol_nondust,'depol_dust',cfg.depol_dust, ...
    'lidar_ratio',cfg.lidar_ratio,'height_step_km',P.height_step_km, ...
    'value_bounds',struct('Ext_max_km_inv',cfg.extinction_max_km_inv, ...
        'Back_max_km_inv_sr',cfg.backscatter_max_km_inv_sr,'Depol_range',cfg.depolarization_range), ...
    'profiles',P.profiles,'rows',P.rows,'valid_ext_rows',P.valid_ext_rows, ...
    'rejected_ext_rows',P.rejected_ext_rows,'rejected_mixed_beta_rows',P.rejected_mixed_beta_rows, ...
    'channels',{cfg.components});
AOD_GRID=struct('meta',meta,'sum_direct_ext',sum_direct,'count_direct_ext',count_direct, ...
    'mean_direct_ext',mean_direct,'sum_component_reconstruction',sum_component, ...
    'count_component_reconstruction',count_component,'mean_component_reconstruction',mean_component, ...
    'lat_edges',cfg.grid.lat_edges,'lon_edges',cfg.grid.lon_edges);
outdir=fileparts(output_path); if ~isfolder(outdir),mkdir(outdir);end
save(output_path,'AOD_GRID','-v7.3');
fprintf('AOD_DAY_CANDIDATE_PASS date=%s profiles=%d dz_km=%.9f output=%s\n',date_ymd,P.profiles,P.height_step_km,output_path);
end
