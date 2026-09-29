function gate_chapter4_layout_compare_20070101()
%GATE_CHAPTER4_LAYOUT_COMPARE_20070101 Compare isolated single-day databases.
code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
project_root=fileparts(code_root);
old_root=fullfile(project_root,'runs','chapter4','run_20070101_Tallv2_001', ...
    'intermediate','chapter4');
test_root=fullfile(project_root,'products','chapter4','test', ...
    layout_gate_id('ch4'),'2007','01','01');
new_root=fullfile(test_root,'intermediate','chapter4');
names={'AERONET_CALIPSO_Matched_20070101_Tallv2.mat', ...
    'AERONET_CALIPSO_Column_Integrated_DB_20070101_Tallv2.mat'};
vars={'Matched_DB','Column_DB'};
for i=1:2
    old=fullfile(old_root,names{i});new=fullfile(new_root,names{i});
    assert(isfile(old)&&isfile(new),'LayoutGate:MissingDB', ...
        'Missing Chapter4 database %s.',names{i});
    A=load(old,vars{i});B=load(new,vars{i});
    assert(isequaln(A.(vars{i}),B.(vars{i})),'LayoutGate:DB', ...
        'Chapter4 database %s differs.',vars{i});
    fprintf('LAYOUT_CH4_DB_PASS %s\n',vars{i});
    clear A B
end
figs={'Figure_4_1.png','Figure_4_2.png','Figure_4_3_Panel_1.png', ...
    'Figure_4_3_Panel_2.png','Figure_4_4.png','Figure_4_5.png'};
for i=1:numel(figs)
    p=fullfile(test_root,'plots','chapter4',figs{i});
    item=dir(p);
    assert(~isempty(item)&&item.bytes>0,'LayoutGate:Figure', ...
        'Missing/empty Chapter4 figure %s.',figs{i});
end
fid=fopen(fullfile(test_root,'gate_report.txt'),'w');
assert(fid>=0,'LayoutGate:Report','Cannot write Gate report.');
fprintf(fid,'status=PASS\ndate=2007-01-01\nold=%s\nnew=%s\n',old_root,new_root);
fprintf(fid,'matched_db=isequaln\ncolumn_db=isequaln\nfigures_nonempty=%d\n',numel(figs));
fclose(fid);
fprintf('LAYOUT_GATE_CHAPTER4_PASS figures=%d\n',numel(figs));
end
