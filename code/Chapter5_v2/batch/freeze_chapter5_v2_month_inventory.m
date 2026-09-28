function inventory_path = freeze_chapter5_v2_month_inventory(year_value,month_value,run_root)
%FREEZE_CHAPTER5_V2_MONTH_INVENTORY Freeze formal T_all/clear-air coverage once.
% This is an administrative preflight only: it never creates scientific data.

cfg = chapter5_v2_config();
if ~isfolder(run_root), mkdir(run_root); end
ym = sprintf('%04d%02d',year_value,month_value);
inventory_path = fullfile(run_root,['date_inventory_' ym '_frozen.csv']);
if isfile(inventory_path)
    error('Chapter5v2:FrozenInventory','Frozen inventory already exists: %s',inventory_path);
end

first_day = datetime(year_value,month_value,1);
days = first_day:dateshift(first_day,'end','month');
n = numel(days);
date = strings(n,1); status = strings(n,1); reason = strings(n,1);
tall_path = strings(n,1); clear_path = strings(n,1);
for q = 1:n
    d = days(q); ymd = char(string(d,'yyyyMMdd'));
    yy = char(string(d,'yyyy')); mm = char(string(d,'MM')); dd = char(string(d,'dd'));
    date(q) = string(d,'yyyy-MM-dd');
    tall_dir = fullfile(cfg.project_root,'products','tall','t_all', ...
        'tall__ap-final-v1__era5-real__adapter-v1__qc-v1',yy,mm,dd);
    clear_dir = fullfile(cfg.project_root,'products','chapter5','clear_air_stats', ...
        'clear__ap-final-v1__grid5deg__z60m__clear-v1',yy,mm,dd);
    tall_path(q) = string(fullfile(tall_dir,['T_all_' ymd '.mat']));
    clear_path(q) = string(fullfile(clear_dir,['CLEAR_AIR_STATS_' ymd '.mat']));
    has_tall = isfile(fullfile(tall_dir,'_SUCCESS')) && isfile(tall_path(q));
    has_clear = isfile(fullfile(clear_dir,'_SUCCESS')) && isfile(clear_path(q));
    if has_tall && has_clear
        status(q) = "READY"; reason(q) = "formal_tall_and_clear_present";
    elseif ~has_tall && ~has_clear
        status(q) = "MISSING_TALL_AND_CLEAR"; reason(q) = "formal_tall_and_clear_absent";
    elseif ~has_tall
        status(q) = "MISSING_TALL"; reason(q) = "formal_tall_absent";
    else
        status(q) = "MISSING_CLEAR"; reason(q) = "formal_clear_absent";
    end
end
T = table(date,status,reason,tall_path,clear_path);
writetable(T,inventory_path);
fprintf('CHAPTER5_V2_INVENTORY_FROZEN month=%s ready=%d missing=%d path=%s\n', ...
    ym,nnz(status=="READY"),nnz(status~="READY"),inventory_path);
end
