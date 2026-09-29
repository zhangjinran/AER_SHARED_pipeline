function final_mat=publish_shared_stats_day(date_str,scenario_name)
%PUBLISH_SHARED_STATS_DAY Publish a Gate-D validated CALIPSO_STATS day.
    shared_dir=fileparts(mfilename('fullpath')); pipeline_root=fileparts(shared_dir); project_root=fileparts(pipeline_root);
    addpath(fullfile(pipeline_root,'config')); cfg=data_roots(); v=product_versions();
    if ~strcmpi(scenario_name,'virtual_rh50'), error('publish_shared_stats_day:Scenario','Only validated virtual_rh50 is publishable here.'); end
    [y,mo,d]=datevec(datetime(date_str,'InputFormat','yyyy-MM-dd')); %#ok<ASGLU>
    yyyy=datestr(datetime(date_str,'InputFormat','yyyy-MM-dd'),'yyyy'); mm=datestr(datetime(date_str,'InputFormat','yyyy-MM-dd'),'mm'); dd=datestr(datetime(date_str,'InputFormat','yyyy-MM-dd'),'dd'); yyyymmdd=datestr(datetime(date_str,'InputFormat','yyyy-MM-dd'),'yyyymmdd');
    product_key=sprintf('stats__%s__%s__%s__%s',v.AP_VERSION,'virtual-rh50',v.STATS_VERSION,'candidate');
    % Preserve the established candidate key while publishing its frozen counterpart.
    candidate_key='stats__ap-final-v1__virtual-rh50__adapter-v1__qc-v1__stats-v1';
    product_root=fullfile(cfg.SHARED_STATS_ROOT,candidate_key); stage_dir=fullfile(product_root,'_staging',yyyy,mm,dd); stage_mat=fullfile(stage_dir,sprintf('CALIPSO_STATS_%s.mat',yyyymmdd));
    final_root=fullfile(cfg.SHARED_STATS_ROOT,'stats__ap-final-v1__virtual-rh50__adapter-v1__qc-v1__stats-v1'); final_dir=fullfile(final_root,yyyy,mm,dd); success_file=fullfile(final_dir,'_SUCCESS');
    if isfile(success_file), error('publish_shared_stats_day:AlreadyPublished','Successful stats product is immutable.'); end
    if ~isfile(stage_mat), error('publish_shared_stats_day:MissingStage','Missing candidate stats: %s',stage_mat); end
    if isfolder(final_dir), error('publish_shared_stats_day:ExistingFinal','Final stats directory exists without _SUCCESS.'); end
    final_parent=fileparts(final_dir); if ~isfolder(final_parent), mkdir(final_parent); end
    tmp_dir=tempname(final_parent); mkdir(tmp_dir); tmp_mat=fullfile(tmp_dir,sprintf('CALIPSO_STATS_%s.mat',yyyymmdd)); copyfile(stage_mat,tmp_mat);
    inv=table({'T_all';'CALIPSO_STATS_candidate'},{'virtual shared T_all';stage_mat},[0;dir(stage_mat).bytes],{'';dir(stage_mat).date},'VariableNames',{'Kind','Path','Bytes','LastModified'}); writetable(inv,fullfile(tmp_dir,'input_inventory.csv'));
    fid=fopen(fullfile(tmp_dir,'manifest.txt'),'w'); fprintf(fid,'manifest_version=%s\nproduct_type=CALIPSO_STATS\nproduct_key=%s\nstatus=PASS\n',v.MANIFEST_VERSION,'stats__ap-final-v1__virtual-rh50__adapter-v1__qc-v1__stats-v1'); fprintf(fid,'date=%s\nscenario=virtual_rh50\nproducer=build_calipso_stats.m\ngate_d=PASS\nsource_tall_status=shared_derived_frozen\nscientific_status=VIRTUAL_RH50_ENGINEERING_BASELINE\nformal_science_product=false\nschema_version=stats-v1\nsuccess_marker=_SUCCESS\n',date_str); fclose(fid);
    movefile(tmp_dir,final_dir); fid=fopen(success_file,'w'); fprintf(fid,'status=PASS\nproduct_key=%s\ndate=%s\npublished_time=%s\n',candidate_key,date_str,char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'))); fclose(fid);
    final_mat=fullfile(final_dir,sprintf('CALIPSO_STATS_%s.mat',yyyymmdd)); if isfolder(stage_dir), rmdir(stage_dir,'s'); end
    fprintf('SHARED CALIPSO_STATS PUBLISHED\nfinal=%s\n_SUCCESS=PASS\n',final_mat);
end
