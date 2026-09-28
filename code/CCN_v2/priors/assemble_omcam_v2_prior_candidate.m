function result = assemble_omcam_v2_prior_candidate(varargin)
%ASSEMBLE_OMCAM_V2_PRIOR_CANDIDATE Assemble validated component lookups in staging.

p=inputParser;
p.addParameter('RunRoot','',@(x)ischar(x)||isstring(x));
p.addParameter('AttemptId','assembled_001',@(x)ischar(x)||isstring(x));
p.addParameter('MarineTable','',@(x)ischar(x)||isstring(x));
p.addParameter('DustTable','',@(x)ischar(x)||isstring(x));
p.addParameter('PCTable','',@(x)ischar(x)||isstring(x));
p.addParameter('CCTable','',@(x)ischar(x)||isstring(x));
p.addParameter('SmokeTable','',@(x)ischar(x)||isstring(x));
p.addParameter('CanonicalPriorRoot','F:\AER_SHARED_PIPELINE\inputs\priors',@(x)ischar(x)||isstring(x));
p.parse(varargin{:}); o=p.Results;
run=char(o.RunRoot); if isempty(run)||~isfolder(run),error('CCNv2:MissingRunRoot','RunRoot must exist.');end
stage=fullfile(run,'staging','priors','assembled',char(o.AttemptId));
if isfolder(stage),error('CCNv2:AttemptExists','Attempt exists: %s',stage);end
mkdir(stage); mkdir(fullfile(stage,'candidates')); mkdir(fullfile(stage,'metadata')); mkdir(fullfile(stage,'validation'));

inputs={char(o.MarineTable),char(o.DustTable),char(o.PCTable),char(o.CCTable),char(o.SmokeTable)};
labels={'marine','dust','polluted_continental','clean_continental','elevated_smoke'};
fields={'CM','DU','PC','CC','SM'};
for i=1:numel(inputs)
    if ~isfile(inputs{i}),error('CCNv2:MissingComponentPrior','Missing %s prior: %s',labels{i},inputs{i});end
end

canonical=char(o.CanonicalPriorRoot);
P=load(fullfile(canonical,'Parameter_Particle_CALISPO.mat'),'data');
E=load(fullfile(canonical,'Extinction_Normalized.mat'),'Extinction_N');
this=fileparts(mfilename('fullpath')); v2root=fileparts(this); addpath(fullfile(v2root,'config'),'-begin'); cfg=ccn_v2_config();
idx=[1 2 3 4 6];
for i=1:numel(inputs)
    S=load(inputs{i},'prior_table'); T=double(S.prior_table);
    if ~isequal(size(T),[100 2])||~isequal(T(:,1),(0:99)')||any(~isfinite(T(:,2)))||any(T(:,2)<=0)
        error('CCNv2:BadComponentPrior','Invalid full RH lookup for %s.',labels{i});
    end
    E.Extinction_N.(fields{i})=T;
    c=cfg.parameters.(labels{i}); j=idx(i);
    P.data.v_i_fine(j)=c.volume_fraction(1); P.data.v_i_coarse(j)=c.volume_fraction(2);
    P.data.r_mean_fine(j)=c.mean_radius_um(1); P.data.r_mean_coarse(j)=c.mean_radius_um(2);
    P.data.GSD_fine(j)=c.geometric_std(1); P.data.GSD_coarse(j)=c.geometric_std(2);
    P.data.m_r_fine(j)=c.ri_real(1); P.data.m_r_coarse(j)=c.ri_real(2);
    P.data.m_i_fine(j)=c.ri_imag(1); P.data.m_i_coarse(j)=c.ri_imag(2);
end
data=P.data; Extinction_N=E.Extinction_N; %#ok<NASGU>
param_path=fullfile(stage,'candidates','Parameter_OMCAM_v2.mat'); ext_path=fullfile(stage,'candidates','Extinction_Normalized_v2.mat');
save(param_path,'data','-v7'); save(ext_path,'Extinction_N','-v7');

fid=fopen(fullfile(stage,'metadata','prior_manifest.txt'),'w');if fid<0,error('CCNv2:Write','Cannot write prior manifest.');end;c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'schema=omcam-v2\nshape_marine=sphere\nshape_dust=spheroid\nwavelength_um=0.532\nrh_grid=0:99\n');
for i=1:numel(inputs),fprintf(fid,'%s_source=%s\n',labels{i},inputs{i});end
fprintf(fid,'type5_parameter_row=legacy_retained_but_unused\n');
fprintf(fid,'status=CANDIDATE\n');
fid2=fopen(fullfile(stage,'validation','status.txt'),'w');fprintf(fid2,'STATUS=ASSEMBLED_CANDIDATE\n');fclose(fid2);
result=struct('stage_root',stage,'parameter_path',param_path,'extinction_path',ext_path);
end
