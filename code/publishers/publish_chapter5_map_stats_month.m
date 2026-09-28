function final_mat=publish_chapter5_map_stats_month(year_value,month_value,stage_mat)
%PUBLISH_CHAPTER5_MAP_STATS_MONTH Publish compact immutable monthly statistics.
    project_root=fileparts(fileparts(fileparts(mfilename('fullpath')))); key='ch5map__era5-real__grid5deg__n50-v1';
    yyyy=sprintf('%04d',year_value); mm=sprintf('%02d',month_value); ym=sprintf('%04d%02d',year_value,month_value);
    final_dir=fullfile(project_root,'products','chapter5','chapter5_map_stats',key,'monthly',yyyy,mm);
    if isfolder(final_dir)&&~isfile(fullfile(final_dir,'_SUCCESS')),error('Ch5Map:IncompleteFinal','Refusing existing incomplete final directory.');end
    S=load_with_nas_retry(stage_mat,'CHAPTER5_MAP_STATS'); if ~isfield(S,'CHAPTER5_MAP_STATS'),error('Ch5Map:Schema','Missing CHAPTER5_MAP_STATS.');end
    parent=fileparts(final_dir);if ~isfolder(parent),mkdir(parent);end;tmp=tempname(parent);mkdir(tmp);guard=onCleanup(@()cleanup_tmp(tmp)); %#ok<NASGU>
    final_mat=fullfile(tmp,['CHAPTER5_MAP_STATS_' ym '.mat']);copyfile(stage_mat,final_mat);
    writetable(table(cellstr(S.CHAPTER5_MAP_STATS.processed_dates),repmat({'processed'},numel(S.CHAPTER5_MAP_STATS.processed_dates),1),'VariableNames',{'Date','Status'}),fullfile(tmp,'date_inventory.csv'));
    fid=fopen(fullfile(tmp,'manifest.txt'),'w');fprintf(fid,'manifest_version=manifest-v1\nproduct_type=CHAPTER5_MAP_STATS\nproduct_key=%s\nperiod=%s-%s\nstatus=PASS\nprocessed_days=%d\nmissing_days=%d\nschema_version=ch5-map-stats-v1\n',key,yyyy,mm,numel(S.CHAPTER5_MAP_STATS.processed_dates),numel(S.CHAPTER5_MAP_STATS.missing_dates));fclose(fid);
    final_dir=controlled_publish_month_dir(tmp,final_dir,S.CHAPTER5_MAP_STATS.processed_dates,'CHAPTER5_MAP_STATS');guard=[];fid=fopen(fullfile(final_dir,'_SUCCESS'),'w');fprintf(fid,'status=PASS\nproduct_key=%s\nperiod=%s\n',key,ym);fclose(fid);final_mat=fullfile(final_dir,['CHAPTER5_MAP_STATS_' ym '.mat']);
end
function cleanup_tmp(p),if isfolder(p),rmdir(p,'s');end,end
