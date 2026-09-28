function output_path = build_ccn_grid_from_shared_tall(tall_path, output_path, varargin)
%BUILD_CCN_GRID_FROM_SHARED_TALL CCN producer independent of CALIPSO_STATS.
% Uses only the frozen shared T_all contract plus existing CCN priors.
producer_dir=fileparts(mfilename('fullpath'));
code_root=fileparts(fileparts(producer_dir));
project=fileparts(code_root);
ip=inputParser; addParameter(ip,'PriorRoot','',@(x)ischar(x)||isstring(x));
parse(ip,varargin{:});
if ~isfile(tall_path), error('CCN:MissingTAll','Missing T_all: %s',tall_path); end
S=load_with_nas_retry(tall_path,'T_all'); T=S.T_all;
required={'Ext','Back','Depol','Type','Lon','Lat','RH'};
if ~all(ismember(required,T.Properties.VariableNames)), error('CCN:Schema','T_all missing CCN fields.'); end
addpath(fullfile(code_root,'functions'));
prior_dir=char(ip.Results.PriorRoot); if isempty(prior_dir), prior_dir=fullfile(project,'inputs','priors'); end
pfile=fullfile(prior_dir,'Parameter_Particle_CALISPO.mat'); if ~isfile(pfile), pfile=fullfile(prior_dir,'Parameter_Particle_CALISPO_candidate.mat'); end
efile=fullfile(prior_dir,'Extinction_Normalized.mat'); if ~isfile(efile), efile=fullfile(prior_dir,'Extinction_Normalized_candidate.mat'); end
P=load_with_nas_retry(pfile); P=P.data;
E=load_with_nas_retry(efile); E=E.Extinction_N;
good=isfinite(T.Ext)&T.Ext>0&T.Ext<=1.25&isfinite(T.Back)&T.Back>0&T.Back<=0.05&isfinite(T.Depol)&T.Depol>0.05&T.Depol<0.31&isfinite(T.RH)&T.RH>0&T.RH<100&isfinite(T.Type)&T.Type>=1&T.Type<=7;
T=T(good,:); total=height(T); [Nd_dry,Nd_wet]=Calc_Nd_OMCAM(T,P,struct('Extinction_N',E)); %#ok<ASGLU>
C=[Nd_dry,1.35*Nd_dry,1.70*Nd_dry]; li=floor((T.Lat+90)/5)+1; lj=floor((T.Lon+180)/5)+1; ok=li>=1&li<=36&lj>=1&lj<=72&isfinite(C(:,1));
sumC=zeros(36,72,3); cnt=zeros(36,72); for q=1:3, sumC(:,:,q)=accumarray([li(ok),lj(ok)],C(ok,q),[36,72],@sum,0); end; cnt=accumarray([li(ok),lj(ok)],1,[36,72],@sum,0);
M=nan(36,72,3); for q=1:3, z=sumC(:,:,q); z(cnt==0)=nan; z(cnt>0)=z(cnt>0)./cnt(cnt>0); M(:,:,q)=z; end
valid_total=sum(ok); meta=struct('grid_size_deg',5,'supersaturation_percent',[0.15 0.25 0.40],'source_tall',tall_path,'source_contract','shared-tall-v1','stats_dependency',false,'product_status','candidate');
outdir=fileparts(output_path); if ~isempty(outdir)&&~isfolder(outdir),mkdir(outdir);end
save(output_path,'M','cnt','total','valid_total','meta','-v7.3'); fprintf('CCN_GRID rows=%d valid=%d output=%s\n',total,valid_total,output_path);
end
