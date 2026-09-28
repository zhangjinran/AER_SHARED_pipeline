%% manage_runs.m
% 管理历史运行记录：查看 + 删除
clear;
build_log_path = fullfile('output_integrated', 'build_log.mat');
out_dir = fullfile('.', 'output_integrated');

if ~isfile(build_log_path)
    error('build_log.mat not found');
end
load(build_log_path, 'build_log');

fprintf('共 %d 条记录\n\n', length(build_log.runs));

for ri = 1:length(build_log.runs)
    r = build_log.runs{ri};
    if isfield(r, 'date_start') && ~isempty(r.date_start)
        desc = sprintf('%s ~ %s', r.date_start, r.date_end);
    else
        desc = sprintf('%d 个文件', length(r.input_files));
    end
    dc = sum(strcmp({r.steps{1}.status, r.steps{2}.status, ...
                     r.steps{3}.status, r.steps{4}.status}, 'done'));
    fprintf('[%d] %s  (%s, %d/4)  %s\n', ri, r.id, desc, dc, r.timestamp);
end

resp = input('\n输入要删除的编号（可多个，如 1 或 1 2），直接回车退出: ', 's');
if isempty(resp)
    return;
end

ids = sscanf(resp, '%d');
ids = sort(ids, 'descend');  % 从后往前删，索引不变

for idx = ids'
    if idx < 1 || idx > length(build_log.runs)
        fprintf('跳过无效编号: %d\n', idx);
        continue;
    end
    r = build_log.runs{idx};
    resp2 = input(sprintf('  确认删除 %s？[y/N]: ', r.id), 's');
    if isempty(resp2) || lower(resp2(1)) ~= 'y'
        fprintf('  跳过\n');
        continue;
    end
    
    fp = fullfile(out_dir, r.id);
    if isfolder(fp)
        rmdir(fp, 's');
        fprintf('  ✓ 已删除文件夹: %s\n', fp);
    end
    build_log.runs(idx) = [];
    fprintf('  ✓ 已从日志移除\n');
end

save(build_log_path, 'build_log');
fprintf('\n已保存 build_log\n');
