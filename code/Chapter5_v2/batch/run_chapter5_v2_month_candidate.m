function run_chapter5_v2_month_candidate(year_value,month_value,run_root)
%RUN_CHAPTER5_V2_MONTH_CANDIDATE Sequential, resumable Phase-3 candidate run.
cfg=chapter5_v2_config();
if nargin<3 || isempty(run_root), error('Chapter5v2:RunRoot','run_root is required.'); end
addpath(fullfile(cfg.code_root,'config'),'-begin');
addpath(fullfile(cfg.code_root,'science_core'),'-begin');
addpath(fullfile(cfg.code_root,'producers'),'-begin');
addpath(fullfile(cfg.code_root,'validation'),'-begin');
ym=sprintf('%04d%02d',year_value,month_value);
inventory=fullfile(run_root,['date_inventory_' ym '_frozen.csv']);
if ~isfile(inventory),error('Chapter5v2:Inventory','Frozen inventory missing: %s',inventory);end
inv=readtable(inventory,'TextType','string');
daily_root=fullfile(run_root,'staging'); report_root=fullfile(run_root,'reports','phase3_day_gates');
if ~isfolder(report_root),mkdir(report_root);end
statuses=strings(height(inv),1);
for q=1:height(inv)
    if inv.status(q)~="READY"
        statuses(q)="SKIPPED_"+inv.status(q); fprintf('CHAPTER5_V2_DAY_SKIP date=%s status=%s\n',inv.date(q),inv.status(q)); continue
    end
    d=datetime(inv.date(q),'InputFormat','yyyy-MM-dd'); ymd=char(string(d,'yyyyMMdd'));
    day_root=fullfile(daily_root,['day_' ymd]);
    candidate=find_daily_candidate(day_root,ymd);
    gate=fullfile(report_root,['day_' ymd '_gate.csv']);
    if isempty(candidate)
        stage=fullfile(day_root,'stats_ch5_v2_day_001'); if ~isfolder(stage),mkdir(stage);end
        candidate=fullfile(stage,['CALIPSO_STATS_CH5_V2_' ymd '.mat']);
        tall=fullfile(cfg.project_root,'products','tall','t_all','tall__ap-final-v1__era5-real__adapter-v1__qc-v1', ...
            char(string(d,'yyyy')),char(string(d,'MM')),char(string(d,'dd')),['T_all_' ymd '.mat']);
        build_calipso_stats_ch5_v2_day(tall,candidate);
    end
    test_chapter5_v2_day_gate(candidate,gate);
    statuses(q)="GATE_PASS";
    fprintf('CHAPTER5_V2_DAY_PASS date=%s candidate=%s\n',ymd,candidate);
end
writetable(table(inv.date,inv.status,inv.reason,statuses,'VariableNames',{'date','frozen_status','reason','phase3_status'}), ...
    fullfile(run_root,['phase3_day_status_' ym '.csv']));
if any(inv.status=="READY" & statuses~="GATE_PASS")
    error('Chapter5v2:Coverage','Not all frozen ready dates passed their daily Gate.');
end
clear_root=fullfile(cfg.project_root,'products','chapter5','clear_air_stats','clear__ap-final-v1__grid5deg__z60m__clear-v1');
month_out=fullfile(run_root,'staging',['month_' ym],['CHAPTER5_MAP_STATS_V2_' ym '.mat']);
build_chapter5_map_stats_v2_month(year_value,month_value,daily_root,clear_root,inventory,month_out);
fprintf('CHAPTER5_V2_PHASE3_CANDIDATE_PASS month=%s output=%s\n',ym,month_out);
end

function p=find_daily_candidate(day_root,ymd)
hits=dir(fullfile(day_root,'stats_ch5_v2_day_*',['CALIPSO_STATS_CH5_V2_' ymd '.mat']));
hits=hits([hits.bytes]>0);
if isempty(hits),p='';return;end
[~,idx]=max([hits.datenum]);p=fullfile(hits(idx).folder,hits(idx).name);
end
