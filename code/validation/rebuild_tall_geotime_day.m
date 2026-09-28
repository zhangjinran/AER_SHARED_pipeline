function rebuild_tall_geotime_day(date_str,run_root)
% Corrected real-RH day candidate only; never overwrite a published product.
code=fileparts(fileparts(mfilename('fullpath')));
cd(fileparts(code));
addpath(fullfile(code,'functions'));addpath(fullfile(code,'config'));addpath(fullfile(code,'root_scripts'));
test_geotime_fix();cfg=data_roots();d=datetime(date_str,'InputFormat','yyyy-MM-dd');
assert(strcmpi(strrep(which('build_calipso_step1_day'),'\','/'),strrep(fullfile(code,'root_scripts','build_calipso_step1_day.m'),'\','/')),'GeoTime:Shadow','Noncanonical producer resolved.');
out=fullfile(run_root,'candidate_era5_real',char(string(d,'yyyyMMdd')));
assert(~isfolder(out),'GeoTime:Overwrite','Candidate directory already exists; inspect before rebuilding.');
era=fullfile(cfg.ERA5_MAT_ROOT,char(string(d,'yyyy')),char(string(d,'MM')),char(string(d,'dd')));
p=build_calipso_step1_day(date_str,'mat','MatRoot',cfg.CALIPSO_AP_ROOT,'ERA5Dir',era,'OutputDir',out,'Scenario',scenario_era5_real());
S=load_with_nas_retry(p,'T_all');T=S.T_all;
assert(strcmp(T.Properties.UserData.geolocation_contract,'native-profile-center-v2'),'GeoTime:Contract','Missing corrected contract.');
assert(all(isfinite(T.Lon)&abs(T.Lon)<=180&isfinite(T.Lat)&abs(T.Lat)<=90),'GeoTime:Coordinates','Bad coordinates.');
assert(any(isfinite(T.RH)),'GeoTime:RH','No real RH values.');
fid=fopen(fullfile(out,'candidate_gate.txt'),'w');assert(fid>=0);
fprintf(fid,'status=CANDIDATE_BUILT\nrows=%d\nRH_finite=%d\nRH_NaN=%d\ngeolocation=native-profile-center-v2\npublication=NOT_PUBLISHED\ntime_epoch_leapsecond_audit=PENDING\n',height(T),nnz(isfinite(T.RH)),nnz(isnan(T.RH)));fclose(fid);
fprintf('GEOTIME_REAL_DAY_CANDIDATE_COMPLETE rows=%d RH_finite=%d RH_NaN=%d path=%s\n',height(T),nnz(isfinite(T.RH)),nnz(isnan(T.RH)),p);
end
