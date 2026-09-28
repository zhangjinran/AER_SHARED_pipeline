function dest = publish_ccn_grid_day_v2(candidate_path, tall_path, ymd)
%PUBLISH_CCN_GRID_DAY_V2 Atomically promote a validated candidate; never copy it.
this=fileparts(mfilename('fullpath'));v2root=fileparts(this);addpath(fullfile(v2root,'config'),'-begin');cfg=ccn_v2_config();
destdir=fullfile(cfg.day_product_root,cfg.product_key,ymd(1:4),ymd(5:6),ymd(7:8));
if isfolder(destdir),error('CCNv2:ProductExists','Refuse to overwrite %s',destdir);end
if ~isfile(candidate_path),error('CCNv2:MissingCandidate','Missing candidate.');end
mkdir(destdir);dest=fullfile(destdir,sprintf('CCN_GRID_V2_%s.mat',ymd));
[ok,msg]=movefile(candidate_path,dest);if ~ok,error('CCNv2:Move',msg);end
fid=fopen(fullfile(destdir,'input_inventory.csv'),'w');
fprintf(fid,'role,path\nt_all,%s\nprior,%s\n',tall_path,fullfile(cfg.prior_root,'omcam_v2__acp-table4-unitgate-v1'));fclose(fid);
fid=fopen(fullfile(destdir,'manifest.txt'),'w');
fprintf(fid,'product_key=%s\nproduct_name=%s\nstatus=FORMAL_IMMUTABLE\nclear_air_in_denominator=false\n',cfg.product_key,cfg.product_name);fclose(fid);
fclose(fopen(fullfile(destdir,'_SUCCESS'),'w'));
end
