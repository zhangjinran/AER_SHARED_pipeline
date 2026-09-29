root='F:\AER_RETRA_CASE'; inroot=fullfile(root,'CCN_FULL_RERUN_20260821','day_20220601');
outmat=fullfile(inroot,'CCN_2022_06_01.mat'); outpng=fullfile(inroot,'CCN_2022_06_01_global.png');
ds=dir(fullfile(inroot,'orbit_*','CALIPSO_results_2022_06_01_hdf.mat'));
assert(numel(ds)==29,'Expected 29 orbit MAT files, found %d',numel(ds));
allT=cell(numel(ds),1);
for k=1:numel(ds), A=load(fullfile(ds(k).folder,ds(k).name),'T_all'); allT{k}=A.T_all; end
T=vertcat(allT{:});
good=isfinite(T.Ext)&T.Ext>0&isfinite(T.Back)&T.Back>0&isfinite(T.Depol)& ...
    isfinite(T.RH)&T.RH>0&T.RH<100&isfinite(T.Type)&T.Type>=1&T.Type<=7;
T=T(good,:);
P=load(fullfile(root,'先验数据','Parameter_Particle_CALISPO.mat')); P=P.data;
E=load(fullfile(root,'先验数据','Extinction_Normalized.mat')); E=E.Extinction_N;
R=load(fullfile(root,'result','AERONET_dVdlnr_R.mat')); Radius=R.AERONET_dVdlnr_R;
ExtNorm=zeros(6,size(E.CM,1)); ExtNorm(1,:)=E.CM(:,2)'; ExtNorm(2,:)=E.DU(:,2)';
ExtNorm(3,:)=E.PC(:,2)'; ExtNorm(4,:)=E.CC(:,2)'; ExtNorm(5,:)=E.PD(:,2)'; ExtNorm(6,:)=E.SM(:,2)';
[Nd_dry,Nd_wet]=Calc_Nd_OMCAM(T,P,struct('Extinction_N',E));
CCN15=Nd_dry; CCN25=1.35*Nd_dry; CCN40=1.70*Nd_dry;
T.Nd_dry=Nd_dry; T.Nd_wet=Nd_wet; T.CCN_15=CCN15; T.CCN_25=CCN25; T.CCN_40=CCN40;
save(outmat,'T','-v7.3');
lat_idx=floor((T.Lat+90)/5)+1; lon_idx=floor((T.Lon+180)/5)+1;
ok=lat_idx>=1&lat_idx<=36&lon_idx>=1&lon_idx<=72&isfinite(CCN15);
M=nan(36,72,3); for c=1:3, x=[CCN15,CCN25,CCN40]; M(:,:,c)=accumarray([lat_idx(ok),lon_idx(ok)],x(ok,c),[36,72],@mean,NaN); end
lon=-177.5:5:177.5; lat=-87.5:5:87.5; f=figure('Color','w','Position',[50 80 1500 430]); ss=[.15 .25 .40];
for c=1:3, subplot(1,3,c); imagesc(lon,lat,M(:,:,c)); set(gca,'YDir','normal'); axis tight equal; xlabel('Longitude'); ylabel('Latitude'); title(sprintf('CCN %.2f%% - 2022-06-01',ss(c))); colorbar; end
sgtitle('Global 5°x5° CCN distribution'); exportgraphics(f,outpng,'Resolution',180); close(f);
fprintf('rows=%d valid=%d Nd_dry=[%g,%g] CCN25=[%g,%g]\n',height(T),sum(ok),min(Nd_dry),max(Nd_dry),min(CCN25),max(CCN25));
