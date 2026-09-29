function process_one_orbit_CCN(mat_path,out_path)
root='F:\AER_RETRA_CASE'; A=load(mat_path,'T_all'); T=A.T_all; clear A;
good=isfinite(T.Ext)&T.Ext>0&T.Ext<=1.25&isfinite(T.Back)&T.Back>0&T.Back<=0.05&isfinite(T.Depol)&T.Depol>0.05&T.Depol<0.31&isfinite(T.RH)&T.RH>0&T.RH<100&isfinite(T.Type)&T.Type>=1&T.Type<=7; T=T(good,:);
P=load(fullfile(root,'先验数据','Parameter_Particle_CALISPO.mat')); P=P.data;
E=load(fullfile(root,'先验数据','Extinction_Normalized.mat')); E=E.Extinction_N;
[Nd,~]=Calc_Nd_OMCAM(T,P,struct('Extinction_N',E)); C=[Nd,1.35*Nd,1.70*Nd]; li=floor((T.Lat+90)/5)+1; lj=floor((T.Lon+180)/5)+1; ok=li>=1&li<=36&lj>=1&lj<=72&isfinite(C(:,1));
sumC=zeros(36,72,3); cnt=zeros(36,72); for q=1:3, sumC(:,:,q)=accumarray([li(ok),lj(ok)],C(ok,q),[36,72],@sum,0); end; cnt=accumarray([li(ok),lj(ok)],1,[36,72],@sum,0); valid=sum(ok); total=height(T); save(out_path,'sumC','cnt','valid','total','-v7.3');
