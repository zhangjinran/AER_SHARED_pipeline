function audit_tall_geolocation_20070101(run_root)
root='F:/AER_SHARED_PIPELINE';addpath(fullfile(root,'code','functions'));addpath(fullfile(root,'code','root_scripts'));
cd(root);
if ~isfolder(run_root),mkdir(run_root);end
X=reshape(1:30,10,3);assert(isequal(calipso_profile_center(X,10),X(:,2)));assert(isequal(calipso_profile_center(X',10),X(:,2)));
rawpath='Z:/CALIPSO_MAT_FINAL/CHAPTER5_AP/05kmAP/2007/2007_01_01.mat';
fprintf('AUDIT_LOAD_RAW\n');S=load_with_nas_retry(rawpath,'day');files=S.day.files;
[~,order]=sort(cellfun(@(x)char(x.filename),files,'UniformOutput',false));A=files{order(1)};clear S files;
raw=read_calipso_apro_core(A,'mat');E=double(raw.Ext_raw);B=double(raw.Back_raw);D=double(raw.Depol_raw);V=uint16(raw.AVD_raw(:,:,1));n=size(E,1);
typ=double(bitand(bitshift(V,-9),uint16(7)));typ(bitand(V,uint16(7))~=3)=0;
v=typ(:)>0&E(:)>0&B(:)>0&D(:)>=0&isfinite(E(:))&isfinite(B(:))&isfinite(D(:));
rep=@(x)reshape(repmat(x(:),1,399),[],1);bad=@(x)reshape(x(:),3,n)';
lon=rep(double(raw.Lon_raw(:,2)));lat=rep(double(raw.Lat_raw(:,2)));t=rep(double(raw.Time_raw(:,2))/86400+datenum(1993,1,1));
wl=bad(double(raw.Lon_raw));wa=bad(double(raw.Lat_raw));wt=bad(double(raw.Time_raw));
wl=rep(wl(:,2));wa=rep(wa(:,2));wt=rep(wt(:,2)/86400+datenum(1993,1,1));
fprintf('AUDIT_LOAD_PUBLISHED\n');S=load_with_nas_retry(fullfile(root,'products/tall/t_all/tall__ap-final-v1__era5-real__adapter-v1__qc-v1/2007/01/01/T_all_20070101.mat'),'T_all');
T=S.T_all(strcmp(string(S.T_all.FileName),string(raw.filename)),:);clear S;
assert(height(T)==nnz(v)&&isequal(T.Ext,E(v)),'AUDIT:Identity','Orbit rows or optical values do not align.');
fprintf('PUBLISHED_AUDIT rows=%d old_lon_equal=%d old_lat_equal=%d old_time_equal=%d correct_lon_equal=%d correct_lat_equal=%d\n',height(T),isequal(T.Lon,wl(v)),isequal(T.Lat,wa(v)),isequal(T.UTC,wt(v)),isequal(T.Lon,lon(v)),isequal(T.Lat,lat(v)));
fprintf('PUBLISHED_ERRORS lat_max_deg=%g lat_median_deg=%g lon_max_deg=%g time_max_seconds=%g\n',max(abs(T.Lat-lat(v))),median(abs(T.Lat-lat(v))),max(abs(T.Lon-lon(v))),max(abs(T.UTC-t(v)))*86400);
out=build_calipso_step1_day('2007-01-01','mat','MatRoot','Z:/CALIPSO_MAT_FINAL/CHAPTER5_AP/05kmAP','OutputDir',fullfile(run_root,'fixed_virtual_one_orbit'),'MaxFiles',1,'Scenario',struct('rh_mode','virtual_rh50','rh_value',50));
S=load_with_nas_retry(out,'T_all');F=S.T_all;
assert(isequal(F.Lon,lon(v))&&isequal(F.Lat,lat(v))&&isequal(F.UTC,t(v)),'AUDIT:Fix','Fixed geotime does not match native center.');
for name={'Ext','Back','Depol','Type','Height','DayNight','LR','FileName'}
    assert(isequaln(F.(name{1}),T.(name{1})),'AUDIT:Science','Unexpected change: %s',name{1});
end
fprintf('FIX_GATE_PASS rows=%d native_profile_center_exact=true optical_fields_unchanged=true RH_test_only=50\n',height(F));
end
