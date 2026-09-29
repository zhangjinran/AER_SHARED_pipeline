function run_chapter5_n50_column_day(date_text, run_root)
%RUN_CHAPTER5_N50_COLUMN_DAY One-day Chapter5-v2 number-column test workflow.
% Test outputs are isolated under products/chapter5_n50_column and
% runs/chapter5; existing products, scripts, and figures are never replaced.

if nargin<1 || isempty(date_text), date_text='2007-01-01'; end
if nargin<2 || isempty(run_root)
    error('CH5ColumnRun:RunRoot','Pass a unique run_root under runs/chapter5.');
end
date_value=datetime(date_text,'InputFormat','yyyy-MM-dd');
date_compact=char(string(date_value,'yyyyMMdd'));
code_dir=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
project_root=fileparts(code_dir);
addpath(fullfile(code_dir,'utils','shared','config'),'-begin');
addpath(fullfile(code_dir,'utils','chapter5','chapter5v2','config'),'-begin');
addpath(fullfile(code_dir,'utils','chapter5','chapter5v2','n50_column'),'-begin');
addpath(fullfile(project_root,'plots','common'),'-begin');
roots=data_roots(); cfg=chapter5_v2_config();

stats_path=fullfile(cfg.stats_product_root,datestr(date_value,'yyyy'), ...
    datestr(date_value,'mm'),datestr(date_value,'dd'), ...
    ['CALIPSO_STATS_CH5_V2_' date_compact '.mat']);
ap_day_path=fullfile(roots.CALIPSO_AP_ROOT,datestr(date_value,'yyyy'), ...
    [datestr(date_value,'yyyy_mm_dd') '.mat']);
if ~isfolder(run_root), mkdir(run_root); end
log_dir=fullfile(run_root,'logs','chapter5_n50_column');
plot_dir=fullfile(run_root,'chapter5','plots');
if ~isfolder(log_dir), mkdir(log_dir); end
if ~isfolder(plot_dir), mkdir(plot_dir); end
log_path=fullfile(log_dir,['n50_column_' date_compact '_matlab.log']);
if isfile(log_path), error('CH5ColumnRun:NoOverwrite','Refusing to overwrite run log %s',log_path); end
diary(log_path); diary_cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('CH5_N50_COLUMN_RUN_START date=%s run_root=%s\n',date_text,run_root);
fprintf('INPUT_STATS=%s\nINPUT_GLOBAL_AP=%s\n',stats_path,ap_day_path);
fprintf('TYPE5=original-sample dust N100 + polluted-continental N50; TYPE7=original-sample dust N100 + marine N50\n');

product_key='ch5-number-column__stats-ch5v2__omcam-v2__grid5deg__z0-10km-v1';
product_dir=fullfile(project_root,'products','chapter5','chapter5_n50_column',product_key, ...
    datestr(date_value,'yyyy'),datestr(date_value,'mm'),datestr(date_value,'dd'));
if isfolder(product_dir) || isfile(fullfile(product_dir,'_SUCCESS'))
    error('CH5ColumnRun:NoOverwrite','Product date directory already exists: %s',product_dir);
end
if ~isfile(fullfile(fileparts(stats_path),'_SUCCESS'))
    error('CH5ColumnRun:MissingStatsSuccess','Formal daily Chapter5_v2 stats lacks _SUCCESS.');
end
if ~isfile(stats_path) || ~isfile(ap_day_path)
    error('CH5ColumnRun:MissingInput','Required source product/input is absent.');
end

try
    mat_path=fullfile(product_dir,['N50_COLUMN_CH5_V2_' date_compact '.mat']);
    mkdir(product_dir);
    build_chapter5_type_number_column_day(stats_path,ap_day_path,mat_path);
    check=load(mat_path,'N50_COLUMN_CH5_V2'); X=check.N50_COLUMN_CH5_V2;
    assert(isequal(size(X.column_mean_cm2),[36 72 2 8]));
    assert(all(X.profile_count(:)>=0) && all(X.sample_count(:)>=0));
    assert(X.meta.unmatched_height_rows_below_10km==0, ...
        'Some Chapter5 stats heights did not match canonical AP altitude centers.');
    assert(X.meta.duplicate_profile_height_rows==0);
    plot_path=plot_chapter5_type_number_column_day(mat_path,plot_dir);

    ds=dir(stats_path); da=dir(ap_day_path);
    inv=table(string({'CALIPSO_STATS_CH5_V2';'GLOBAL_AP_DAY_METADATA'}), ...
        string({stats_path;ap_day_path}), ...
        [uint64(ds.bytes);uint64(da.bytes)], ...
        'VariableNames',{'role','path','bytes'});
    if ~isfolder(product_dir), mkdir(product_dir); end
    writetable(inv,fullfile(product_dir,'input_inventory.csv'));
    fid=fopen(fullfile(product_dir,'manifest.txt'),'w');
    if fid<0, error('CH5ColumnRun:Manifest','Cannot write manifest.'); end
    fprintf(fid,'manifest_version=candidate-v1\nproduct_type=CHAPTER5_TYPE_NUMBER_COLUMN\n');
    fprintf(fid,'product_key=%s\nstatus=TEST_CANDIDATE_PASS\ndate=%s\n',product_key,date_text);
    fprintf(fid,'source_stats=%s\nsource_ap_day_metadata=%s\n',stats_path,ap_day_path);
    fprintf(fid,'grid=5deg_by_5deg\naltitude_km=0_to_10\nunits=cm-2\n');
    fprintf(fid,'type5=dust_N100_plus_polluted_continental_N50_within_original_sample\n');
    fprintf(fid,'type7=dust_N100_plus_marine_N50_within_original_sample\n');
    fprintf(fid,'aggregation=profile_column_integral_then_mean_over_aerosol_bearing_profiles\n');
    fclose(fid);
    fid=fopen(fullfile(product_dir,'_SUCCESS'),'w');
    if fid<0, error('CH5ColumnRun:SuccessMarker','Cannot write _SUCCESS.'); end
    fprintf(fid,'status=TEST_CANDIDATE_PASS\ndate=%s\nmat=%s\n',date_text,mat_path); fclose(fid);
    fprintf('CH5_N50_COLUMN_RUN_PASS product=%s plot=%s\n',mat_path,plot_path);
catch ME
    fprintf(2,'CH5_N50_COLUMN_RUN_FAIL id=%s message=%s\n',ME.identifier,ME.message);
    fprintf(2,'%s\n',getReport(ME,'extended','hyperlinks','off'));
    rethrow(ME);
end
end
