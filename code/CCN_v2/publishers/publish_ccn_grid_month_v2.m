function dest=publish_ccn_grid_month_v2(candidate_path,yyyymm,expected_dates)
this=fileparts(mfilename('fullpath'));v2root=fileparts(this);addpath(fullfile(v2root,'config'),'-begin');cfg=ccn_v2_config();
destdir=fullfile(cfg.month_product_root,cfg.product_key,yyyymm(1:4),yyyymm(5:6));
if isfolder(destdir),error('CCNv2:ProductExists','Refuse overwrite.');end
mkdir(destdir);dest=fullfile(destdir,sprintf('CCN_GRID_V2_MONTH_%s.mat',yyyymm));
[ok,msg]=movefile(candidate_path,dest);if ~ok,error('CCNv2:Move',msg);end
fid=fopen(fullfile(destdir,'input_inventory.csv'),'w');fprintf(fid,'date\n');fprintf(fid,'%s\n',expected_dates{:});fclose(fid);
fid=fopen(fullfile(destdir,'manifest.txt'),'w');fprintf(fid,'product_key=%s\naggregation=pooled_sum_over_pooled_sample_count\nstatus=FORMAL_IMMUTABLE\n',cfg.product_key);fclose(fid);
fclose(fopen(fullfile(destdir,'_SUCCESS'),'w'));
end
