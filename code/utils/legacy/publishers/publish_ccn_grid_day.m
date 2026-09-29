function final_mat=publish_ccn_grid_day(date_str,candidate_path)
date_str=char(string(date_str)); dt=datetime(date_str,'InputFormat','yyyy-MM-dd');
cfg=data_roots(); root=cfg.CCN_GRID_ROOT; key='ccn__ap-final-v1__era5-real__grid5deg__ccn-v1';
final_dir=fullfile(root,key,datestr(dt,'yyyy'),datestr(dt,'mm'),datestr(dt,'dd'));
if ~isfile(candidate_path), error('CCN:MissingCandidate'); end
if isfile(fullfile(final_dir,'_SUCCESS'))||isfolder(final_dir), error('CCN:ImmutableExists'); end
parent=fileparts(final_dir); if ~isfolder(parent),mkdir(parent);end; tmp=tempname(parent);mkdir(tmp); cleanup=onCleanup(@()clean(tmp));
name=sprintf('CCN_GRID_%s.mat',datestr(dt,'yyyymmdd')); copyfile(candidate_path,fullfile(tmp,name)); src=dir(candidate_path);
tall_path=fullfile(cfg.SHARED_TALL_ROOT,'tall__ap-final-v1__era5-real__adapter-v1__qc-v1',datestr(dt,'yyyy'),datestr(dt,'mm'),datestr(dt,'dd'),sprintf('T_all_%s.mat',datestr(dt,'yyyymmdd'))); td=dir(tall_path);
fid=fopen(fullfile(tmp,'input_inventory.csv'),'w'); fprintf(fid,'Kind,Path,Bytes,LastModified\nT_all,%s,%d,%s\n',tall_path,td.bytes,td.date); fclose(fid);
fid=fopen(fullfile(tmp,'manifest.txt'),'w'); fprintf(fid,'manifest_version=manifest-v1\nproduct_type=CCN_GRID\nproduct_key=%s\nstatus=PASS\ndate=%s\nproducer=build_ccn_grid_from_shared_tall.m\nsource_tall=%s\ngrid_size_deg=5\nsupersaturation_percent=0.15,0.25,0.40\nstats_dependency=false\nno_data_value=NaN\nformal_science_product=true\nsuccess_marker=_SUCCESS\n',key,date_str,tall_path); fclose(fid); movefile(tmp,final_dir); cleanup=[]; fid=fopen(fullfile(final_dir,'_SUCCESS'),'w'); fprintf(fid,'status=PASS\nproduct_key=%s\ndate=%s\n',key,date_str); fclose(fid); final_mat=fullfile(final_dir,name); fprintf('PUBLISHED %s\n',final_mat);
end
function clean(p),if isfolder(p),rmdir(p,'s');end,end
