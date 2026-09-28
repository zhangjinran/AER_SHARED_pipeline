function [pool, dates_used] = load_chapter4_tall_month_pool(tall_root, year_value, month_value)
%LOAD_CHAPTER4_TALL_MONTH_POOL Read published daily T_all directly for Chapter 4.
% Columns: Lat Lon UTC Ext Back Depol RH Type lat_grid lon_grid.
% No monthly CALIPSO_STATS copy is created.

    required = {'Lat','Lon','UTC','Ext','Back','Depol','RH','Type','DayNight'};
    day_count = eomday(year_value, month_value);
    day_parts = cell(day_count,1);
    dates_used = strings(0,1);
    for day_value = 1:day_count
        ymd = sprintf('%04d%02d%02d',year_value,month_value,day_value);
        selected_dates=strsplit(getenv('CHAPTER4_TALL_DATES'),',');
        if ~isempty(getenv('CHAPTER4_TALL_DATES')) && ~any(strcmp(selected_dates,ymd)),continue;end
        day_dir = fullfile(tall_root,sprintf('%04d',year_value), ...
            sprintf('%02d',month_value),sprintf('%02d',day_value));
        mat_path = fullfile(day_dir,['T_all_' ymd '.mat']);
        if ~isfile(mat_path) && ~isfile(fullfile(day_dir,'_SUCCESS'))
            fprintf('CHAPTER4_TALL_MISSING %s\n',ymd);
            continue
        end
        if ~isfile(mat_path) || ~isfile(fullfile(day_dir,'_SUCCESS'))
            error('Chapter4:IncompleteTAll','Incomplete published T_all for %s.',ymd);
        end
        S = load_with_nas_retry(mat_path,'T_all');
        T = S.T_all;
        if ~istable(T) || ~all(ismember(required,T.Properties.VariableNames))
            error('Chapter4:TAllSchema','Missing required T_all fields in %s.',mat_path);
        end
        utc = T.UTC;
        if isdatetime(utc), utc = datenum(utc); end
        lat = double(T.Lat); lon = double(T.Lon);
        li = floor((lat+90)/5)+1; lj = floor((lon+180)/5)+1;
        type = double(T.Type);
        daynight = string(T.DayNight);
        keep = li>=1 & li<=36 & lj>=1 & lj<=72 & ...
            type>=1 & type<=7 & type==floor(type) & ...
            (daynight=="Day" | daynight=="Night") & ...
            year(datetime(utc,'ConvertFrom','datenum'))==year_value & ...
            month(datetime(utc,'ConvertFrom','datenum'))==month_value;
        rh = double(T.RH);
        rh(rh<1)=1; rh(rh>100)=100;
        day_parts{day_value} = [lat(keep),lon(keep),double(utc(keep)), ...
            double(T.Ext(keep)),double(T.Back(keep)),double(T.Depol(keep)), ...
            rh(keep),type(keep),li(keep),lj(keep)];
        dates_used(end+1,1) = string(ymd); %#ok<AGROW>
        fprintf('CHAPTER4_TALL_LOADED %s rows=%d\n',ymd,nnz(keep));
        clear S T
    end
    if isempty(dates_used)
        error('Chapter4:NoTAll','No published T_all days found for %04d-%02d.',year_value,month_value);
    end
    pool = vertcat(day_parts{:});
    fprintf('CHAPTER4_TALL_MONTH_READY days=%d rows=%d\n',numel(dates_used),size(pool,1));
end
