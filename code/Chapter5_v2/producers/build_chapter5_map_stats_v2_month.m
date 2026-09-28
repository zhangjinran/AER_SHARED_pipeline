function output_path = build_chapter5_map_stats_v2_month(year_value, month_value, daily_root, clear_root, date_inventory_path, output_path)
%BUILD_CHAPTER5_MAP_STATS_V2_MONTH Stream daily Chapter5_v2 candidates.
% Monthly means are formed from pooled sum/count, never daily means.

cfg = chapter5_v2_config();
inv = readtable(date_inventory_path,'TextType','string');
must_have = {'date','status','reason'};
if ~all(ismember(must_have,inv.Properties.VariableNames))
    error('Chapter5v2:Inventory','Frozen date inventory must contain date,status,reason.');
end
ready = inv.status == "READY";
missing_dates = inv.date(~ready);
nlat=36; nlon=72; nd_sum=zeros(nlat,nlon,2,7); aerosol_count=zeros(nlat,nlon,2); clear_count=zeros(nlat,nlon,2);
processed_dates=strings(0,1); clear_centers=(0.03:0.06:14.97)'; clear_mask=clear_centers<=cfg.grid.altitude_limit_km;
dn_names=string(cfg.daynight); month_names=string(cfg.month_names); month_field=char(month_names(month_value));

for q=find(ready)'
    d=datetime(inv.date(q),'InputFormat','yyyy-MM-dd'); ymd=char(string(d,'yyyyMMdd'));
    candidate_path = find_daily_candidate(daily_root,ymd);
    if isempty(candidate_path)
        error('Chapter5v2:MissingDailyCandidate','Frozen ready date has no daily candidate: %s',ymd);
    end
    clear_dir=fullfile(clear_root,char(string(d,'yyyy')),char(string(d,'MM')),char(string(d,'dd')));
    clear_path=fullfile(clear_dir,['CLEAR_AIR_STATS_' ymd '.mat']);
    if ~isfile(fullfile(clear_dir,'_SUCCESS')) || ~isfile(clear_path)
        error('Chapter5v2:MissingClear','Frozen ready date lacks formal CLEAR_AIR_STATS: %s',ymd);
    end
    A=builtin('load',candidate_path,'CALIPSO_STATS_CH5_V2');
    C=builtin('load',clear_path,'CLEAR_STATS');
    if ~strcmp(A.CALIPSO_STATS_CH5_V2.meta.status,'candidate_unpublished')
        error('Chapter5v2:DailyStatus','Unexpected daily candidate status for %s.',ymd);
    end
    for i=1:nlat
        for j=1:nlon
            for dn=1:2
                dnf=char(dn_names(dn));
                % Struct-array field sharing makes absent nested fields [].
                if isfield(C.CLEAR_STATS.grid(i,j),dnf) && isstruct(C.CLEAR_STATS.grid(i,j).(dnf)) && ...
                        isfield(C.CLEAR_STATS.grid(i,j).(dnf),month_field)
                    vp=C.CLEAR_STATS.grid(i,j).(dnf).(month_field).count_vert_prof;
                    clear_count(i,j,dn)=clear_count(i,j,dn)+sum(vp(clear_mask));
                end
                if ~isfield(A.CALIPSO_STATS_CH5_V2.grid(i,j),dnf) || ~isstruct(A.CALIPSO_STATS_CH5_V2.grid(i,j).(dnf)) || ...
                        ~isfield(A.CALIPSO_STATS_CH5_V2.grid(i,j).(dnf),month_field)
                    continue
                end
                block=A.CALIPSO_STATS_CH5_V2.grid(i,j).(dnf).(month_field);
                for t=1:7
                    tf=sprintf('Type%d',t);
                    if ~isfield(block,tf), continue; end
                    tab=block.(tf).data;
                    ok=isfinite(tab.Nd_dry_OMCAM_v2) & tab.Nd_dry_OMCAM_v2>=0 & tab.Height<=cfg.grid.altitude_limit_km;
                    nd_sum(i,j,dn,t)=nd_sum(i,j,dn,t)+sum(tab.Nd_dry_OMCAM_v2(ok));
                    aerosol_count(i,j,dn)=aerosol_count(i,j,dn)+nnz(ok);
                end
            end
        end
    end
    processed_dates(end+1,1)=string(d,'yyyy-MM-dd'); %#ok<AGROW>
    fprintf('CHAPTER5_V2_MONTH_ACCUMULATED %d/%d date=%s\n',numel(processed_dates),nnz(ready),ymd);
    clear A C
end

period_start=datetime(year_value,month_value,1); period_start.Format='yyyy-MM-dd';
period_end=dateshift(period_start,'end','month'); period_end.Format='yyyy-MM-dd';
CHAPTER5_MAP_STATS_V2=struct( ...
    'schema_version','chapter5-map-stats-v2', ...
    'product_key',cfg.map_product_key, ...
    'nd_sum',nd_sum, ...
    'aerosol_count',aerosol_count, ...
    'clear_count',clear_count, ...
    'processed_dates',processed_dates, ...
    'missing_dates',missing_dates, ...
    'date_inventory_path',date_inventory_path, ...
    'alt_limit_km',cfg.grid.altitude_limit_km, ...
    'daynight',{cfg.daynight}, ...
    'period_start',char(period_start), ...
    'period_end',char(period_end), ...
    'status','candidate_unpublished'); %#ok<NASGU>
folder=fileparts(output_path); if ~isfolder(folder),mkdir(folder);end
save(output_path,'CHAPTER5_MAP_STATS_V2','-v7.3');
fprintf('CHAPTER5_V2_MONTH_CANDIDATE PASS processed=%d missing=%d output=%s\n',numel(processed_dates),numel(missing_dates),output_path);
end

function p=find_daily_candidate(daily_root,ymd)
hits=dir(fullfile(daily_root,['day_' ymd],'stats_ch5_v2_day_*',['CALIPSO_STATS_CH5_V2_' ymd '*.mat']));
hits=hits([hits.bytes]>0);
if isempty(hits),p='';return;end
[~,idx]=max([hits.datenum]);
p=fullfile(hits(idx).folder,hits(idx).name);
end
