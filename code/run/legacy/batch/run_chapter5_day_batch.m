% Clean, non-interactive daily entry point for the monthly PowerShell loop.
restoredefaultpath;
rehash toolboxcache;
addpath('F:\AER_SHARED_PIPELINE\code\producers\chapter5', '-begin');
date_text = getenv('CHAPTER5_BATCH_DATE');
if isempty(date_text)
    error('run_chapter5_day_batch:MissingDate', ...
        'Environment variable CHAPTER5_BATCH_DATE is required.');
end
status = build_chapter5_day_products(date_text);
disp(status);
