function run_postarchive_day_gates_20070101(stage)
% One-day, isolated post-archive regression. Does not publish products.
if nargin<1, stage='all'; end
assert(any(strcmp(stage,{'tall','downstream','resume_ccn','resume_ch5'})), ...
    'LayoutGate:Stage','Use tall, downstream, resume_ccn or resume_ch5 stage.');
restoredefaultpath;
code_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
project_root = fileparts(code_root);
cd(project_root);
addpath(fullfile(code_root,'utils','shared','current'),'-begin');
addpath(fullfile(code_root,'utils','shared','config'),'-begin');
addpath(fullfile(code_root,'utils','shared','common'),'-begin');
addpath(fullfile(code_root,'test','tall','tallv2'),'-begin');
addpath(fullfile(code_root,'test','chapter5','chapter5v2'),'-begin');
addpath(fullfile(code_root,'test','ccn','ccnv2'),'-begin');
addpath(fullfile(code_root,'test','aod','aodv2'),'-begin');
addpath(fullfile(code_root,'test','chapter4','current'),'-begin');
addpath(fullfile(code_root,'test','shared'),'-begin');
addpath(fullfile(code_root,'utils','tall','tallv2'),'-begin');
assert_current_path(code_root);
assert_resolves('load_with_nas_retry',fullfile(code_root,'utils','shared','current'));
assert_resolves('load',fullfile(code_root,'utils','shared','current'));
assert_resolves('build_calipso_step1_day',fullfile(code_root,'utils','tall','tallv2'));

if strcmp(stage,'tall')
    gate_tallv2_layout_20070101();
    fprintf('POSTARCHIVE_TALL_GATE_20070101_PASS\n');
    return
end
project_root = fileparts(code_root);
tall_candidate=fullfile(project_root,'products','tall','t_all_v2', ...
    'tall__ap-final-v1__era5-real__geotime-v2__qc-v1','test', ...
    layout_gate_id('tallv2'),'2007','01','01','candidate_era5_real', ...
    '20070101','CALIPSO_results_2007_01_01_mat.mat');
assert(isfile(tall_candidate),'LayoutGate:MissingCandidateInput', ...
    'Current attempt T_all candidate is missing.');
setenv('CODE_LAYOUT_GATE_TALL_CANDIDATE',tall_candidate);
assert_current_path(code_root);
if strcmp(stage,'downstream')
    gate_clear_layout_20070101();
else
    clear_report=fullfile(project_root,'products','chapter5', ...
        'clear_air_stats_v2','clear__ap-final-v1__geotime-v2','test', ...
        layout_gate_id('clearv2'),'2007','01','01','gate_report.txt');
    assert(isfile(clear_report),'LayoutGate:MissingClearGate', ...
        'Current attempt clear-air Gate report is missing.');
end
assert_current_path(code_root);
if strcmp(stage,'resume_ch5')
    ccn_report=fullfile(project_root,'products','ccn','ccn_v2', ...
        'ccn_grid_day','ccnv2__tall-v2-geotime__era5-rh__omcam-v2__grid2x5-z60', ...
        'test',layout_gate_id('ccnv2'),'2007','01','01','gate_report.txt');
    assert(isfile(ccn_report),'LayoutGate:MissingCCNGate', ...
        'Current attempt CCN Gate report is missing.');
else
    gate_ccnv2_layout_20070101();
end
assert_current_path(code_root);
gate_chapter5v2_layout_20070101();
assert_current_path(code_root);
gate_aodv2_layout_20070101();
assert_current_path(code_root);

setenv('CHAPTER4_RUN_ID',['run_' layout_gate_id('ch4')]);
setenv('CHAPTER4_YEAR','2007');
setenv('CHAPTER4_MONTH','1');
setenv('CHAPTER4_FILE_TAG','20070101_Tallv2');
setenv('CHAPTER4_TALL_DATES','20070101');
setenv('CHAPTER4_TALL_ROOT',fullfile(project_root,'products','tall','t_all_v2', ...
    'tall__ap-final-v1__era5-real__geotime-v2__qc-v1','test', ...
    layout_gate_id('tallv2'),'chapter4_input'));
setenv('CHAPTER4_TEST_PRODUCT_ROOT',fullfile(project_root,'products','chapter4', ...
    'test',layout_gate_id('ch4'),'2007','01','01'));
run(fullfile(code_root,'run','chapter4','current','run_chapter4_month.m'));
% The retained Chapter 4 plotting scripts clear their caller workspace.
code_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
assert_current_path(code_root);
gate_chapter4_layout_compare_20070101();
fprintf('POSTARCHIVE_DAY_GATES_20070101_PASS\n');
end

function assert_current_path(code_root)
entries = strsplit(strrep(path,'\','/'),pathsep);
code = lower(strrep(code_root,'\','/'));
for k=1:numel(entries)
    entry=lower(entries{k});
    if startsWith(entry,[code '/'])
        relative=extractAfter(entry,numel(code)+1);
        assert(startsWith(relative,'run/') || startsWith(relative,'utils/') || ...
            startsWith(relative,'test/'),'LayoutGate:OldCodePath', ...
            'Old code directory on MATLAB path: %s',entries{k});
        assert(~contains(relative,'/legacy/'),'LayoutGate:LegacyPath', ...
            'Archived code on MATLAB path: %s',entries{k});
    end
end
fprintf('POSTARCHIVE_PATH_PASS no_legacy_or_old_top_level\n');
end

function assert_resolves(name,folder)
actual=which(name);
assert(startsWith(lower(strrep(actual,'\','/')), ...
    lower([strrep(folder,'\','/') '/'])),'LayoutGate:Shadow', ...
    '%s resolved to %s instead of %s',name,actual,folder);
fprintf('POSTARCHIVE_WHICH_PASS %s %s\n',name,actual);
end
