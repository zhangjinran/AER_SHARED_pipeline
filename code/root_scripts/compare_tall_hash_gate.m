% Compare virtual and era5_real T_all without isequaln on whole tables.
root = 'F:\AER_RETRA_CASE\shared_derived\t_all';
vp = fullfile(root,'tall__ap-final-v1__virtual-rh50__adapter-v1__qc-v1','2007','01','01','T_all_20070101.mat');
rp = fullfile(root,'tall__ap-final-v1__era5-real__adapter-v1__qc-v1','_staging','2007','01','01','CALIPSO_results_2007_01_01_mat.mat');
V=load(vp,'T_all'); R=load(rp,'T_all'); v=V.T_all; r=R.T_all;
fid=fopen(fullfile(root,'hash_gate_20070101.txt'),'w'); c=onCleanup(@()fclose(fid));
fprintf(fid,'rows_virtual=%d\nrows_real=%d\nwidth_virtual=%d\nwidth_real=%d\n',height(v),height(r),width(v),width(r));
finite=isfinite(r.RH); fprintf(fid,'rh_finite=%d\nrh_nan=%d\nrh_min=%.15g\nrh_max=%.15g\n',nnz(finite),nnz(isnan(r.RH)),min(r.RH(finite)),max(r.RH(finite)));
fields={'Ext','Back','Depol','Type','Lon','Lat','UTC','Height','DayNight','LR'}; allok=height(v)==height(r);
for i=1:numel(fields)
  f=fields{i}; hv=sha256(getByteStreamFromArray(v.(f))); hr=sha256(getByteStreamFromArray(r.(f))); eq=strcmp(hv,hr); allok=allok&&eq;
  fprintf(fid,'field_%s_identical=%d\nfield_%s_virtual_sha256=%s\nfield_%s_real_sha256=%s\n',f,eq,f,hv,f,hr);
end
fprintf(fid,'non_rh_fields_identical=%d\n',allok); fclose(fid); clear c;
type(fullfile(root,'hash_gate_20070101.txt'));

function h=sha256(bytes)
  md=java.security.MessageDigest.getInstance('SHA-256'); md.update(uint8(bytes)); b=typecast(md.digest(),'uint8'); h=lower(reshape(dec2hex(b,2).',1,[]));
end
