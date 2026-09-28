function report = test_ccn_v2_sample_gate(prior_root, report_path)
%TEST_CCN_V2_SAMPLE_GATE Covers Types 1--7 and all mixed depol regimes.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'config'),'-begin'); addpath(fullfile(root,'science_core'),'-begin');
cfg=ccn_v2_config(); E=load(fullfile(prior_root,'Extinction_Normalized_v2.mat'),'Extinction_N');
T=table((1:7)',repmat(0.1,7,1),repmat(0.002,7,1),[0.10;0.10;0.10;0.10;0.04;0.10;0.32],repmat(50,7,1), ...
    'VariableNames',{'Type','Ext','Back','Depol','RH'});
o=compute_ccn_sample_contributions_v2(T,E.Extinction_N,cfg);
assert(all(o.valid)); assert(all(isfinite(o.ccn020_total_cm3)&o.ccn020_total_cm3>=0));
assert(o.mixed_beta_conserved); assert(o.ccn020_component_cm3(5,2)==0); assert(o.ccn020_component_cm3(7,1)==0);
report=table(T.Type,o.ccn020_total_cm3,o.valid,'VariableNames',{'type','ccn020_cm3','pass'});
if nargin>1&&~isempty(report_path),writetable(report,report_path);end
fprintf('CCN_V2_SAMPLE_GATE PASS types=1:7\n');
end
