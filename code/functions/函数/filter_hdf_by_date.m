function files = filter_hdf_by_date(data_root, date_start, date_end)
% 按日期范围筛选 CALIPSO HDF 文件，返回值与 dir() 格式兼容
%
% 输入:
%   data_root  - 数据根目录，如 'Z:\05kmAP' 或 'F:\...\APro'
%   date_start - 起始日期，如 '2007-01-01' 或 datetime；为空时退化到 dir(data_root)
%   date_end   - 结束日期，同上；为空时只筛单日
%
% 输出:
%   files      - 结构体数组，每个元素含 .name / .folder / .bytes / .datenum
%                （和 dir() 格式完全一致）

    % ===== 1. 无日期参数 → 退化到原始 dir() 行为 =====
    if nargin < 2 || isempty(date_start)
        ptn = fullfile(data_root, '*.hdf');
        files = dir(ptn);
        if isempty(files)
            files = dir(fullfile(data_root, 'CAL_LID_L2_05kmAPro*'));
        end
        for i = 1:length(files)
            files(i).folder = data_root;
        end
        fprintf('  filter_hdf_by_date: 从 %s 找到 %d 个文件 (原始模式)\n', ...
            data_root, length(files));
        return;
    end

    % ===== 2. 统一日期格式 =====
    if ischar(date_start) || isstring(date_start)
        date_start = datetime(date_start, 'InputFormat', 'yyyy-MM-dd');
    end
    if nargin < 3 || isempty(date_end)
        date_end = date_start;
    elseif ischar(date_end) || isstring(date_end)
        date_end = datetime(date_end, 'InputFormat', 'yyyy-MM-dd');
    end
    yr_start = year(date_start); yr_end = year(date_end);

    all_files = struct('name',{},'folder',{},'date',{},'bytes',{},'isdir',{},'datenum',{});

    % ===== 3. 检测数据结构：树形 or 扁平 =====
    yr_dirs = dir(fullfile(data_root, '*'));
    yr_dirs = yr_dirs([yr_dirs.isdir] & ~ismember({yr_dirs.name}, {'.', '..'}));
    yr_nums = str2double({yr_dirs.name});
    has_year_dirs = any(~isnan(yr_nums) & yr_nums >= 2006 & yr_nums <= 2030);

    % ===== 4A. 树形结构：Z:\05kmAP\2022\2022_06_01\*.hdf =====
    if has_year_dirs
        for yi = 1:length(yr_dirs)
            yr = yr_nums(yi);
            if isnan(yr) || yr < yr_start || yr > yr_end
                continue;
            end

            day_dirs = dir(fullfile(yr_dirs(yi).folder, yr_dirs(yi).name, '*'));
            day_dirs = day_dirs([day_dirs.isdir] & ~ismember({day_dirs.name}, {'.', '..'}));

            for di = 1:length(day_dirs)
                try
                    folder_date = datetime(day_dirs(di).name, 'InputFormat', 'yyyy_MM_dd');
                catch
                    continue;
                end
                if folder_date < date_start || folder_date > date_end
                    continue;
                end

                day_path = fullfile(day_dirs(di).folder, day_dirs(di).name);
                day_files = dir(fullfile(day_path, '*.hdf'));
                for fi = 1:length(day_files)
                    day_files(fi).folder = day_path;
                end
                all_files = [all_files; day_files]; %#ok<AGROW>
            end
        end

    % ===== 4B. 扁平结构：F:\...\APro\CAL_LID_L2_05kmAPro-*.hdf =====
    else
        raw = dir(fullfile(data_root, '*.hdf'));
        yr_start_dn = datenum(date_start);
        yr_end_dn   = datenum(date_end);

        for i = 1:length(raw)
            fname = raw(i).name;
            % 从文件名中提取日期: ...2022-01-01T...
            toks = regexp(fname, '(\d{4})-(\d{2})-(\d{2})T', 'tokens');
            if isempty(toks)
                continue;
            end
            file_dn = datenum(str2double(toks{1}{1}), str2double(toks{1}{2}), str2double(toks{1}{3}));
            if file_dn >= yr_start_dn && file_dn <= yr_end_dn
                raw(i).folder = data_root;
                all_files(end+1, 1) = raw(i); %#ok<AGROW>
            end
        end
    end

    files = all_files;
    if has_year_dirs
        mode_str = '树形';
    else
        mode_str = '扁平';
    end
    fprintf('  filter_hdf_by_date: 从 %s 找到 %d 个文件 [%s模式] (%s ~ %s)\n', ...
        data_root, length(files), mode_str, datestr(date_start, 'yyyy-mm-dd'), ...
        datestr(date_end, 'yyyy-mm-dd'));
end
