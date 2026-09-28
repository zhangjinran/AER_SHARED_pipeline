function r=run_compare_clean_continental_day(run_root)
v2root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(v2root,'validation'),'-begin');
diary(fullfile(run_root,'logs','compare_clean_continental_day_matlab.log'));c=onCleanup(@()diary('off')); %#ok<NASGU>
r=compare_clean_continental_day_to_grid(run_root,'20070101');disp(r);
end
