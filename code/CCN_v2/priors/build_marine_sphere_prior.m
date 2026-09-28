function result = build_marine_sphere_prior(varargin)
%BUILD_MARINE_SPHERE_PRIOR Build candidate Marine sphere/Mie prior for CCN v2.
% This candidate-only function never writes inputs\priors\ccn_v2 directly.

p = inputParser;
p.addParameter('RunRoot','',@(x)ischar(x)||isstring(x));
p.addParameter('AttemptId','marine_sphere_attempt_001',@(x)ischar(x)||isstring(x));
p.addParameter('MopsmapRoot','F:\MOPSMAP\mopsmap',@(x)ischar(x)||isstring(x));
p.addParameter('CanonicalPriorRoot','F:\AER_SHARED_PIPELINE\inputs\priors',@(x)ischar(x)||isstring(x));
p.addParameter('WslDistro','Ubuntu',@(x)ischar(x)||isstring(x));
p.addParameter('RHValues',(0:99)',@(x)isnumeric(x)&&isvector(x));
p.addParameter('ExecuteMopsmap',false,@(x)islogical(x)&&isscalar(x));
p.parse(varargin{:}); opt=p.Results;

run_root=char(opt.RunRoot); attempt=char(opt.AttemptId);
if isempty(run_root)||~isfolder(run_root), error('CCNv2:MissingRunRoot','RunRoot must already exist.'); end
mopsmap_root=char(opt.MopsmapRoot); canonical_root=char(opt.CanonicalPriorRoot);
if ~isfolder(mopsmap_root)||~isfolder(canonical_root)
    error('CCNv2:MissingPriorSource','MOPSMAP or canonical prior root is unavailable.');
end

stage=fullfile(run_root,'staging','priors','marine_sphere',attempt);
if isfolder(stage), error('CCNv2:AttemptExists','Candidate attempt already exists: %s',stage); end
layout=make_layout(stage); make_dirs(layout);

this_dir=fileparts(mfilename('fullpath')); v2root=fileparts(this_dir);
addpath(fullfile(v2root,'config'),'-begin'); cfg=ccn_v2_config(); marine=cfg.parameters.marine;

write_text(fullfile(layout.metadata,'scientific_contract.txt'),sprintf([ ...
    'component=marine\nshape=sphere\nscattering=Mie\nwavelength_um=0.532\n', ...
    'kappa=%.4f\nrh_coordinate=0:99 percent\noutput_unit=Mm^-1\n'],marine.kappa));

radius=logspace(log10(0.05),log10(15),1000)';
fine=fullfile(layout.inputs,'marine_fine_dvdlnr.txt');
coarse=fullfile(layout.inputs,'marine_coarse_dvdlnr.txt');
write_lognormal(fine,radius,marine.volume_fraction(1),marine.mean_radius_um(1),marine.geometric_std(1));
write_lognormal(coarse,radius,marine.volume_fraction(2),marine.mean_radius_um(2),marine.geometric_std(2));

rh=unique(double(opt.RHValues(:))); rh=sort(rh);
if any(~isfinite(rh)|rh<0|rh>99|rh~=round(rh)), error('CCNv2:BadRH','RHValues must be integer 0:99.'); end
for i=1:numel(rh)
    write_input(fullfile(layout.inputs,sprintf('input_rh%02d.txt',rh(i))),fine,coarse,mopsmap_root,marine,rh(i));
end

if ~opt.ExecuteMopsmap
    write_text(fullfile(layout.validation,'status.txt'),sprintf('STATUS=PREPARED_ONLY\nMOPSMAP was not executed.\n'));
    result=struct('status','prepared_only','stage_root',stage,'candidate_dir',layout.candidates);
    return
end

check_wsl(char(opt.WslDistro));
extinction=run_mopsmap(layout,mopsmap_root,rh,char(opt.WslDistro));
writetable(table(rh,extinction,'VariableNames',{'RH_percent','extinction_per_Mm'}), ...
    fullfile(layout.outputs,'marine_sphere_extinction_rh.csv'));

% Build a v2 candidate by importing unchanged legacy components and replacing CM.
P=load(fullfile(canonical_root,'Parameter_Particle_CALISPO.mat'),'data');
E=load(fullfile(canonical_root,'Extinction_Normalized.mat'),'Extinction_N');
data=P.data;
data.v_i_fine(1)=marine.volume_fraction(1); data.v_i_coarse(1)=marine.volume_fraction(2);
data.r_mean_fine(1)=marine.mean_radius_um(1); data.r_mean_coarse(1)=marine.mean_radius_um(2);
data.GSD_fine(1)=marine.geometric_std(1); data.GSD_coarse(1)=marine.geometric_std(2);
data.m_r_fine(1)=marine.ri_real(1); data.m_r_coarse(1)=marine.ri_real(2);
data.m_i_fine(1)=marine.ri_imag(1); data.m_i_coarse(1)=marine.ri_imag(2);
Extinction_N=E.Extinction_N; Extinction_N.CM=[rh extinction]; %#ok<NASGU>
save(fullfile(layout.candidates,'Parameter_OMCAM_v2.mat'),'data','-v7');
save(fullfile(layout.candidates,'Extinction_Normalized_v2.mat'),'Extinction_N','-v7');
write_text(fullfile(layout.validation,'status.txt'),sprintf('STATUS=PASS\nMOPSMAP Marine sphere prior candidate generated.\n'));
result=struct('status','pass','stage_root',stage,'candidate_dir',layout.candidates, ...
    'parameter_path',fullfile(layout.candidates,'Parameter_OMCAM_v2.mat'), ...
    'extinction_path',fullfile(layout.candidates,'Extinction_Normalized_v2.mat'));
end

function layout=make_layout(stage)
layout.stage=stage; layout.inputs=fullfile(stage,'inputs'); layout.logs=fullfile(stage,'logs');
layout.outputs=fullfile(stage,'outputs'); layout.metadata=fullfile(stage,'metadata');
layout.validation=fullfile(stage,'validation'); layout.candidates=fullfile(stage,'candidates');
end
function make_dirs(layout)
f=fieldnames(layout); for i=1:numel(f), mkdir(layout.(f{i})); end
end
function write_lognormal(path,r,v,mu,gsd)
y=v./(sqrt(2*pi)*log(gsd)).*exp(-0.5*((log(r)-log(mu))./log(gsd)).^2);
writematrix([r y],path,'Delimiter','space');
end
function write_input(path,fine,coarse,root,m,rh)
fid=fopen(path,'w'); if fid<0,error('CCNv2:WriteFailed','Cannot write %s',path);end; c=onCleanup(@()fclose(fid)); %#ok<NASGU>
data=win_to_wsl(fullfile(root,'data')); scat=win_to_wsl(fullfile(root,'optical_dataset'));
fprintf(fid,"mode 1 size distr_file dvdlnr '%s'\n",win_to_wsl(fine));
fprintf(fid,"mode 2 size distr_file dvdlnr '%s'\n",win_to_wsl(coarse));
fprintf(fid,'mode 1 refrac %.7f %.7f\n',m.ri_real(1),m.ri_imag(1));
fprintf(fid,'mode 1 kappa %.7f\n',m.kappa); fprintf(fid,'mode 1 shape sphere\n');
fprintf(fid,'mode 2 refrac %.7f %.7f\n',m.ri_real(2),m.ri_imag(2));
fprintf(fid,'mode 2 kappa %.7f\n',m.kappa); fprintf(fid,'mode 2 shape sphere\n');
fprintf(fid,'wavelength 0.532\nrH %d\nsize_equ vol\n',rh);
fprintf(fid,"scatlib '%s'\nwater_refrac_file '%s'\noutput lidar\noutput ascii_file 'marine_sphere_rh%02d'\n",scat,[data '/refr_water_segelstein'],rh);
end
function check_wsl(distro)
[s,msg]=system(sprintf('wsl.exe -d %s -u root -- /bin/true',distro));
if s~=0,error('CCNv2:WSLUnavailable','WSL preflight failed: %s',msg);end
end
function extinction=run_mopsmap(layout,root,rh,distro)
exe=win_to_wsl(fullfile(root,'mopsmap')); stage=win_to_wsl(layout.stage); extinction=nan(numel(rh),1);
for i=1:numel(rh)
    in=sprintf('inputs/input_rh%02d.txt',rh(i)); log=sprintf('logs/mopsmap_rh%02d.log',rh(i));
    cmd=sprintf('wsl.exe -d %s -u root -- bash -lc "cd ''%s'' && ''%s'' ''%s'' > ''%s'' 2>&1"',distro,stage,exe,in,log);
    [s,msg]=system(cmd); if s~=0,error('CCNv2:MopsmapFailed','RH=%d: %s',rh(i),msg);end
    lidar=fullfile(layout.stage,sprintf('marine_sphere_rh%02d.lidar',rh(i)));
    x=readmatrix(lidar,'FileType','text'); x=x(isfinite(x));
    if numel(x)<2,error('CCNv2:MopsmapOutput','No extinction value at RH=%d.',rh(i));end
    extinction(i)=x(2);
end
end
function p=win_to_wsl(p)
p=char(p); if numel(p)<3||p(2)~=':',error('CCNv2:Path','Expected Windows path.');end
p=['/mnt/' lower(p(1)) strrep(p(3:end),'\','/')];
end
function write_text(path,txt)
fid=fopen(path,'w'); if fid<0,error('CCNv2:WriteFailed','Cannot write %s',path);end; c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',txt);
end
