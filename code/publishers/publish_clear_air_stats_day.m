function final_mat = publish_clear_air_stats_day(date_str, stage_mat, final_calipso_mat)
%PUBLISH_CLEAR_AIR_STATS_DAY Publish one immutable daily CLEAR_STATS product.
    dt=datetime(date_str,'InputFormat','yyyy-MM-dd');
    project_root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    key='clear__ap-final-v1__grid5deg__z60m__clear-v1';
    yyyy=datestr(dt,'yyyy'); mm=datestr(dt,'mm'); dd=datestr(dt,'dd'); ymd=datestr(dt,'yyyymmdd');
    final_dir=fullfile(project_root,'products','chapter5','clear_air_stats',key,yyyy,mm,dd);
    if isfile(fullfile(final_dir,'_SUCCESS')), error('ClearStats:AlreadyPublished','Immutable product already exists: %s',final_dir); end
    if isfolder(final_dir), error('ClearStats:IncompleteFinal','Refusing existing incomplete final directory: %s',final_dir); end
    if ~isfile(stage_mat), error('ClearStats:MissingStage','Missing stage MAT: %s',stage_mat); end
    S=load_with_nas_retry(stage_mat,'CLEAR_STATS','processed_files');
    if ~isfield(S,'CLEAR_STATS') || ~isfield(S.CLEAR_STATS,'grid') || ~isequal(size(S.CLEAR_STATS.grid),[36 72])
        error('ClearStats:Schema','Expected CLEAR_STATS.grid size [36 72].');
    end
    parent=fileparts(final_dir); if ~isfolder(parent), mkdir(parent); end
    tmp=tempname(parent); mkdir(tmp); guard=onCleanup(@()cleanup_tmp(tmp)); %#ok<NASGU>
    final_mat=fullfile(tmp,sprintf('CLEAR_AIR_STATS_%s.mat',ymd)); copyfile(stage_mat,final_mat);
    info=dir(final_calipso_mat); inv=table({'Final_CALIPSO_MAT'},{final_calipso_mat},info.bytes,{info.date},'VariableNames',{'Kind','Path','Bytes','LastModified'}); writetable(inv,fullfile(tmp,'input_inventory.csv'));
    fid=fopen(fullfile(tmp,'manifest.txt'),'w'); fprintf(fid,'manifest_version=manifest-v1\nproduct_type=CLEAR_AIR_STATS\nproduct_key=%s\ndate=%s\nstatus=PASS\nproducer=build_clear_air_stats_day.m\ngrid=5deg\nvertical_bin=0.06km\nsuccess_marker=_SUCCESS\n',key,date_str); fclose(fid);
    movefile(tmp,final_dir); guard=[];
    fid=fopen(fullfile(final_dir,'_SUCCESS'),'w'); fprintf(fid,'status=PASS\nproduct_key=%s\ndate=%s\n',key,date_str); fclose(fid);
    final_mat=fullfile(final_dir,sprintf('CLEAR_AIR_STATS_%s.mat',ymd));
end

function cleanup_tmp(p), if isfolder(p), rmdir(p,'s'); end, end
