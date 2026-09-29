root='F:\AER_RETRA_CASE'; day=fullfile(root,'CCN_FULL_RERUN_20260821','day_20220601'); ds=dir(fullfile(day,'orbit_*','CALIPSO_results_2022_06_01_hdf.mat')); P=load(fullfile(root,'先验数据','Parameter_Particle_CALISPO.mat')); P=P.data; E=load(fullfile(root,'先验数据','Extinction_Normalized.mat')); E=E.Extinction_N;
fid=fopen(fullfile(day,'ccn_outliers.txt'),'w');
for k=1:numel(ds)
 A=load(fullfile(ds(k).folder,ds(k).name),'T_all'); T=A.T_all; good=isfinite(T.Ext)&T.Ext>0&isfinite(T.Back)&T.Back>0&isfinite(T.Depol)&T.Depol>0.05&T.Depol<0.31&isfinite(T.RH)&T.RH>0&T.RH<100&isfinite(T.Type)&T.Type>=1&T.Type<=7; T=T(good,:); [Nd,~]=Calc_Nd_OMCAM(T,P,struct('Extinction_N',E)); [mx,ix]=max(Nd); if mx>1e7, fprintf(fid,'orbit=%d Nd=%g Ext=%g Back=%g Depol=%g RH=%g Type=%d Height=%g Lon=%g Lat=%g\n',k,mx,T.Ext(ix),T.Back(ix),T.Depol(ix),T.RH(ix),T.Type(ix),T.Height(ix),T.Lon(ix),T.Lat(ix)); end; clear T Nd A;
end
fclose(fid);
