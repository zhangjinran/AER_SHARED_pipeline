function result = build_component_optical_prior_v2(component_name,varargin)
%BUILD_COMPONENT_OPTICAL_PRIOR_V2 Candidate MOPSMAP alpha_n(RH) table for one component.
% Results are isolated under a run staging directory; this function never publishes.

p=inputParser;
p.addRequired('component_name',@(x)ischar(x)||isstring(x));
p.addParameter('RunRoot','',@(x)ischar(x)||isstring(x));
p.addParameter('AttemptId','attempt_001',@(x)ischar(x)||isstring(x));
p.addParameter('MopsmapRoot','F:\MOPSMAP\mopsmap',@(x)ischar(x)||isstring(x));
p.addParameter('WslDistro','Ubuntu',@(x)ischar(x)||isstring(x));
p.addParameter('RHValues',(0:99)',@(x)isnumeric(x)&&isvector(x));
p.addParameter('ExecuteMopsmap',false,@(x)islogical(x)&&isscalar(x));
p.parse(component_name,varargin{:}); opt=p.Results;

name=char(string(opt.component_name)); run_root=char(opt.RunRoot); root=char(opt.MopsmapRoot);
if isempty(run_root)||~isfolder(run_root),error('CCNv2:MissingRunRoot','RunRoot must exist.');end
if ~isfolder(root),error('CCNv2:MissingMopsmap','Missing MOPSMAP root: %s',root);end
this_dir=fileparts(mfilename('fullpath')); v2root=fileparts(this_dir);
addpath(fullfile(v2root,'config'),'-begin'); cfg=ccn_v2_config();
if ~isfield(cfg.parameters,name),error('CCNv2:BadComponent','Unsupported component: %s',name);end
c=cfg.parameters.(name);

stage=fullfile(run_root,'staging','priors','components',name,char(opt.AttemptId));
if isfolder(stage),error('CCNv2:AttemptExists','Attempt exists: %s',stage);end
dirs={'inputs','logs','outputs','metadata','validation','candidates'};
for i=1:numel(dirs),mkdir(fullfile(stage,dirs{i}));end

r=logspace(log10(0.05),log10(cfg.radius_max_um),1000)';
fine=fullfile(stage,'inputs',[name '_fine_dvdlnr.txt']); coarse=fullfile(stage,'inputs',[name '_coarse_dvdlnr.txt']);
write_dist(fine,r,c.volume_fraction(1),c.mean_radius_um(1),c.geometric_std(1));
write_dist(coarse,r,c.volume_fraction(2),c.mean_radius_um(2),c.geometric_std(2));
rh=sort(unique(double(opt.RHValues(:))));
if any(~isfinite(rh)|rh<0|rh>99|rh~=round(rh)),error('CCNv2:BadRH','RH must be integer 0:99.');end
for i=1:numel(rh),write_input(fullfile(stage,'inputs',sprintf('input_rh%02d.txt',rh(i))),fine,coarse,root,c,rh(i),name);end
write_metadata(fullfile(stage,'metadata','component_contract.txt'),name,c,rh);

if ~opt.ExecuteMopsmap
    write_text(fullfile(stage,'validation','status.txt'),sprintf('STATUS=PREPARED_ONLY\n'));
    result=struct('status','prepared_only','stage_root',stage); return
end
check_wsl(char(opt.WslDistro)); ext=run_grid(stage,root,rh,char(opt.WslDistro),name);
prior_table=[rh ext]; save(fullfile(stage,'candidates',[name '_alpha_n.mat']),'prior_table','name','c','-v7');
writetable(table(rh,ext,'VariableNames',{'RH_percent','extinction_per_Mm'}),fullfile(stage,'outputs',[name '_alpha_n.csv']));
write_text(fullfile(stage,'validation','status.txt'),sprintf('STATUS=PASS\n'));
result=struct('status','pass','stage_root',stage,'prior_table_path',fullfile(stage,'candidates',[name '_alpha_n.mat']));
end

function write_dist(path,r,v,mu,g)
y=v./(sqrt(2*pi)*log(g)).*exp(-.5*((log(r)-log(mu))./log(g)).^2); writematrix([r y],path,'Delimiter','space');
end
function write_input(path,fine,coarse,root,c,rh,name)
fid=fopen(path,'w');
if fid<0
    error('CCNv2:Write','Cannot write input.');
end
cl=onCleanup(@()fclose(fid)); %#ok<NASGU>
data=to_wsl(fullfile(root,'data')); scat=to_wsl(fullfile(root,'optical_dataset'));
fprintf(fid,"mode 1 size distr_file dvdlnr '%s'\n",to_wsl(fine)); fprintf(fid,"mode 2 size distr_file dvdlnr '%s'\n",to_wsl(coarse));
for k=1:2
    fprintf(fid,'mode %d refrac %.7f %.7f\n',k,c.ri_real(k),c.ri_imag(k));
    fprintf(fid,'mode %d kappa %.7f\n',k,c.kappa);
    if strcmp(c.shape,'sphere')
        fprintf(fid,'mode %d shape sphere\n',k);
    else
        fprintf(fid,"mode %d shape spheroid distr_file '%s'\n",k,[data '/ar_dubovik']);
    end
end
fprintf(fid,'wavelength 0.532\nrH %d\nsize_equ vol\n',rh);
fprintf(fid,"scatlib '%s'\nwater_refrac_file '%s'\noutput lidar\noutput ascii_file '%s_rh%02d'\n",scat,[data '/refr_water_segelstein'],name,rh);
end
function ext=run_grid(stage,root,rh,distro,name)
exe=to_wsl(fullfile(root,'mopsmap')); sw=to_wsl(stage); ext=nan(numel(rh),1);
for i=1:numel(rh)
    cmd=sprintf('wsl.exe -d %s -u root -- bash -lc "cd ''%s'' && ''%s'' ''inputs/input_rh%02d.txt'' > ''logs/mopsmap_rh%02d.log'' 2>&1"',distro,sw,exe,rh(i),rh(i));
    [s,msg]=system(cmd);
    if s~=0, error('CCNv2:Mopsmap','%s',msg); end
    x=readmatrix(fullfile(stage,sprintf('%s_rh%02d.lidar',name,rh(i))),'FileType','text');
    x=x(isfinite(x));
    if numel(x)<2, error('CCNv2:BadMopsmapOutput','No extinction.'); end
    ext(i)=x(2);
end
end
function check_wsl(d)
[s,m]=system(sprintf('wsl.exe -d %s -u root -- /bin/true',d));
if s~=0
    error('CCNv2:WSL','%s',m);
end
end
function out=to_wsl(in)
in=char(in);
out=['/mnt/' lower(in(1)) strrep(in(3:end),'\','/')];
end

function write_metadata(path,name,c,rh)
write_text(path,sprintf('component=%s\nshape=%s\nkappa=%g\nrh_count=%d\n', ...
    name,c.shape,c.kappa,numel(rh)));
end

function write_text(path,text)
fid=fopen(path,'w');
if fid<0
    error('CCNv2:Write','Cannot write %s',path);
end
cl=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',text);
end
