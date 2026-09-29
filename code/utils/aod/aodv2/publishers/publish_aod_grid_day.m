function final_mat=publish_aod_grid_day(candidate_mat,tall_mat,date_ymd)
error('AOD:RetiredTAll','T_all AOD v1 publication disabled. Use publish_aod_apro_product.');
%PUBLISH_AOD_GRID_DAY Immutable daily publisher; refuses any existing target.
cfg=aod_config(); yyyy=date_ymd(1:4); mm=date_ymd(5:6); dd=date_ymd(7:8);
final_dir=fullfile(cfg.daily_root,yyyy,mm,dd);
if isfolder(final_dir),error('AOD:PublishNoOverwrite','Daily product target exists: %s',final_dir);end
if ~isfile(candidate_mat)||~isfile(tall_mat),error('AOD:PublishInput','Candidate or T_all input is missing.');end
Q=load(candidate_mat,'AOD_GRID'); X=Q.AOD_GRID;
if ~strcmp(X.meta.date,date_ymd)||~strcmp(X.meta.product_key,cfg.daily_key)
    error('AOD:PublishContract','Daily candidate metadata mismatch.');
end
parent=fileparts(final_dir); if ~isfolder(parent),mkdir(parent);end
tmp=tempname(parent); mkdir(tmp);
try
    name=sprintf('AOD_GRID_%s.mat',date_ymd); copyfile(candidate_mat,fullfile(tmp,name));
    info=dir(tall_mat); inventory=table("T_all",string(tall_mat),uint64(info.bytes),string(info.date), ...
        'VariableNames',{'role','path','bytes','modified'});
    writetable(inventory,fullfile(tmp,'input_inventory.csv'));
    fid=fopen(fullfile(tmp,'manifest.txt'),'w'); if fid<0,error('AOD:Manifest','Cannot write manifest.');end
    fprintf(fid,'manifest_version=manifest-v1\nproduct_type=AOD_GRID_DAY\nproduct_key=%s\nstatus=PASS\ndate=%s\ngrid=global_5x5deg\nchannels=Type1-Type7,Total\nmethods=direct_APro_Extinction;Chapter5_CCN_component_reconstruction\nsource=T_all\n',cfg.daily_key,date_ymd); fclose(fid);
    fid=fopen(fullfile(tmp,'_SUCCESS'),'w'); if fid<0,error('AOD:SuccessMarker','Cannot write success marker.');end
    fprintf(fid,'status=PASS\nproduct_key=%s\ndate=%s\n',cfg.daily_key,date_ymd); fclose(fid);
    [ok,msg]=movefile(tmp,final_dir); if ~ok,error('AOD:PublishMove','%s',msg);end
catch ME
    rethrow(ME);
end
final_mat=fullfile(final_dir,sprintf('AOD_GRID_%s.mat',date_ymd));
fprintf('AOD_DAY_PUBLISHED date=%s path=%s\n',date_ymd,final_mat);
end
