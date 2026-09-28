root = 'F:\AER_RETRA_CASE';
report = fullfile(root,'audit_CCN_data_stage1.txt');
fid = fopen(report,'w');
fprintf(fid,'CCN data audit stage 1\n');
fprintf(fid,'time=%s\n',datestr(now));
fprintf(fid,'[FILES]\n');
names = {'CALIPSO_STATS_Monthly.mat','CALIPSO_results_Batch_1.csv', ...
    'CALIPSO_results_Batch_2.csv','CALIPSO_results_Batch_3.csv', ...
    'CALIPSO_results_Batch_4.csv','CALIPSO_results_Batch_5.csv'};
for k=1:numel(names)
    p=fullfile(root,names{k}); d=dir(p);
    fprintf(fid,'%s exists=%d bytes=%g\n',names{k},~isempty(d),sum([d.bytes]));
end

fprintf(fid,'[MAT_TOP_LEVEL]\n');
% The 1.4 GB v7.3 MAT is audited separately with a bounded reader.
fprintf(fid,'MAT inspection deferred: v7.3 file is large and must not be fully loaded in this stage.\n');

fprintf(fid,'[CSV_HEADERS_AND_SAMPLE]\n');
for k=1:5
    p=fullfile(root,sprintf('CALIPSO_results_Batch_%d.csv',k));
    fidc=fopen(p,'r'); h=fgetl(fidc); s=fgetl(fidc); fclose(fidc);
    fprintf(fid,'%s\n%s\n',h,s);
end
fclose(fid);
