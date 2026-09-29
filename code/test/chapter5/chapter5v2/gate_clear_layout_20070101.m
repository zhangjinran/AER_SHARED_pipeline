function gate_clear_layout_20070101()
%GATE_CLEAR_LAYOUT_20070101 Check relocated clear-air producer, no publish.
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
project_root=fileparts(code_root);
cd(project_root);
addpath(fullfile(code_root,'utils','shared','current'),'-begin');
addpath(fullfile(code_root,'utils','chapter5','chapter5v2'),'-begin');

product_root=fullfile(project_root,'products','chapter5','clear_air_stats_v2', ...
    'clear__ap-final-v1__geotime-v2');
formal=fullfile(product_root,'2007','01','01','CLEAR_AIR_STATS_20070101.mat');
test_root=fullfile(product_root,'test',layout_gate_id('clearv2'), ...
    '2007','01','01');
candidate=fullfile(test_root,'CLEAR_AIR_STATS_20070101.mat');
raw='Z:/CALIPSO_MAT_FINAL/CHAPTER5_AP/05kmAP/2007/2007_01_01.mat';
assert(isfile(formal)&&isfile(raw),'LayoutGate:MissingInput', ...
    'Formal clear-air product or global APro missing.');
assert(~isfolder(test_root),'LayoutGate:ExistingTest', ...
    'Test directory already exists: %s',test_root);
mkdir(test_root);
fprintf('LAYOUT_CLEAR_TEST_ROOT %s\n',test_root);
fprintf('LAYOUT_CLEAR_PRODUCER %s\n',which('build_clear_air_stats_day'));
build_clear_air_stats_day('2007-01-01',raw,candidate);

A=load_with_nas_retry(candidate,'CLEAR_STATS','processed_files');
B=load_with_nas_retry(formal,'CLEAR_STATS','processed_files');
assert(isequaln(A.processed_files,B.processed_files), ...
    'LayoutGate:OrbitCount','Processed orbit counts differ.');
assert(isequaln(A.CLEAR_STATS,B.CLEAR_STATS), ...
    'LayoutGate:Stats','Clear-air structures differ.');
fid=fopen(fullfile(test_root,'gate_report.txt'),'w');
assert(fid>=0,'LayoutGate:Report','Cannot write Gate report.');
fprintf(fid,'status=PASS\ndate=2007-01-01\nformal=%s\ncandidate=%s\n', ...
    formal,candidate);
fprintf(fid,'processed_files=%d\nmethod=isequaln_CLEAR_STATS_and_processed_files\n', ...
    A.processed_files);
fclose(fid);
fprintf('LAYOUT_GATE_CLEARV2_PASS processed_files=%d\n',A.processed_files);
end
