function output_path = build_ccn_grid_monthly_from_daily(year_num, month_num, output_path, date_inventory_path, varargin)
%BUILD_CCN_GRID_MONTHLY_FROM_DAILY Sample-weighted monthly CCN aggregation.
project='F:\AER_SHARED_PIPELINE'; cfg=data_roots(); key='ccn__ap-final-v1__era5-real__grid5deg__ccn-v1';
ip=inputParser; addParameter(ip,'InputRoot','',@(x)ischar(x)||isstring(x)); parse(ip,varargin{:}); input_root=char(ip.Results.InputRoot); if isempty(input_root), input_root=fullfile(cfg.CCN_GRID_ROOT,key); end
if nargin<4 || isempty(date_inventory_path), error('Coverage:MissingFinalizedDates','CCN monthly requires finalized_dates.csv'); end
addpath(fullfile(project,'code','common'),'-begin'); [date_list,~]=read_finalized_dates(date_inventory_path);
sum_month=zeros(36,72,3); cnt_month=zeros(36,72); processed=[]; missing=[];
for k=1:numel(date_list)
    dt=datetime(date_list(k),'InputFormat','yyyy-MM-dd');
    ymd=datestr(dt,'yyyymmdd'); p=fullfile(input_root,datestr(dt,'yyyy'),datestr(dt,'mm'),datestr(dt,'dd'),sprintf('CCN_GRID_%s.mat',ymd));
    if ~isfile(p) || ~isfile(fullfile(fileparts(p),'_SUCCESS')), error('Coverage:MissingDailyCCN','Frozen ready date lacks daily CCN: %s',ymd); end
    S=load_with_nas_retry(p,'M','cnt');
    if ~isequal(size(S.M),[36 72 3]) || ~isequal(size(S.cnt),[36 72]), error('CCN:MonthlySchema','Invalid daily schema: %s',p); end
    for q=1:3, z=S.M(:,:,q); z(~isfinite(z))=0; sum_month(:,:,q)=sum_month(:,:,q)+z.*S.cnt; end
    cnt_month=cnt_month+S.cnt; processed(end+1)=str2double(ymd);
end
M=nan(36,72,3); for q=1:3, z=sum_month(:,:,q); z(cnt_month==0)=nan; z(cnt_month>0)=z(cnt_month>0)./cnt_month(cnt_month>0); M(:,:,q)=z; end
meta=struct('product_type','CCN_GRID_MONTHLY','aggregation','sample_weighted_mean','source_product','daily CCN_GRID','year',year_num,'month',month_num,'processed_days',processed,'missing_days',missing,'grid_size_deg',5,'supersaturation_percent',[0.15 0.25 0.40],'formal_science_product',true);
if ~isfolder(fileparts(output_path)), mkdir(fileparts(output_path)); end
save(output_path,'M','sum_month','cnt_month','meta','-v7.3'); fprintf('CCN_MONTHLY_PASS processed=%d missing=%d output=%s\n',numel(processed),numel(missing),output_path);
end
