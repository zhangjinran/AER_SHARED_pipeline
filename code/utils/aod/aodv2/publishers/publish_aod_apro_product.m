function destination=publish_aod_apro_product(candidate,source_path,date_ymd,kind)
cfg=aod_apro_config();
if strcmp(kind,'profile'),root=cfg.profile_root;key=cfg.profile_key;name=['AOD_PROFILE_' date_ymd '.mat'];variable='AOD_PROFILE';
elseif strcmp(kind,'grid'),root=cfg.grid_root;key=cfg.grid_key;name=['AOD_GRID_' date_ymd '.mat'];variable='AOD_GRID';
else,error('AOD:ProductKind','Unknown product kind.');end
target=fullfile(root,date_ymd(1:4),date_ymd(5:6),date_ymd(7:8));
assert(~isfolder(target),'AOD:Overwrite','Formal destination already exists: %s',target);
S=load_aod_mat_retry(candidate,variable); M=S.(variable).meta;
assert(strcmp(M.product_key,key)&&strcmp(M.date,date_ymd),'AOD:Publish','Metadata mismatch.');
parent=fileparts(target); if ~isfolder(parent),mkdir(parent);end
stage=[target '_publishing']; assert(~isfolder(stage),'AOD:Publish','Prior incomplete publication needs inspection.');mkdir(stage);
info=dir(source_path); assert(~isempty(info),'AOD:Source','Publication input missing.');
T=table(string(source_path),uint64(info.bytes),'VariableNames',{'path','bytes'});
writetable(T,fullfile(stage,'input_inventory.csv'));
fid=fopen(fullfile(stage,'manifest.txt'),'w');assert(fid>=0,'AOD:Write','Cannot write manifest.');
fprintf(fid,'product_key=%s\ndate=%s\nsource=global_APro_MAT\nstatus=PASS\nqc_used=%d\nqc_policy=if_present_accept_0_1_16_18;otherwise_range_only\nnon_aerosol=zero\nunknown_or_no_signal=invalid_profile\navd=both_planes_half_bin\naveraging=%s\n',key,date_ymd,M.qc_used,cfg.averaging);fclose(fid);
[ok,msg]=movefile(candidate,fullfile(stage,name));assert(ok,'AOD:Move','%s',msg);
fid=fopen(fullfile(stage,'_SUCCESS'),'w');assert(fid>=0,'AOD:Write','Cannot write success marker.');
fprintf(fid,'status=PASS\nproduct_key=%s\n',key);fclose(fid);
[ok,msg]=movefile(stage,target);assert(ok,'AOD:Move','%s',msg);
destination=fullfile(target,name); fprintf('AOD_PUBLISHED kind=%s path=%s\n',kind,destination);
end
