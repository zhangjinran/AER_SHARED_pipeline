function gate_ccnv2_layout_20070101()
%GATE_CCNV2_LAYOUT_20070101 Compare relocated CCN day producer to formal day.
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
project_root=fileparts(code_root);
cd(project_root);
v2root=fullfile(code_root,'utils','ccn','ccnv2');
addpath(fullfile(v2root,'config'),'-begin');
addpath(fullfile(v2root,'science_core'),'-begin');
addpath(fullfile(v2root,'producers'),'-begin');
addpath(fileparts(mfilename('fullpath')),'-begin');
test_ccn_v2_routing_gate();

key='ccnv2__tall-v2-geotime__era5-rh__omcam-v2__grid2x5-z60';
product_root=fullfile(project_root,'products','ccn','ccn_v2','ccn_grid_day',key);
formal=fullfile(product_root,'2007','01','01','CCN_GRID_V2_20070101.mat');
test_root=fullfile(product_root,'test',layout_gate_id('ccnv2'), ...
    '2007','01','01');
candidate=fullfile(test_root,'CCN_GRID_V2_20070101.mat');
tall=getenv('CODE_LAYOUT_GATE_TALL_CANDIDATE');
assert(~isempty(tall),'LayoutGate:MissingCandidateInput', ...
    'Current-run T_all candidate path is required.');
prior=fullfile(project_root,'inputs','priors','ccn_v2', ...
    'omcam_v2__acp-table4-unitgate-v1');
assert(isfile(formal)&&isfile(tall)&&isfolder(prior), ...
    'LayoutGate:MissingInput','Formal CCN, T_all or prior missing.');
if ~isfolder(test_root)
    mkdir(test_root);
    fprintf('LAYOUT_CCN_PRODUCER %s\n',which('build_ccn_grid_day_v2'));
    build_ccn_grid_day_v2(tall,prior,candidate);
else
    assert(isfile(candidate) && ~isfile(fullfile(test_root,'gate_report.txt')), ...
        'LayoutGate:ExistingTest','Unexpected pre-existing CCN test output.');
    fprintf('LAYOUT_CCN_RESUME_CURRENT_ATTEMPT %s\n',candidate);
end

fields={'sum_component','sum_total','sample_count','meta'};
A=load(candidate,fields{:});
B=load(formal,fields{:});
for i=1:numel(fields)
    field=fields{i};
    if strcmp(field,'meta')
        assert(strcmp(A.meta.source_tall,tall),'LayoutGate:Provenance', ...
            'CCN did not read this attempt T_all candidate.');
        a_meta=rmfield(A.meta,'source_tall');
        b_meta=rmfield(B.meta,'source_tall');
        assert(isequaln(a_meta,b_meta),'LayoutGate:Value', ...
            'CCN meta differs beyond the source T_all path.');
    else
        assert(isequaln(A.(field),B.(field)),'LayoutGate:Value', ...
            'CCN field %s differs.',field);
    end
    fprintf('LAYOUT_CCN_FIELD_PASS %s\n',field);
end
fid=fopen(fullfile(test_root,'gate_report.txt'),'w');
assert(fid>=0,'LayoutGate:Report','Cannot write Gate report.');
fprintf(fid,'status=PASS\ndate=2007-01-01\nformal=%s\ncandidate=%s\n',formal,candidate);
fprintf(fid,'method=isequaln_sum_component_sum_total_sample_count_meta\n');
fprintf(fid,'meta_source_tall=current_attempt_candidate_path\n');
fclose(fid);
fprintf('LAYOUT_GATE_CCNV2_PASS date=2007-01-01\n');
end
