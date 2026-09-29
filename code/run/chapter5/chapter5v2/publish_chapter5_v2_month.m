function publish_chapter5_v2_month(year_value,month_value,run_root)
%PUBLISH_CHAPTER5_V2_MONTH Publish gated Phase-3 candidates without copying.
cfg=chapter5_v2_config();addpath(fullfile(cfg.code_root,'publishers'),'-begin');
ym=sprintf('%04d%02d',year_value,month_value);inv_path=fullfile(run_root,['date_inventory_' ym '_frozen.csv']);inv=readtable(inv_path,'TextType','string');ready=inv.status=="READY";
report_root=fullfile(run_root,'reports','phase3_day_gates');published=strings(height(inv),1);
for q=1:height(inv)
    if ~ready(q),published(q)="SKIPPED_"+inv.status(q);continue;end
    d=datetime(string(inv.date(q)),'InputFormat','yyyy-MM-dd');ymd=char(string(d,'yyyyMMdd'));hits=dir(fullfile(run_root,'staging',['day_' ymd],'stats_ch5_v2_day_*',['CALIPSO_STATS_CH5_V2_' ymd '.mat']));hits=hits([hits.bytes]>0);
    if isempty(hits),error('Chapter5v2:Candidate','No nonzero candidate for %s.',ymd);end
    [~,newest]=max([hits.datenum]); hit=hits(newest);
    publish_calipso_stats_ch5_v2_day(char(string(d,'yyyy-MM-dd')),fullfile(hit.folder,hit.name),fullfile(report_root,['day_' ymd '_gate.csv']));published(q)="PUBLISHED";
end
writetable(table(inv.date,inv.status,published,'VariableNames',{'date','frozen_status','publish_status'}),fullfile(run_root,'reports',['phase4_publish_days_' ym '.csv']));
if any(ready & published~="PUBLISHED"),error('Chapter5v2:Publish','Not all ready days published.');end
candidate=fullfile(run_root,'staging',['month_' ym],['CHAPTER5_MAP_STATS_V2_' ym '.mat']);
publish_chapter5_map_stats_v2_month(year_value,month_value,candidate,inv_path);
fprintf('CHAPTER5_V2_PHASE4_PUBLISH_PASS month=%s\n',ym);
end
