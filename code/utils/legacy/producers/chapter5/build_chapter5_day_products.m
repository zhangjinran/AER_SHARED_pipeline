function status=build_chapter5_day_products(date_str)
%BUILD_CHAPTER5_DAY_PRODUCTS Build/publish T_all, CALIPSO_STATS and CLEAR_STATS for one day.
    dt=datetime(date_str,'InputFormat','yyyy-MM-dd');yyyy=datestr(dt,'yyyy');mm=datestr(dt,'mm');dd=datestr(dt,'dd');ymd=datestr(dt,'yyyymmdd');ymd_us=datestr(dt,'yyyy_mm_dd');
    project='F:\AER_SHARED_PIPELINE';code=fullfile(project,'code');
    % Pin the canonical new-root implementation.  Several legacy folders
    % contain same-named functions, so relying on ambient MATLAB path order
    % can silently select the old ERA5 adapter.
    path_parts = strsplit(path, pathsep);
    legacy_root = 'F:\AER_RETRA_CASE';
    for path_i = 1:numel(path_parts)
        if startsWith(path_parts{path_i}, legacy_root, 'IgnoreCase', true)
            rmpath(path_parts{path_i});
        end
    end
    canonical_dirs = {fullfile(code,'config'), fullfile(code,'publishers'), ...
        fullfile(code,'producers','calipso_stats'), ...
        fullfile(code,'producers','chapter5'), fullfile(code,'root_scripts'), ...
        fullfile(code,'functions'), fullfile(code,'producers','t_all')};
    for path_i = 1:numel(canonical_dirs)
        if contains([pathsep path pathsep], [pathsep canonical_dirs{path_i} pathsep], ...
                'IgnoreCase', true)
            rmpath(canonical_dirs{path_i});
        end
    end
    addpath(fullfile(code,'config'),'-begin');
    addpath(fullfile(code,'producers','calipso_stats'),'-begin');
    addpath(fullfile(code,'producers','chapter5'),'-begin');
    addpath(fullfile(code,'root_scripts'),'-begin');
    addpath(fullfile(code,'functions'),'-begin');
    addpath(fullfile(code,'producers','t_all'),'-begin');
    % Publishers are deliberately last/highest: root_scripts contains an
    % older same-named stats publisher with a different function signature.
    addpath(fullfile(code,'publishers'),'-begin');
    clear get_ERA5_meta build_calipso_step1_day build_shared_tall_day publish_shared_stats_day_real;
    rehash path;
    fprintf('PATH build_shared_tall_day=%s\n',which('build_shared_tall_day'));
    fprintf('PATH build_calipso_step1_day=%s\n',which('build_calipso_step1_day'));
    fprintf('PATH get_ERA5_meta=%s\n',which('get_ERA5_meta'));
    fprintf('PATH publish_shared_stats_day_real=%s\n',which('publish_shared_stats_day_real'));
    cfg=data_roots(); final_ap=fullfile(cfg.CALIPSO_AP_ROOT,yyyy,[ymd_us '.mat']);
    status=struct('date',date_str,'tall','pending','stats','pending','clear','pending');
    if ~nas_isfile_retry(final_ap,'FINAL_MAT')
        status.tall='missing_final_mat';status.stats='skipped';status.clear='skipped';return;
    end
    tall_key='tall__ap-final-v1__era5-real__adapter-v1__qc-v1';tall_dir=fullfile(project,'products','tall','t_all',tall_key,yyyy,mm,dd);tall_mat=fullfile(tall_dir,['T_all_' ymd '.mat']);
    if ~isfile(fullfile(tall_dir,'_SUCCESS'))
        candidate=build_shared_tall_day(date_str,'era5_real');S=load_with_nas_retry(candidate,'T_all');assert(height(S.T_all)>0&&nnz(isfinite(S.T_all.RH))>0,'Daily T_all Gate failed.');clear S;publish_shared_tall_day(date_str,'era5_real');status.tall='published';
    else,status.tall='existing';end
    stats_key='stats__ap-final-v1__era5-real__adapter-v1__qc-v1__stats-v1';stats_dir=fullfile(project,'products','chapter5','calipso_stats',stats_key,yyyy,mm,dd);stats_stage=fullfile(project,'products','chapter5','calipso_stats',stats_key,'_staging',yyyy,mm,dd,['CALIPSO_STATS_' ymd '.mat']);
    if ~isfile(fullfile(stats_dir,'_SUCCESS'))
        build_calipso_stats(tall_mat,stats_stage);A=load_with_nas_retry(stats_stage,'CALIPSO_STATS');assert(isequal(size(A.CALIPSO_STATS.grid),[36 72]),'Daily CALIPSO_STATS Gate failed.');clear A;publish_shared_stats_day_real(date_str);status.stats='published';
    else,status.stats='existing';end
    clear_key='clear__ap-final-v1__grid5deg__z60m__clear-v1';clear_dir=fullfile(project,'products','chapter5','clear_air_stats',clear_key,yyyy,mm,dd);clear_stage=fullfile(project,'products','chapter5','clear_air_stats',clear_key,'_staging',yyyy,mm,dd,['CLEAR_AIR_STATS_' ymd '.mat']);
    if ~isfile(fullfile(clear_dir,'_SUCCESS'))
        build_clear_air_stats_day(date_str,final_ap,clear_stage);publish_clear_air_stats_day(date_str,clear_stage,final_ap);status.clear='published';
    else,status.clear='existing';end
    fprintf('DAY_PRODUCTS_PASS date=%s tall=%s stats=%s clear=%s\n',date_str,status.tall,status.stats,status.clear);
end

function tf=nas_isfile_retry(path_text,label)
    max_attempts=5;
    for attempt=1:max_attempts
        if isfile(path_text)
            if attempt>1, fprintf('%s_PATH_PASS attempt=%d/%d path=%s\n',label,attempt,max_attempts,path_text); end
            tf=true; return
        end
        if attempt<max_attempts
            fprintf(2,'%s_PATH_RETRY attempt=%d/%d path=%s\n',label,attempt,max_attempts,path_text);
            pause(2*attempt);
        end
    end
    fprintf(2,'%s_PATH_MISSING attempts=%d path=%s\n',label,max_attempts,path_text);
    tf=false;
end
