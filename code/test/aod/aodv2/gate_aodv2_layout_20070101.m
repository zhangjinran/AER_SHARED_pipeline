function gate_aodv2_layout_20070101()
%GATE_AODV2_LAYOUT_20070101 Rebuild profile and grid in isolated test roots.
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
project_root=fileparts(code_root);
cd(project_root);
v2root=fullfile(code_root,'utils','aod','aodv2');
addpath(genpath(v2root));
addpath(fileparts(mfilename('fullpath')));
test_aod_apro_gate();
cfg=aod_apro_config();
date='20070101';
profile_formal=fullfile(cfg.profile_root,'2007','01','01',['AOD_PROFILE_' date '.mat']);
grid_formal=fullfile(cfg.grid_root,'2007','01','01',['AOD_GRID_' date '.mat']);
profile_test=fullfile(cfg.profile_root,'test',layout_gate_id('aodv2'), ...
    '2007','01','01');
grid_test=fullfile(cfg.grid_root,'test',layout_gate_id('aodv2'), ...
    '2007','01','01');
profile_candidate=fullfile(profile_test,['AOD_PROFILE_' date '.mat']);
grid_candidate=fullfile(grid_test,['AOD_GRID_' date '.mat']);
raw=fullfile(cfg.input_root,'2007','2007_01_01.mat');
assert(isfile(raw)&&isfile(profile_formal)&&isfile(grid_formal), ...
    'LayoutGate:MissingInput','APro or formal AOD products missing.');
assert(~isfolder(profile_test)&&~isfolder(grid_test), ...
    'LayoutGate:ExistingTest','AOD test directory already exists.');
mkdir(profile_test);mkdir(grid_test);
fprintf('LAYOUT_AOD_PROFILE_PRODUCER %s\n',which('build_aod_profile_day'));
build_aod_profile_day(raw,date,profile_candidate);
P=load(profile_candidate,'AOD_PROFILE');Q=load(profile_formal,'AOD_PROFILE');
assert(isequaln(P.AOD_PROFILE,Q.AOD_PROFILE),'LayoutGate:Profile', ...
    'Daily AOD profile product differs.');
fprintf('LAYOUT_AOD_PROFILE_PASS profiles=%d\n',P.AOD_PROFILE.meta.profile_count);
clear P Q

fprintf('LAYOUT_AOD_GRID_PRODUCER %s\n',which('build_aod_apro_grid_day'));
build_aod_apro_grid_day(profile_candidate,date,grid_candidate);
G=load(grid_candidate,'AOD_GRID');H=load(grid_formal,'AOD_GRID');
assert(isequaln(G.AOD_GRID,H.AOD_GRID),'LayoutGate:Grid', ...
    'Daily AOD grid product differs.');
fid=fopen(fullfile(grid_test,'gate_report.txt'),'w');
assert(fid>=0,'LayoutGate:Report','Cannot write Gate report.');
fprintf(fid,'status=PASS\ndate=2007-01-01\n');
fprintf(fid,'profile_formal=%s\nprofile_candidate=%s\n',profile_formal,profile_candidate);
fprintf(fid,'grid_formal=%s\ngrid_candidate=%s\n',grid_formal,grid_candidate);
fprintf(fid,'method=isequaln_AOD_PROFILE_and_AOD_GRID\n');
fclose(fid);
fprintf('LAYOUT_GATE_AODV2_PASS date=2007-01-01\n');
end
