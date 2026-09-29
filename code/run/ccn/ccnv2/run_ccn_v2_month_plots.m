function outputs=run_ccn_v2_month_plots(run_root,yyyymm)
%RUN_CCN_V2_MONTH_PLOTS Plot a formal CCN_v2 monthly product.
if nargin<2||isempty(yyyymm),error('CCNv2:MonthLabel','Pass month as YYYYMM.');end
yyyymm=char(string(yyyymm));
if isempty(regexp(yyyymm,'^\d{6}$','once')),error('CCNv2:MonthLabel','yyyymm must use YYYYMM.');end
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
v2root=fullfile(code_root,'utils','ccn','ccnv2');addpath(fullfile(v2root,'consumers'),'-begin');
project_root=fileparts(code_root);
year=yyyymm(1:4);month=yyyymm(5:6);
logdir=fullfile(run_root,'logs','ccn_v2');if ~isfolder(logdir),mkdir(logdir);end
diary(fullfile(logdir,['monthly_plots_' yyyymm '_matlab.log']));c=onCleanup(@()diary('off')); %#ok<NASGU>
monthly=fullfile(project_root,'products','ccn','ccn_v2','ccn_grid_monthly', ...
    'ccnv2__tall-v1__era5-rh__omcam-v2__grid2x5-z60',year,month, ...
    ['CCN_GRID_V2_MONTH_' yyyymm '.mat']);
output_dir=fullfile(run_root,'plots','ccn_v2',yyyymm);
outputs=plot_ccn_v2_monthly_diagnostics(monthly,output_dir);disp(outputs);
fprintf('CCN_V2_MONTH_PLOTS_PASS month=%s time=%s\n',yyyymm,datestr(now,31));
end
