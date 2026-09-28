root='F:\AER_RETRA_CASE'; out=fullfile(root,'audit_CCN_processed_log.txt'); fid=fopen(out,'w');
S=load(fullfile(root,'processed_files_log_monthly.mat'));
fprintf(fid,'fields=%s\n',strjoin(fieldnames(S),','));
if isfield(S,'processed_list')
 fprintf(fid,'count=%d\n',numel(S.processed_list));
 for k=1:numel(S.processed_list), fprintf(fid,'%s\n',S.processed_list{k}); end
end
fclose(fid);
