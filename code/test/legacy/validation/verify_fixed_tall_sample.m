function verify_fixed_tall_sample(run_root)
code=fileparts(fileparts(mfilename('fullpath')));cd(fileparts(code));addpath(fullfile(code,'functions'));addpath(fullfile(code,'root_scripts'));test_geotime_fix();
fprintf('CANONICAL_BUILD_PATH %s\n',which('build_calipso_step1_day'));
assert(strcmpi(strrep(which('build_calipso_step1_day'),'\','/'),strrep(fullfile(code,'root_scripts','build_calipso_step1_day.m'),'\','/')),'GeoTime:Shadow','Noncanonical producer resolved.');
S=load_with_nas_retry('Z:/CALIPSO_MAT_FINAL/CHAPTER5_AP/05kmAP/2007/2007_01_01.mat','day');
[~,order]=sort(cellfun(@(x)char(x.filename),S.day.files,'UniformOutput',false));A=S.day.files{order(1)};clear S;
R=read_calipso_apro_core(A,'mat');n=size(R.Ext_raw,1);V=uint16(R.AVD_raw(:,:,1));
typ=double(bitand(bitshift(V,-9),uint16(7)));typ(bitand(V,uint16(7))~=3)=0;
e=double(R.Ext_raw(:));b=double(R.Back_raw(:));d=double(R.Depol_raw(:));
v=typ(:)>0&e>0&b>0&d>=0&isfinite(e)&isfinite(b)&isfinite(d);
expand=@(x)reshape(repmat(double(x(:)),1,399),[],1);
lon=expand(R.Lon_raw(:,2));lat=expand(R.Lat_raw(:,2));t=expand(double(R.Time_raw(:,2))/86400+datenum(1993,1,1));
p=build_calipso_step1_day('2007-01-01','mat','MatRoot','Z:/CALIPSO_MAT_FINAL/CHAPTER5_AP/05kmAP','OutputDir',fullfile(run_root,'fixed_virtual_canonical'),'MaxFiles',1,'Scenario',struct('rh_mode','virtual_rh50','rh_value',50));
S=load_with_nas_retry(p,'T_all');T=S.T_all;
fprintf('FIX_DIFF rows=%d lon=%g lat=%g time_sec=%g ext=%g\n',height(T),max(abs(T.Lon-lon(v))),max(abs(T.Lat-lat(v))),max(abs(T.UTC-t(v)))*86400,max(abs(T.Ext-e(v))));
assert(isequal(T.Lon,lon(v))&&isequal(T.Lat,lat(v))&&isequal(T.UTC,t(v)),'GeoTime:Mismatch','Native centers mismatch.');
assert(isequal(T.Ext,e(v))&&isequal(T.Back,b(v))&&isequal(T.Depol,d(v))&&isequal(T.Type,typ(v)),'GeoTime:Optical','Optical mismatch.');
fprintf('FIX_GATE_PASS rows=%d center_lon_lat_time_exact=true optical_fields_exact=true\n',height(T));
fid=fopen(fullfile(run_root,'sample_gate_PASS.txt'),'w');assert(fid>=0);fprintf(fid,'PASS rows=%d\nlon_lat_time_order_exact=true\noptical_fields_exact=true\ntime_epoch_convention_audit_pending=true\n',height(T));fclose(fid);
end
