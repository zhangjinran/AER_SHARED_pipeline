function result = run_build_omcam_v2_priors_logged(run_root)
%RUN_BUILD_OMCAM_V2_PRIORS_LOGGED Run the frozen prior build with a recoverable diary.
if nargin<1||isempty(run_root),error('CCNv2:MissingRunRoot','Run root is required.');end
logdir=fullfile(char(run_root),'logs'); if ~isfolder(logdir),mkdir(logdir);end
logpath=fullfile(logdir,'build_omcam_v2_priors_resume_matlab.log');
diary(logpath); cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('CCN_V2_PRIOR_BUILD_START %s\n',datestr(now,31));
try
    result=run_build_omcam_v2_priors(run_root);
    disp(result); fprintf('CCN_V2_PRIOR_BUILD_PASS %s\n',datestr(now,31));
catch ME
    fprintf(2,'CCN_V2_PRIOR_BUILD_FAIL %s\n%s\n',datestr(now,31),getReport(ME,'extended','hyperlinks','off'));
    rethrow(ME);
end
end
