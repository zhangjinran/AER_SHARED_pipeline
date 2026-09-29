function build_log = cleanup_build_log(build_log, out_dir, date_start, date_end, current_files)
% 清理 build_log 中重复的历史运行记录
%
% 匹配规则：
%   日期模式 → 比较 date_start + date_end
%   原始模式 → 比较 input_files 文件列表
%
% 保留规则：
%   同组重复中，完成步数多的优先
%   步数相同则保留最新的
%   删除前逐一询问确认

    n_runs = length(build_log.runs);
    if n_runs <= 1
        return;
    end

    % === 计算当前的身份键 ===
    current_key = {};
    if ~isempty(date_start)
        if isdatetime(date_start)
            ds = datestr(date_start, 'yyyy-mm-dd');
        else
            ds = char(date_start);
        end
        if isempty(date_end)
            de = ds;
        elseif isdatetime(date_end)
            de = datestr(date_end, 'yyyy-mm-dd');
        else
            de = char(date_end);
        end
        current_key = {ds, de, 'date'};
    else
        current_key = {current_files, 'files'};
    end

    % === 对每个历史 run 生成身份键 ===
    run_keys = cell(n_runs, 1);
    for ri = 1:n_runs
        r = build_log.runs{ri};
        if isfield(r, 'date_start') && ~isempty(r.date_start)
            run_keys{ri} = {r.date_start, r.date_end, 'date'};
        else
            run_keys{ri} = {r.input_files, 'files'};
        end
    end

    % === 找出和当前配置相同键的历史 run（排除最后一个，那是当前 run）===
    matching = false(n_runs, 1);
    for ri = 1:n_runs-1
        if isequal(run_keys{ri}, current_key)
            matching(ri) = true;
        end
    end

    if ~any(matching)
        return;
    end

    % === 收集匹配的 run，按完成步数降序 + 时间降序排序 ===
    match_idx = find(matching);
    info = [];
    for mi = 1:length(match_idx)
        ri = match_idx(mi);
        r = build_log.runs{ri};
        dc = sum(strcmp({r.steps{1}.status, r.steps{2}.status, ...
                         r.steps{3}.status, r.steps{4}.status}, 'done'));
        info = [info; ri, dc, datenum(r.timestamp)]; %#ok<AGROW>
    end
    info = sortrows(info, [-2, -3]);  % 步数降序→时间降序

    % === 保留最好的第一个，删除其余的 ===
    to_del = info(2:end, 1);
    for di = 1:length(to_del)
        ri = to_del(di);
        r = build_log.runs{ri};
        dc = sum(strcmp({r.steps{1}.status, r.steps{2}.status, ...
                         r.steps{3}.status, r.steps{4}.status}, 'done'));

        if isfield(r, 'date_start') && ~isempty(r.date_start)
            desc = sprintf('%s ~ %s', r.date_start, r.date_end);
        else
            desc = sprintf('%d 个文件', length(r.input_files));
        end

        resp = input(sprintf('  发现重复: %s (%s, %d/4步骤), 删除此记录？[y/N]: ', ...
            r.id, desc, dc), 's');
        if ~isempty(resp) && lower(resp(1)) == 'y'
            fp = fullfile(out_dir, r.id);
            if isfolder(fp)
                rmdir(fp, 's');
                fprintf('    ✓ 已删除文件夹: %s\n', fp);
            end
            build_log.runs(ri) = [];
            fprintf('    ✓ 已从日志移除: %s\n', r.id);
        end
    end
end
