function r=run_inspect_clean_continental_200701(run_root)
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(code_root,'test','ccn','ccnv2'),'-begin');
diary(fullfile(run_root,'logs','inspect_clean_continental_200701_matlab.log'));c=onCleanup(@()diary('off')); %#ok<NASGU>
r=inspect_clean_continental_200701(run_root);disp(r);
end
