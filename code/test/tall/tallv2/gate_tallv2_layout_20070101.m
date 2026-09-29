function gate_tallv2_layout_20070101()
%GATE_TALLV2_LAYOUT_20070101 Rebuild one day after path migration.
% Candidate stays under the product's test directory; no formal publish.
code_root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
project_root = fileparts(code_root);
cd(project_root);
addpath(fullfile(code_root,'utils','shared','current'),'-begin');
addpath(fullfile(code_root,'utils','shared','config'),'-begin');
addpath(fullfile(code_root,'utils','tall','tallv2'),'-begin');
addpath(fullfile(code_root,'test','tall','tallv2'),'-begin');

product_root = fullfile(project_root,'products','tall','t_all_v2', ...
    'tall__ap-final-v1__era5-real__geotime-v2__qc-v1');
formal = fullfile(product_root,'2007','01','01','T_all_20070101.mat');
test_root = fullfile(product_root,'test',layout_gate_id('tallv2'), ...
    '2007','01','01');
assert(isfile(formal),'LayoutGate:MissingFormal','Missing formal T_all.');
assert(~isfolder(test_root),'LayoutGate:ExistingTest', ...
    'Test directory already exists: %s',test_root);
mkdir(test_root);
fprintf('LAYOUT_GATE_TEST_ROOT %s\n',test_root);
fprintf('LAYOUT_GATE_BUILDER %s\n',which('build_calipso_step1_day'));
rebuild_tall_geotime_day('2007-01-01',test_root);
candidate = fullfile(test_root,'candidate_era5_real','20070101', ...
    'CALIPSO_results_2007_01_01_mat.mat');
assert(isfile(candidate),'LayoutGate:MissingCandidate','Missing candidate T_all.');

new_data = load_with_nas_retry(candidate,'T_all');
old_data = load_with_nas_retry(formal,'T_all');
A = new_data.T_all;
B = old_data.T_all;
assert(istable(A)&&istable(B),'LayoutGate:Schema','T_all is not a table.');
assert(height(A)==height(B),'LayoutGate:Rows', ...
    'Candidate rows %d, formal rows %d.',height(A),height(B));
names = A.Properties.VariableNames;
assert(isequal(names,B.Properties.VariableNames),'LayoutGate:Fields', ...
    'Column names or order differ.');
for k=1:numel(names)
    name=names{k};
    assert(isequaln(A.(name),B.(name)),'LayoutGate:Value', ...
        'Field %s differs.',name);
    fprintf('LAYOUT_GATE_FIELD_PASS %s\n',name);
end
assert(isequaln(A.Properties.UserData,B.Properties.UserData), ...
    'LayoutGate:Metadata','T_all UserData differs.');
fid=fopen(fullfile(test_root,'gate_report.txt'),'w');
assert(fid>=0,'LayoutGate:Report','Cannot write Gate report.');
fprintf(fid,'status=PASS\ndate=2007-01-01\nformal=%s\ncandidate=%s\n',formal,candidate);
fprintf(fid,'rows=%d\ncolumns=%d\nmethod=isequaln_each_table_field_and_UserData\n', ...
    height(A),numel(names));
fclose(fid);
fprintf('LAYOUT_GATE_TALLV2_PASS rows=%d columns=%d\n',height(A),numel(names));
end
