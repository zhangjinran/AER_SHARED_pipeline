root='F:\AER_RETRA_CASE'; day=fullfile(root,'CCN_FULL_RERUN_20260821','day_20220601'); fid=fopen(fullfile(day,'value_diagnosis.txt'),'w');
ds=dir(fullfile(day,'orbit_*','CALIPSO_results_2022_06_01_hdf.mat')); P=load(fullfile(root,'先验数据','Parameter_Particle_CALISPO.mat')); P=P.data; E=load(fullfile(root,'先验数据','Extinction_Normalized.mat')); E=E.Extinction_N;
for k=[1 2 29]
 A=load(fullfile(ds(k).folder,ds(k).name),'T_all'); T=A.T_all; good=isfinite(T.Ext)&T.Ext>0&isfinite(T.Back)&T.Back>0&isfinite(T.Depol)&isfinite(T.RH)&T.RH>0&T.RH<100&isfinite(T.Type)&T.Type>=1&T.Type<=7; T=T(good,:); [Nd,~]=Calc_Nd_OMCAM(T,P,struct('Extinction_N',E));
 fprintf(fid,'orbit %d rows=%d Ext[min max mean]=[%g %g %g] Back=[%g %g %g] RH=[%g %g %g] Nd=[%g %g %g] p99=%g\n',k,height(T),min(T.Ext),max(T.Ext),mean(T.Ext),min(T.Back),max(T.Back),mean(T.Back),min(T.RH),max(T.RH),mean(T.RH),min(Nd),max(Nd),mean(Nd),prctile(Nd,99)); clear T Nd A;
end
G=load(fullfile(day,'CCN_2022_06_01_grid.mat')); x=G.M(:,:,2); x=x(isfinite(x)); fprintf(fid,'grid CCN25 n=%d min=%g max=%g mean=%g p50=%g p95=%g p99=%g\n',numel(x),min(x),max(x),mean(x),prctile(x,50),prctile(x,95),prctile(x,99)); fclose(fid);
