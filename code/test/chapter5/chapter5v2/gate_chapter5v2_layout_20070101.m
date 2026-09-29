function gate_chapter5v2_layout_20070101()
%GATE_CHAPTER5V2_LAYOUT_20070101 Rebuild one daily stats candidate after move.
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
project_root=fileparts(code_root);
cd(project_root);
v2root=fullfile(code_root,'utils','chapter5','chapter5v2');
addpath(fullfile(v2root,'config'),'-begin');
addpath(fullfile(v2root,'science_core'),'-begin');
addpath(fullfile(v2root,'producers'),'-begin');
addpath(fullfile(code_root,'utils','shared','current'),'-begin');
addpath(fullfile(code_root,'utils','shared','common'),'-begin');

old_key=getenv('CHAPTER5_V2_STATS_PRODUCT_KEY');
cleanup=onCleanup(@()setenv('CHAPTER5_V2_STATS_PRODUCT_KEY',old_key)); %#ok<NASGU>
key='stats-ch5v2__tall-v2-geotime__era5-rh__omcam-v2__grid5deg__stats-v2';
setenv('CHAPTER5_V2_STATS_PRODUCT_KEY',key);
product_root=fullfile(project_root,'products','chapter5', ...
    'calipso_stats_chapter5_v2',key);
formal=fullfile(product_root,'2007','01','01', ...
    'CALIPSO_STATS_CH5_V2_20070101.mat');
test_root=fullfile(product_root,'test',layout_gate_id('ch5v2'), ...
    '2007','01','01');
candidate=fullfile(test_root,'CALIPSO_STATS_CH5_V2_20070101.mat');
tall=getenv('CODE_LAYOUT_GATE_TALL_CANDIDATE');
assert(~isempty(tall),'LayoutGate:MissingCandidateInput', ...
    'Current-run T_all candidate path is required.');
assert(isfile(formal)&&isfile(tall),'LayoutGate:MissingInput', ...
    'Formal Chapter5 stats or T_all missing.');
if ~isfolder(test_root)
    mkdir(test_root);
    fprintf('LAYOUT_CH5_PRODUCER %s\n',which('build_calipso_stats_ch5_v2_day'));
    build_calipso_stats_ch5_v2_day(tall,candidate);
else
    assert(isfile(candidate) && ~isfile(fullfile(test_root,'gate_report.txt')), ...
        'LayoutGate:ExistingTest','Unexpected pre-existing Chapter5 test output.');
    fprintf('LAYOUT_CH5_RESUME_CURRENT_ATTEMPT %s\n',candidate);
end

A=load(candidate,'CALIPSO_STATS_CH5_V2');
B=load(formal,'CALIPSO_STATS_CH5_V2');
X=A.CALIPSO_STATS_CH5_V2;Y=B.CALIPSO_STATS_CH5_V2;
assert(strcmp(X.meta.source_tall,tall),'LayoutGate:Provenance', ...
    'Chapter5 did not read this attempt T_all candidate.');
assert(isequaln(rmfield(X.meta,'source_tall'),rmfield(Y.meta,'source_tall')) && ...
    isequaln(X.grid,Y.grid),'LayoutGate:Stats', ...
    'Daily Chapter5 stats differ beyond the source T_all path.');
fid=fopen(fullfile(test_root,'gate_report.txt'),'w');
assert(fid>=0,'LayoutGate:Report','Cannot write Gate report.');
fprintf(fid,'status=PASS\ndate=2007-01-01\nformal=%s\ncandidate=%s\n',formal,candidate);
fprintf(fid,'valid_rows=%d\nmethod=isequaln_CALIPSO_STATS_CH5_V2\n', ...
    A.CALIPSO_STATS_CH5_V2.meta.valid_rows);
fprintf(fid,'meta_source_tall=current_attempt_candidate_path\n');
fclose(fid);
fprintf('LAYOUT_GATE_CHAPTER5V2_PASS valid_rows=%d\n', ...
    A.CALIPSO_STATS_CH5_V2.meta.valid_rows);
end
