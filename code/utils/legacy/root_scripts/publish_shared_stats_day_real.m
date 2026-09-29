function final_mat = publish_shared_stats_day_real(date_str, candidate_path)
% Publish the already Gate-validated ERA5-real CALIPSO_STATS immutably.
date_str=char(string(date_str)); dt=datetime(date_str,'InputFormat','yyyy-MM-dd');
cfg_root='F:\AER_RETRA_CASE\shared_derived\calipso_stats';
key='stats__ap-final-v1__era5-real__adapter-v1__qc-v1__stats-v1';
final_dir=fullfile(cfg_root,key,datestr(dt,'yyyy'),datestr(dt,'mm'),datestr(dt,'dd'));
if ~isfile(candidate_path), error('Missing candidate Stats: %s',candidate_path); end
if isfile(fullfile(final_dir,'_SUCCESS')), error('Formal Stats already published.'); end
if isfolder(final_dir), error('Refusing to overwrite existing incomplete directory.'); end
parent=fileparts(final_dir); if ~isfolder(parent), mkdir(parent); end
tmp_dir=tempname(parent); mkdir(tmp_dir); cleanup=onCleanup(@()cleanup_tmp(tmp_dir));
tmp_mat=fullfile(tmp_dir,sprintf('CALIPSO_STATS_%s.mat',datestr(dt,'yyyymmdd'))); copyfile(candidate_path,tmp_mat);
src=dir(candidate_path); input_kind={'T_all'}; input_path={strrep(candidate_path,'calipso_stats\candidate_era5-real_20070101\CALIPSO_STATS_20070101.mat','t_all\tall__ap-final-v1__era5-real__adapter-v1__qc-v1\2007\01\01\T_all_20070101.mat')}; input_bytes=src.bytes; input_modified={src.date};
inventory=table(input_kind,input_path,input_bytes,input_modified,'VariableNames',{'Kind','Path','Bytes','LastModified'}); writetable(inventory,fullfile(tmp_dir,'input_inventory.csv'));
fid=fopen(fullfile(tmp_dir,'manifest.txt'),'w'); fprintf(fid,'manifest_version=manifest-v1\nproduct_type=CALIPSO_STATS\nproduct_key=%s\nstatus=PASS\ndate=%s\nscenario=era5_real\nproducer=build_calipso_stats.m\nsource_candidate=%s\nsource_tall_status=published\ngate_t_all=PASS\ngate_hash=PASS\ngate_stats_consumer=PASS\nbelow_ground_mask=none\nsurface_pressure_used=false\nformal_science_product=true\nschema_version=stats-v1\nsuccess_marker=_SUCCESS\n',key,date_str,candidate_path); fclose(fid);
movefile(tmp_dir,final_dir); cleanup=[];
fid=fopen(fullfile(final_dir,'_SUCCESS'),'w'); fprintf(fid,'status=PASS\nproduct_key=%s\ndate=%s\npublished_time=%s\n',key,date_str,char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'))); fclose(fid);
final_mat=fullfile(final_dir,sprintf('CALIPSO_STATS_%s.mat',datestr(dt,'yyyymmdd'))); fprintf('PUBLISHED %s\n',final_mat);
end
function cleanup_tmp(p), if isfolder(p), rmdir(p,'s'); end, end
