function final_mat=publish_aod_grid_month(candidate_mat,year_value,month_value,daily_paths,run_inventory)
%PUBLISH_AOD_GRID_MONTH Immutable pooled monthly AOD publisher.
cfg=aod_config(); ym=sprintf('%04d%02d',year_value,month_value);
final_dir=fullfile(cfg.monthly_root,sprintf('%04d',year_value),sprintf('%02d',month_value));
if isfolder(final_dir),error('AOD:PublishNoOverwrite','Monthly product target exists: %s',final_dir);end
if ~isfile(candidate_mat)||isempty(daily_paths),error('AOD:PublishInput','Monthly candidate or daily sources missing.');end
Q=load(candidate_mat,'AOD_GRID_MONTH'); X=Q.AOD_GRID_MONTH;
if ~strcmp(X.meta.period,ym)||~strcmp(X.meta.product_key,cfg.monthly_key)
    error('AOD:PublishContract','Monthly candidate metadata mismatch.');
end
parent=fileparts(final_dir); if ~isfolder(parent),mkdir(parent);end
tmp=tempname(parent); mkdir(tmp);
try
    name=sprintf('AOD_GRID_MONTH_%s.mat',ym); copyfile(candidate_mat,fullfile(tmp,name));
    roles=strings(numel(daily_paths)+1,1); paths=roles; bytes=zeros(numel(daily_paths)+1,1,'uint64'); modified=roles;
    for k=1:numel(daily_paths)
        roles(k)="daily_AOD_GRID"; paths(k)=string(daily_paths{k}); d=dir(daily_paths{k}); bytes(k)=uint64(d.bytes); modified(k)=string(d.date);
    end
    roles(end)="frozen_date_inventory"; paths(end)=string(run_inventory); d=dir(run_inventory); bytes(end)=uint64(d.bytes); modified(end)=string(d.date);
    writetable(table(roles,paths,bytes,modified,'VariableNames',{'role','path','bytes','modified'}),fullfile(tmp,'input_inventory.csv'));
    fid=fopen(fullfile(tmp,'manifest.txt'),'w'); if fid<0,error('AOD:Manifest','Cannot write manifest.');end
    fprintf(fid,'manifest_version=manifest-v1\nproduct_type=AOD_GRID_MONTH\nproduct_key=%s\nstatus=PASS\nperiod=%s\ngrid=global_5x5deg\naggregation=pooled_profile_sum_over_pooled_profile_count\nready_days=%d\n',cfg.monthly_key,ym,numel(daily_paths)); fclose(fid);
    fid=fopen(fullfile(tmp,'_SUCCESS'),'w'); if fid<0,error('AOD:SuccessMarker','Cannot write success marker.');end
    fprintf(fid,'status=PASS\nproduct_key=%s\nperiod=%s\nready_days=%d\n',cfg.monthly_key,ym,numel(daily_paths)); fclose(fid);
    [ok,msg]=movefile(tmp,final_dir); if ~ok,error('AOD:PublishMove','%s',msg);end
catch ME
    rethrow(ME);
end
final_mat=fullfile(final_dir,sprintf('AOD_GRID_MONTH_%s.mat',ym));
fprintf('AOD_MONTH_PUBLISHED period=%s path=%s\n',ym,final_mat);
end
