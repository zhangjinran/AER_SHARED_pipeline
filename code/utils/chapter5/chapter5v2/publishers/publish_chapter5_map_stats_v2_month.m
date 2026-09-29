function final_mat = publish_chapter5_map_stats_v2_month(year_value,month_value,candidate_path,date_inventory_path)
%PUBLISH_CHAPTER5_MAP_STATS_V2_MONTH Atomically publish a gated month MAT.
cfg=chapter5_v2_config();ym=sprintf('%04d%02d',year_value,month_value);final_dir=fullfile(cfg.map_product_root,sprintf('%04d',year_value),sprintf('%02d',month_value));final_mat=fullfile(final_dir,['CHAPTER5_MAP_STATS_V2_' ym '.mat']);
if isfolder(final_dir),error('Chapter5v2:Immutable','Final month directory already exists: %s',final_dir);end
if ~isfile(candidate_path)||dir(candidate_path).bytes==0,error('Chapter5v2:Candidate','Missing month candidate.');end
S=builtin('load',candidate_path,'CHAPTER5_MAP_STATS_V2');X=S.CHAPTER5_MAP_STATS_V2;
inv=readtable(date_inventory_path,'TextType','string');ready=inv.status=="READY";
if ~strcmp(X.status,'candidate_unpublished') || numel(X.processed_dates)~=nnz(ready) || numel(X.missing_dates)~=nnz(~ready)
    error('Chapter5v2:MonthGate','Monthly candidate does not meet frozen date contract.');
end
for q=find(ready)'
    d=datetime(string(inv.date(q)),'InputFormat','yyyy-MM-dd'); day_dir=fullfile(cfg.stats_product_root,char(string(d,'yyyy')),char(string(d,'MM')),char(string(d,'dd')));
    if ~isfile(fullfile(day_dir,'_SUCCESS')),error('Chapter5v2:DayDependency','Formal daily product absent: %s',char(inv.date(q)));end
end
parent=fileparts(final_dir);if ~isfolder(parent),mkdir(parent);end
tmp=[final_dir '__publishing'];if isfolder(tmp),error('Chapter5v2:PublishTemp','Stale publishing directory exists: %s',tmp);end
mkdir(tmp);[ok,msg]=movefile(candidate_path,fullfile(tmp,['CHAPTER5_MAP_STATS_V2_' ym '.mat']));if ~ok,error('Chapter5v2:Move',msg);end
writetable(inv,fullfile(tmp,'input_inventory.csv'));
fid=fopen(fullfile(tmp,'manifest.txt'),'w');fprintf(fid,['manifest_version=manifest-v2\nproduct_type=CHAPTER5_MAP_STATS_V2\nproduct_key=%s\nstatus=PASS\nperiod=%s\n', ...
    'daily_product_key=%s\nclear_product_key=%s\naggregation=pooled_sum_over_aerosol_plus_clear\naltitude_limit_km=10\nprocessed_days=%d\nmissing_days=%d\nsuccess_marker=_SUCCESS\n'], ...
    cfg.map_product_key,ym,cfg.stats_product_key,clear_key(),numel(X.processed_dates),numel(X.missing_dates));fclose(fid);
[ok,msg]=movefile(tmp,final_dir);if ~ok,error('Chapter5v2:PublishMove',msg);end
fid=fopen(fullfile(final_dir,'_SUCCESS'),'w');fprintf(fid,'status=PASS\nproduct_key=%s\nperiod=%s\n',cfg.map_product_key,ym);fclose(fid);
fprintf('CHAPTER5_V2_MONTH_PUBLISHED month=%s path=%s\n',ym,final_mat);
end
function key=clear_key()
key=getenv('CHAPTER5_V2_CLEAR_PRODUCT_KEY');
if isempty(key),key='clear__ap-final-v1__grid5deg__z60m__clear-v1';end
end
