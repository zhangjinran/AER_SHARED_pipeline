function report = test_ccn_v2_unit_gate(candidate_prior_root, report_path)
%TEST_CCN_V2_UNIT_GATE Compare alpha-to-number factors to ACP Table 4.

if nargin<1||isempty(candidate_prior_root)
    error('CCNv2:MissingCandidatePrior','Candidate prior root is required.');
end
if nargin<2, report_path=''; end
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
root=fullfile(code_root,'utils','ccn','ccnv2');
addpath(fullfile(root,'config'),'-begin'); addpath(fullfile(root,'science_core'),'-begin');
cfg=ccn_v2_config();
P=load(fullfile(candidate_prior_root,'Parameter_OMCAM_v2.mat'),'data');
E=load(fullfile(candidate_prior_root,'Extinction_Normalized_v2.mat'),'Extinction_N');

names={'marine','dust','polluted_continental','clean_continental','elevated_smoke'};
fields={'CM','DU','PC','CC','SM'}; expected=[21.2077,11.0847,24.931,3.598,21.9948];
cutoff=[cfg.cutoff_um.nondust,cfg.cutoff_um.dust,cfg.cutoff_um.nondust,cfg.cutoff_um.nondust,cfg.cutoff_um.nondust];
param_index=[1 2 3 4 6];
got=nan(size(expected)); alpha_n=nan(size(expected)); integral=nan(size(expected));
for i=1:numel(names)
    c=cfg.parameters.(names{i});
    % Candidate MAT is separately checked to prevent config/MAT divergence.
    assert(abs(P.data.v_i_fine(param_index(i))-c.volume_fraction(1))<1e-12, ...
        'CCNv2:ParameterMismatch','Candidate parameter mismatch for %s.',names{i});
    prior_table=E.Extinction_N.(fields{i});
    alpha_n(i)=lookup_normalized_extinction(prior_table,0);
    integral(i)=integrate_number_per_unit_volume(c,cutoff(i),cfg.radius_max_um);
    % alpha_n: Mm^-1, CALIPSO alpha: km^-1, Vt conversion: 1e9.
    got(i)=1e9*integral(i)/alpha_n(i)/1000;
end
relative_error=abs(got-expected)./expected;
pass=relative_error<=0.05;
report=table(string(names(:)),expected(:),alpha_n(:),integral(:),got(:),relative_error(:),pass(:), ...
    'VariableNames',{'component','expected_Mm_cm3','alpha_n_RH0_MmInv','integral_per_volume','got_Mm_cm3','relative_error','pass'});
if ~isempty(report_path), writetable(report,report_path); end
assert(all(pass),'CCNv2:UnitGateFailed','Unit Gate failed; inspect report.');
fprintf('CCN_V2_UNIT_GATE PASS max_relative_error=%.6g\n',max(relative_error));
end
