function report = test_chapter5_v2_month_gate(candidate_path,daily_root,clear_root,date_inventory_path,report_path)
%TEST_CHAPTER5_V2_MONTH_GATE Independently re-pool daily candidates.
% Validates pooled sums/counts, frozen coverage, and the clear-air denominator.

if nargin<5, report_path=''; end
cfg=chapter5_v2_config();
M=builtin('load',candidate_path,'CHAPTER5_MAP_STATS_V2');
assert(isfield(M,'CHAPTER5_MAP_STATS_V2'),'Chapter5v2:MonthGate','Monthly candidate variable missing.');
X=M.CHAPTER5_MAP_STATS_V2;
assert(strcmp(X.status,'candidate_unpublished'),'Chapter5v2:MonthGate','Unexpected monthly candidate status.');
inv=readtable(date_inventory_path,'TextType','string'); ready=inv.status=="READY";
ready_dates=normalize_dates(inv.date(ready));
missing_dates=normalize_dates(inv.date(~ready));
assert(numel(X.processed_dates)==nnz(ready),'Chapter5v2:MonthGate','Processed-date count mismatch.');
assert(isequal(normalize_dates(X.processed_dates),ready_dates),'Chapter5v2:MonthGate','Processed-date order differs from frozen inventory.');
assert(isequal(normalize_dates(X.missing_dates),missing_dates),'Chapter5v2:MonthGate','Missing-date list differs from frozen inventory.');

nlat=36; nlon=72; nd_sum=zeros(nlat,nlon,2,7); aerosol_count=zeros(nlat,nlon,2); clear_count=zeros(nlat,nlon,2);
dn_names=string(cfg.daynight); month_id=month(datetime(X.period_start,'InputFormat','yyyy-MM-dd')); month_field=char(string(cfg.month_names{month_id}));
clear_centers=(0.03:0.06:14.97)'; clear_mask=clear_centers<=cfg.grid.altitude_limit_km;
for q=find(ready)'
    d=datetime(inv.date(q),'InputFormat','yyyy-MM-dd'); ymd=char(string(d,'yyyyMMdd'));
    dp=find_daily_candidate(daily_root,ymd);
    assert(~isempty(dp),'Chapter5v2:MonthGate','No candidate for frozen ready date %s.',ymd);
    cp=fullfile(clear_root,char(string(d,'yyyy')),char(string(d,'MM')),char(string(d,'dd')),['CLEAR_AIR_STATS_' ymd '.mat']);
    A=builtin('load',dp,'CALIPSO_STATS_CH5_V2'); C=builtin('load',cp,'CLEAR_STATS');
    for i=1:nlat
        for j=1:nlon
            for dn=1:2
                dnf=char(dn_names(dn));
                if isfield(C.CLEAR_STATS.grid(i,j),dnf) && isstruct(C.CLEAR_STATS.grid(i,j).(dnf)) && isfield(C.CLEAR_STATS.grid(i,j).(dnf),month_field)
                    clear_count(i,j,dn)=clear_count(i,j,dn)+sum(C.CLEAR_STATS.grid(i,j).(dnf).(month_field).count_vert_prof(clear_mask));
                end
                if ~isfield(A.CALIPSO_STATS_CH5_V2.grid(i,j),dnf) || ~isstruct(A.CALIPSO_STATS_CH5_V2.grid(i,j).(dnf)) || ~isfield(A.CALIPSO_STATS_CH5_V2.grid(i,j).(dnf),month_field), continue; end
                block=A.CALIPSO_STATS_CH5_V2.grid(i,j).(dnf).(month_field);
                for t=1:7
                    tf=sprintf('Type%d',t); if ~isfield(block,tf),continue;end
                    tab=block.(tf).data; ok=isfinite(tab.Nd_dry_OMCAM_v2) & tab.Nd_dry_OMCAM_v2>=0 & tab.Height<=cfg.grid.altitude_limit_km;
                    nd_sum(i,j,dn,t)=nd_sum(i,j,dn,t)+sum(tab.Nd_dry_OMCAM_v2(ok));
                    aerosol_count(i,j,dn)=aerosol_count(i,j,dn)+nnz(ok);
                end
            end
        end
    end
    clear A C
    fprintf('CHAPTER5_V2_MONTH_GATE_REPOOLED %d/%d %s\n',find(q==find(ready)),nnz(ready),ymd);
end
nd_err=max(abs(nd_sum(:)-X.nd_sum(:))); aerosol_err=max(abs(aerosol_count(:)-X.aerosol_count(:))); clear_err=max(abs(clear_count(:)-X.clear_count(:)));
assert(nd_err==0 && aerosol_err==0 && clear_err==0,'Chapter5v2:MonthGate','Pooled monthly arrays differ from independent accumulation.');
assert(all(X.aerosol_count(:)>=0) && all(X.clear_count(:)>=0),'Chapter5v2:MonthGate','Negative denominator count.');
report=table(string(datetime('now')),nnz(ready),numel(X.missing_dates),nd_err,aerosol_err,clear_err, ...
    'VariableNames',{'timestamp','processed_dates','missing_dates','max_nd_sum_error','max_aerosol_count_error','max_clear_count_error'});
if ~isempty(report_path)
    folder=fileparts(report_path);if ~isempty(folder)&&~isfolder(folder),mkdir(folder);end
    writetable(report,report_path);
end
fprintf('CHAPTER5_V2_MONTH_GATE PASS processed=%d missing=%d\n',nnz(ready),numel(X.missing_dates));
end

function p=find_daily_candidate(daily_root,ymd)
hits=dir(fullfile(daily_root,['day_' ymd],'stats_ch5_v2_day_*',['CALIPSO_STATS_CH5_V2_' ymd '.mat']));
hits=hits([hits.bytes]>0);if isempty(hits),p='';return;end
[~,idx]=max([hits.datenum]);p=fullfile(hits(idx).folder,hits(idx).name);
end

function out=normalize_dates(x)
if isdatetime(x)
    y=x(:); y.Format='yyyy-MM-dd'; out=string(y);
else
    out=string(x(:));
end
end
