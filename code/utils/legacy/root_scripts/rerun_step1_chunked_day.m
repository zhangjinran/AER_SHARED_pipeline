% Process one CALIPSO day one orbit at a time to avoid batch HDF crashes.
root = 'F:\AER_RETRA_CASE'; outroot = fullfile(root,'CCN_FULL_RERUN_20260821','step1_20220601_chunked');
if ~isfolder(outroot), mkdir(outroot); end
date_str = '2022-06-01';
for k = 1:29
    od = fullfile(outroot,sprintf('orbit_%03d',k));
    if ~isfolder(od), mkdir(od); end
    try
        build_calipso_step1_day(date_str,'hdf','HdfRoot','Z:\\05kmAP', ...
            'ERA5Dir',fullfile(root,'ERA5_CACHE'),'OutputDir',od, ...
            'StartFile',k,'MaxFiles',1);
        fprintf('DONE %d/29\n',k);
    catch ME
        fprintf(2,'FAIL %d/29: %s\n',k,ME.message);
    end
end
