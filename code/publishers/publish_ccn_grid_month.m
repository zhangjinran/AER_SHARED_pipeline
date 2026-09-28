function final_mat=publish_ccn_grid_month(year_value,month_value,stage_mat)
%PUBLISH_CCN_GRID_MONTH Controlled in-place replacement for expanded coverage.
project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));key='ccn-monthly__ap-final-v1__era5-real__grid5deg__ccn-v1';
yyyy=sprintf('%04d',year_value);mm=sprintf('%02d',month_value);ym=sprintf('%04d%02d',year_value,month_value);final_dir=fullfile(project_root,'products','ccn','ccn_grid_monthly',key,yyyy,mm);
if isfolder(final_dir)&&~isfile(fullfile(final_dir,'_SUCCESS')),error('CCNMonth:IncompleteFinal','Refusing incomplete final directory.');end
S=load_with_nas_retry(stage_mat,'M','sum_month','cnt_month','meta');if ~isequal(size(S.M),[36 72 3])||~isequal(size(S.sum_month),[36 72 3])||~isequal(size(S.cnt_month),[36 72]),error('CCNMonth:Schema','Invalid staged CCN month.');end
parent=fileparts(final_dir);if ~isfolder(parent),mkdir(parent);end;tmp=tempname(parent);mkdir(tmp);guard=onCleanup(@()cleanup_tmp(tmp)); %#ok<NASGU>
final_mat=fullfile(tmp,['CCN_GRID_Monthly_' ym '.mat']);copyfile(stage_mat,final_mat);dates=datestr(datetime(string(compose('%08d',S.meta.processed_days(:))),'InputFormat','yyyyMMdd'),'yyyy-MM-dd');
writetable(table(string(dates),repmat("processed",numel(dates),1),'VariableNames',{'Date','Status'}),fullfile(tmp,'input_inventory.csv'));fid=fopen(fullfile(tmp,'manifest.txt'),'w');fprintf(fid,'product_type=CCN_GRID_MONTHLY\nproduct_key=%s\nstatus=PASS\nprocessed_days=%d\n',key,numel(dates));fclose(fid);
final_dir=controlled_publish_month_dir(tmp,final_dir,string(dates),'CCN_GRID_MONTHLY');guard=[];fid=fopen(fullfile(final_dir,'_SUCCESS'),'w');fprintf(fid,'status=PASS\nproduct_key=%s\nperiod=%s\n',key,ym);fclose(fid);final_mat=fullfile(final_dir,['CCN_GRID_Monthly_' ym '.mat']);
end
function cleanup_tmp(p),if isfolder(p),rmdir(p,'s');end,end
