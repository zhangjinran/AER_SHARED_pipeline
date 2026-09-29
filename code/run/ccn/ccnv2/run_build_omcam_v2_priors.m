function result = run_build_omcam_v2_priors(run_root)
%RUN_BUILD_OMCAM_V2_PRIORS Sequentially build all five CCN v2 component priors.

if nargin<1||isempty(run_root),error('CCNv2:MissingRunRoot','Run root is required.');end
run_root=char(run_root); if ~isfolder(run_root),error('CCNv2:MissingRunRoot','Run root does not exist.');end
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
v2root=fullfile(code_root,'utils','ccn','ccnv2');
addpath(fullfile(v2root,'priors'),'-begin');

names={'marine','dust','polluted_continental','clean_continental','elevated_smoke'};
attempts={'marine_sphere_full_002','dust_spheroid_full_001','pc_sphere_full_001','cc_sphere_full_001','smoke_sphere_full_001'};
tables=cell(size(names));
for i=1:numel(names)
    if strcmp(names{i},'marine')
        base=fullfile(run_root,'staging','priors','marine_sphere',attempts{i},'candidates');
        candidate=fullfile(base,'Extinction_Normalized_v2.mat');
        if ~isfile(candidate),error('CCNv2:MissingMarine','Marine full candidate must be built first.');end
        S=load(candidate,'Extinction_N'); prior_table=S.Extinction_N.CM;
        tables{i}=fullfile(base,'marine_alpha_n.mat'); save(tables{i},'prior_table','-v7');
    else
        base=fullfile(run_root,'staging','priors','components',names{i},attempts{i},'candidates');
        tables{i}=fullfile(base,[names{i} '_alpha_n.mat']);
        if ~isfile(tables{i})
            stage=fullfile(run_root,'staging','priors','components',names{i},attempts{i});
            if isfolder(stage)
                % An interrupted attempt is resumed in place.  Existing valid RH
                % outputs are immutable inputs to the resume step and are not run again.
                resume_component_optical_prior_v2(names{i},'RunRoot',run_root,'AttemptId',attempts{i});
            else
                build_component_optical_prior_v2(names{i},'RunRoot',run_root,'AttemptId',attempts{i},'ExecuteMopsmap',true);
            end
        end
    end
end

assembled=fullfile(run_root,'staging','priors','assembled','omcam_v2_full_001','candidates','Extinction_Normalized_v2.mat');
if ~isfile(assembled)
    result=assemble_omcam_v2_prior_candidate('RunRoot',run_root,'AttemptId','omcam_v2_full_001', ...
        'MarineTable',tables{1},'DustTable',tables{2},'PCTable',tables{3}, ...
        'CCTable',tables{4},'SmokeTable',tables{5});
else
    result=struct('status','already_assembled','extinction_path',assembled);
end
end
