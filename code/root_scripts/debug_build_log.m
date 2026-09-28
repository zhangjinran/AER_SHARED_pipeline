%% debug_build_log.m
% 读取并显示 build_log 的全部内容，用于调试
clear;
build_log_path = fullfile('output_integrated', 'build_log.mat');
if ~isfile(build_log_path)
    error('build_log.mat not found at %s', build_log_path);
end
load(build_log_path, 'build_log');

fprintf('build_log version: %s\n', build_log.version);
fprintf('last_run: %s\n', build_log.last_run);
fprintf('共 %d 条记录\n\n', length(build_log.runs));

for ri = 1:length(build_log.runs)
    r = build_log.runs{ri};
    fprintf('=== run %d: %s ===\n', ri, r.id);
    fprintf('  timestamp: %s\n', r.timestamp);
    
    % date_start / date_end
    if isfield(r, 'date_start') && ~isempty(r.date_start)
        fprintf('  date_start: %s  (type: %s)\n', r.date_start, class(r.date_start));
        fprintf('  date_end:   %s  (type: %s)\n', r.date_end, class(r.date_end));
        key = {r.date_start, r.date_end, 'date'};
        fprintf('  identity key: {%s, %s, date}\n', r.date_start, r.date_end);
    else
        fprintf('  date_start: (无)\n');
        if isfield(r, 'input_files')
            fprintf('  input_files: %d 个文件\n', length(r.input_files));
            key = {r.input_files, 'files'};
        else
            fprintf('  input_files: (无)\n');
        end
    end
    
    % 各步骤状态
    for si = 1:4
        s = r.steps{si};
        fprintf('  step%d: status=%s', si, s.status);
        if ~isempty(s.name)
            fprintf('  name=%s', s.name);
        end
        if ~isempty(s.timestamp)
            fprintf('  time=%s', s.timestamp);
        end
        fprintf('\n');
    end
    fprintf('\n');
end

% 显示当前可能的身份键
fprintf('========== 当前配置的身份键 ==========\n');
fprintf('  要调试清理逻辑，请手动修改下面的 date_start/date_end\n');
fprintf('  然后运行 cleanup_build_log 看匹配结果\n');
