function S=load_aod_mat_retry(mat_path,varargin)
%LOAD_AOD_MAT_RETRY Bounded read retry without adding legacy function paths.
max_attempts=5; last_error=[];
for attempt=1:max_attempts
    try
        S=builtin('load',mat_path,varargin{:});
        if attempt>1,fprintf('AOD_MAT_LOAD_PASS attempt=%d/%d file=%s\n',attempt,max_attempts,mat_path);end
        return
    catch ME
        last_error=ME;
        if attempt<max_attempts
            fprintf(2,'AOD_MAT_LOAD_RETRY attempt=%d/%d file=%s error=%s\n',attempt,max_attempts,mat_path,ME.message);
            pause(2*attempt);
        end
    end
end
fprintf(2,'AOD_MAT_LOAD_FAILED attempts=%d file=%s\n',max_attempts,mat_path);
rethrow(last_error);
end
