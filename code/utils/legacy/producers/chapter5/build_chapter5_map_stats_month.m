function output_path = build_chapter5_map_stats_month(year_value,month_value,output_path,date_inventory_path,varargin)
%BUILD_CHAPTER5_MAP_STATS_MONTH Stream daily products into compact map statistics.
    ip=inputParser; addParameter(ip,'StatsRoot','',@(x)ischar(x)||isstring(x)); addParameter(ip,'ClearRoot','',@(x)ischar(x)||isstring(x)); parse(ip,varargin{:});
    dt0=datetime(year_value,month_value,1); dt1=dateshift(dt0,'end','month');
    project_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    if nargin<4 || isempty(date_inventory_path), error('Coverage:MissingFinalizedDates','Chapter 5 monthly requires finalized_dates.csv'); end
    addpath(fullfile(project_root,'code','common'),'-begin'); [date_list,~]=read_finalized_dates(date_inventory_path);
    stats_key='stats__ap-final-v1__era5-real__adapter-v1__qc-v1__stats-v1';
    clear_key='clear__ap-final-v1__grid5deg__z60m__clear-v1';
    stats_root=char(ip.Results.StatsRoot); if isempty(stats_root), stats_root=fullfile(project_root,'products','chapter5','calipso_stats',stats_key); end
    clear_root=char(ip.Results.ClearRoot); if isempty(clear_root), clear_root=fullfile(project_root,'products','chapter5','clear_air_stats',clear_key); end
    dn_names={'Day','Night'}; month_names={'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'};
    month_field=month_names{month_value}; alt_limit_km=10; clear_centers=(0.03:0.06:14.97)'; clear_mask=clear_centers<=alt_limit_km;
    nd_sum=zeros(36,72,2,7); aerosol_count=zeros(36,72,2); clear_count=zeros(36,72,2);
    processed_dates=strings(0,1); missing_dates=strings(0,1);
    for k=1:numel(date_list)
        d=datetime(date_list(k),'InputFormat','yyyy-MM-dd'); yyyy=datestr(d,'yyyy'); mm=datestr(d,'mm'); dd=datestr(d,'dd'); ymd=datestr(d,'yyyymmdd');
        stats_dir=fullfile(stats_root,yyyy,mm,dd);
        clear_dir=fullfile(clear_root,yyyy,mm,dd);
        stats_mat=fullfile(stats_dir,['CALIPSO_STATS_' ymd '.mat']); clear_mat=fullfile(clear_dir,['CLEAR_AIR_STATS_' ymd '.mat']);
        if ~isfile(fullfile(stats_dir,'_SUCCESS')) || ~isfile(fullfile(clear_dir,'_SUCCESS')) || ~isfile(stats_mat) || ~isfile(clear_mat)
            error('Coverage:MissingDailyInput','Frozen ready date lacks Stats or Clear product: %s',ymd);
        end
        A=load_with_nas_retry(stats_mat,'CALIPSO_STATS'); C=load_with_nas_retry(clear_mat,'CLEAR_STATS');
        for i=1:36
            for j=1:72
                for dn=1:2
                    dn_name=dn_names{dn};
                    try
                        vp=C.CLEAR_STATS.grid(i,j).(dn_name).(month_field).count_vert_prof;
                        clear_count(i,j,dn)=clear_count(i,j,dn)+sum(vp(clear_mask));
                    catch
                    end
                    try
                        mo=A.CALIPSO_STATS.grid(i,j).(dn_name).(month_field);
                        for t=1:7
                            tp=sprintf('Type%d',t);
                            if ~isfield(mo,tp), continue; end
                            tab=mo.(tp).data; vals=tab.Nd_dry_OMCAM; h=tab.Height;
                            ok=isfinite(vals)&vals>0&h<=alt_limit_km;
                            nd_sum(i,j,dn,t)=nd_sum(i,j,dn,t)+sum(vals(ok));
                            aerosol_count(i,j,dn)=aerosol_count(i,j,dn)+nnz(ok);
                        end
                    catch
                    end
                end
            end
        end
        processed_dates(end+1,1)=string(d,'yyyy-MM-dd'); %#ok<AGROW>
        clear A C
        fprintf('[%d/%d] %s accumulated\n',k,numel(date_list),datestr(d,'yyyy-mm-dd'));
    end
    CHAPTER5_MAP_STATS=struct('nd_sum',nd_sum,'aerosol_count',aerosol_count,'clear_count',clear_count, ...
        'processed_dates',processed_dates,'missing_dates',missing_dates,'alt_limit_km',alt_limit_km,'daynight',{dn_names}, ...
        'period_start',char(string(dt0,'yyyy-MM-dd')),'period_end',char(string(dt1,'yyyy-MM-dd')),'schema_version','ch5-map-stats-v1'); %#ok<NASGU>
    outdir=fileparts(output_path); if ~isfolder(outdir),mkdir(outdir);end
    save(output_path,'CHAPTER5_MAP_STATS','-v7.3');
    fprintf('MONTH_STATS saved processed=%d missing=%d output=%s\n',numel(processed_dates),numel(missing_dates),output_path);
end
