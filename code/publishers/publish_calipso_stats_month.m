function final_mat = publish_calipso_stats_month(year_value, month_value, stage_mat)
%PUBLISH_CALIPSO_STATS_MONTH Publish immutable monthly detailed Stats.
    % mfilename is ...\code\publishers\publish_calipso_stats_month.m.
    % Ascend through publishers and code to the pipeline root.
    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    key = 'stats-monthly__ap-final-v1__era5-real__adapter-v1__qc-v1';
    yyyy = sprintf('%04d',year_value); mm = sprintf('%02d',month_value);
    ym = sprintf('%04d%02d',year_value,month_value);
    final_dir = fullfile(project_root,'products','chapter5','calipso_stats_monthly',key,'monthly',yyyy,mm);
    if isfolder(final_dir) && ~isfile(fullfile(final_dir,'_SUCCESS'))
        error('StatsMonthly:IncompleteFinal','Refusing incomplete final directory: %s',final_dir);
    end
    S = load_with_nas_retry(stage_mat,'CALIPSO_STATS');
    if ~isfield(S,'CALIPSO_STATS') || ~isfield(S.CALIPSO_STATS,'grid')
        error('StatsMonthly:Schema','Missing CALIPSO_STATS.grid in %s',stage_mat);
    end
    parent = fileparts(final_dir); if ~isfolder(parent), mkdir(parent); end
    tmp_dir = tempname(parent); mkdir(tmp_dir);
    cleanup = onCleanup(@() cleanup_tmp(tmp_dir)); %#ok<NASGU>
    final_mat = fullfile(tmp_dir,['CALIPSO_STATS_Monthly_' ym '.mat']);
    copyfile(stage_mat,final_mat);
    dates = string(S.CALIPSO_STATS.meta.processed_dates);
    status = repmat("processed",numel(dates),1);
    missing = string(S.CALIPSO_STATS.meta.missing_dates);
    dates = [dates;missing]; status = [status;repmat("missing_daily_stats",numel(missing),1)];
    writetable(table(dates,status,'VariableNames',{'Date','Status'}),fullfile(tmp_dir,'input_inventory.csv'));
    fid = fopen(fullfile(tmp_dir,'manifest.txt'),'w');
    fprintf(fid,['manifest_version=manifest-v1\nproduct_type=CALIPSO_STATS_MONTHLY\nproduct_key=%s\n' ...
        'period=%s-%s\nstatus=PASS\nprocessed_days=%d\nmissing_days=%d\n' ...
        'source_daily_calipso_stats=published\nschema_version=stats-monthly-v1\n'], ...
        key,yyyy,mm,numel(S.CALIPSO_STATS.meta.processed_dates),numel(S.CALIPSO_STATS.meta.missing_dates));
    fclose(fid);
    final_dir=controlled_publish_month_dir(tmp_dir,final_dir,S.CALIPSO_STATS.meta.processed_dates,'CALIPSO_STATS_MONTHLY'); cleanup=[];
    fid=fopen(fullfile(final_dir,'_SUCCESS'),'w');
    fprintf(fid,'status=PASS\nproduct_key=%s\nperiod=%s\n',key,ym); fclose(fid);
    final_mat = fullfile(final_dir,['CALIPSO_STATS_Monthly_' ym '.mat']);
end

function cleanup_tmp(path_value)
    if isfolder(path_value), rmdir(path_value,'s'); end
end
