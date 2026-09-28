function S = load_with_nas_retry(mat_path, varargin)
%LOAD_WITH_NAS_RETRY Load selected MAT variables with bounded NAS retries.
%   All attempts and their outcomes are written to the active MATLAB log.

    max_attempts = 5;
    last_error = [];
    for attempt = 1:max_attempts
        try
            S = builtin('load', mat_path, varargin{:});
            if attempt > 1
                fprintf('MAT_LOAD_PASS attempt=%d/%d file=%s\n', ...
                    attempt, max_attempts, mat_path);
            end
            return
        catch ME
            last_error = ME;
            if attempt < max_attempts
                fprintf(2, 'MAT_LOAD_RETRY attempt=%d/%d file=%s error=%s\n', ...
                    attempt, max_attempts, mat_path, ME.message);
                pause(2 * attempt);
            end
        end
    end
    fprintf(2, 'MAT_LOAD_FAILED attempts=%d file=%s\n', max_attempts, mat_path);
    rethrow(last_error);
end
