function G=build_aod_apro_grid_day(profile_path,date_ymd,output_path)
assert(~isfile(output_path),'AOD:Overwrite','Grid candidate exists.');
cfg=aod_apro_config(); S=load_aod_mat_retry(profile_path,'AOD_PROFILE'); P=S.AOD_PROFILE;
assert(strcmp(P.meta.date,date_ymd)&&strcmp(P.meta.product_key,cfg.profile_key),'AOD:Input','Profile contract mismatch.');
G=grid_aod_profiles(P,cfg);
G.meta=struct('schema_version','aod-grid-v2','product_key',cfg.grid_key,'date',date_ymd, ...
    'channels',{cfg.channels},'source_profile_key',cfg.profile_key,'qc_used',P.meta.qc_used, ...
    'averaging',cfg.averaging,'common_valid_profiles',nnz(P.valid_for_grid), ...
    'zero_aerosol_profiles',P.meta.zero_aerosol_profiles,'source_profile', ...
    fullfile(cfg.profile_root,date_ymd(1:4),date_ymd(5:6),date_ymd(7:8),['AOD_PROFILE_' date_ymd '.mat']));
AOD_GRID=G; %#ok<NASGU>
save(output_path,'AOD_GRID','-v7.3');
fprintf('AOD_GRID_PASS common_profiles=%d occupied=%d\n',sum(G.profile_count,'all'),nnz(G.profile_count));
end
