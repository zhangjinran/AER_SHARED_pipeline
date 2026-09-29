function report=compare_clean_continental_day_to_grid(run_root,ymd)
%COMPARE_CLEAN_CONTINENTAL_DAY_TO_GRID Exact one-day Type-4 to component-4 closure check.
if nargin<2,ymd='20070101';end
root='F:\AER_SHARED_PIPELINE';code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
v2root=fullfile(code_root,'utils','ccn','ccnv2');
addpath(fullfile(v2root,'config'),'-begin');addpath(fullfile(v2root,'science_core'),'-begin');cfg=ccn_v2_config();
tall=fullfile(root,'products','tall','t_all','tall__ap-final-v1__era5-real__adapter-v1__qc-v1',ymd(1:4),ymd(5:6),ymd(7:8),sprintf('T_all_%s.mat',ymd));
prior=fullfile(root,'inputs','priors','ccn_v2','omcam_v2__acp-table4-unitgate-v1','Extinction_Normalized_v2.mat');
grid=fullfile(root,'products','ccn','ccn_v2','ccn_grid_day',cfg.product_key,ymd(1:4),ymd(5:6),ymd(7:8),sprintf('CCN_GRID_V2_%s.mat',ymd));
S=load(tall,'T_all');P=load(prior,'Extinction_N');o=compute_ccn_sample_contributions_v2(S.T_all,P.Extinction_N,cfg);
t4=double(S.T_all.Type)==4; raw_type4=nnz(t4); valid_type4=nnz(t4&o.valid); manual_ccn025=sum(o.ccn020_component_cm3(t4,4))*cfg.supersaturation_factor(2);clear S P o
G=load(grid,'sum_component');x=G.sum_component(:,:,:,4,2);grid_ccn025=sum(x(:));grid_nonzero_voxels=nnz(x);delta=abs(manual_ccn025-grid_ccn025);
report=table(string(ymd),raw_type4,valid_type4,manual_ccn025,grid_ccn025,delta,grid_nonzero_voxels,'VariableNames',{'date','raw_type4_rows','valid_type4_rows','manual_ccn025_sum','grid_ccn025_sum','absolute_difference','grid_nonzero_voxels'});
writetable(report,fullfile(run_root,'reports',sprintf('clean_continental_day_closure_%s.csv',ymd)));disp(report);
assert(delta<1e-6*max(1,manual_ccn025),'CCNv2:CleanClosure','Type-4 manual/grid closure failed.');
end
