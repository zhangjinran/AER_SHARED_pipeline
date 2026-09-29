root='F:\AER_RETRA_CASE'; inroot=fullfile(root,'CCN_FULL_RERUN_20260821','day_20220601');
ds=dir(fullfile(inroot,'orbit_*','CALIPSO_results_2022_06_01_hdf.mat')); assert(numel(ds)==29);
P=load(fullfile(root,'先验数据','Parameter_Particle_CALISPO.mat')); P=P.data;
E=load(fullfile(root,'先验数据','Extinction_Normalized.mat')); E=E.Extinction_N;
sumC=zeros(36,72,3); cnt=zeros(36,72); total=0; valid_total=0;
for k=1:numel(ds)
    A=load(fullfile(ds(k).folder,ds(k).name),'T_all'); T=A.T_all; clear A;
    good=isfinite(T.Ext)&T.Ext>0&isfinite(T.Back)&T.Back>0&isfinite(T.Depol)&isfinite(T.RH)&T.RH>0&T.RH<100&isfinite(T.Type)&T.Type>=1&T.Type<=7;
    T=T(good,:); total=total+height(T); if isempty(T), clear T; continue; end
    [Nd_dry,~]=Calc_Nd_OMCAM(T,P,struct('Extinction_N',E));
    c=[Nd_dry,1.35*Nd_dry,1.70*Nd_dry];
    li=floor((T.Lat+90)/5)+1; lj=floor((T.Lon+180)/5)+1; ok=li>=1&li<=36&lj>=1&lj<=72&isfinite(c(:,1));
    for q=1:3, sumC(:,:,q)=sumC(:,:,q)+accumarray([li(ok),lj(ok)],c(ok,q),[36,72],@sum,0); end
    cnt=cnt+accumarray([li(ok),lj(ok)],1,[36,72],@sum,0); valid_total=valid_total+sum(ok);
    fprintf('orbit %d/%d rows=%d valid=%d\n',k,numel(ds),height(T),sum(ok)); clear T Nd_dry c li lj ok;
end
M=nan(36,72,3); for q=1:3, z=sumC(:,:,q); z(cnt>0)=z(cnt>0)./cnt(cnt>0); M(:,:,q)=z; end
outmat=fullfile(inroot,'CCN_2022_06_01_grid.mat'); save(outmat,'M','cnt','total','valid_total','-v7.3');
lon=-177.5:5:177.5; lat=-87.5:5:87.5; f=figure('Color','w','Position',[50 80 1500 430]); ss=[.15 .25 .40];
for q=1:3, subplot(1,3,q); imagesc(lon,lat,M(:,:,q)); set(gca,'YDir','normal'); axis tight equal; xlabel('Longitude'); ylabel('Latitude'); title(sprintf('CCN %.2f%% - 2022-06-01',ss(q))); colorbar; end
sgtitle('Global 5°x5° CCN distribution'); outpng=fullfile(inroot,'CCN_2022_06_01_global.png'); exportgraphics(f,outpng,'Resolution',180); close(f);
fprintf('total=%d valid=%d output=%s\n',total,valid_total,outpng);
