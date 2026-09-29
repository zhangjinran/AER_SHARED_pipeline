% Dynamic Chapter 4 monthly runner. CHAPTER4_TALL_ROOT selects direct T_all input.
project = fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))));
run_id = getenv('CHAPTER4_RUN_ID');
if isempty(run_id), error('Chapter4:MissingRunId','CHAPTER4_RUN_ID is required.'); end
run_id = strrep(run_id,'/','\');
if ~startsWith(run_id,'chapter4\')
    if isempty(regexp(run_id,'[\\/]','once'))
        run_id = fullfile('chapter4',run_id);
    else
        error('Chapter4:RunCategory','RunId must be chapter4\run_<id> (or a bare run_<id>).');
    end
end
y = str2double(getenv('CHAPTER4_YEAR'));
m = str2double(getenv('CHAPTER4_MONTH'));
ym = sprintf('%04d%02d',y,m);
if ~isempty(getenv('CHAPTER4_FILE_TAG')),ym=getenv('CHAPTER4_FILE_TAG');end
run_root = fullfile(project,'runs',run_id);
test_root = getenv('CHAPTER4_TEST_PRODUCT_ROOT');
if ~isempty(test_root)
    allowed = fullfile(project,'products','chapter4','test');
    assert(startsWith(lower(strrep(test_root,'/','\')),lower([allowed filesep])), ...
        'Chapter4:TestRoot','Test output must be under products/chapter4/test.');
    assert(~isfolder(test_root),'Chapter4:ExistingTest','Test root already exists.');
    run_root = test_root;
end
out = fullfile(run_root,'intermediate','chapter4');
if ~isfolder(out), mkdir(out); end
stats = fullfile(project,'products','chapter5','calipso_stats_monthly', ...
    'stats-monthly__ap-final-v1__era5-real__adapter-v1__qc-v1', ...
    'monthly',sprintf('%04d',y),sprintf('%02d',m), ...
    ['CALIPSO_STATS_Monthly_' ym '.mat']);
if isempty(getenv('CHAPTER4_TALL_ROOT'))
    assert(isfile(stats) && isfile(fullfile(fileparts(stats),'_SUCCESS')), ...
        'Missing published monthly Stats');
else
    fprintf('CHAPTER4_SOURCE=published_daily_T_all root=%s\n',getenv('CHAPTER4_TALL_ROOT'));
end
setenv('CHAPTER4_CODE_ROOT',fullfile(project,'code','utils','chapter4','current'));
setenv('CHAPTER4_CALIPSO_STATS_FILE',stats);
a = 'F:\AER_RETRA_CASE\areonet data\delivery\full_20070101_20221231_z05kmap_days';
setenv('CHAPTER4_AERONET_FILE',fullfile(a,'AERONET_Data_INVL15_20070101_20221231_Z05kmAP.mat'));
setenv('CHAPTER4_AERONET_SITE_INFO_FILE',fullfile(a,'AERONET_Site_Info_INV15_20070101_20221231_Z05kmAP.mat'));
match = fullfile(out,['AERONET_CALIPSO_Matched_' ym '.mat']);
setenv('CHAPTER4_MATCH_OUTPUT_FILE',match);
setenv('CHAPTER4_MATCH_INPUT_FILE',match);
setenv('CHAPTER4_COLUMN_OUTPUT_FILE',fullfile(out,['AERONET_CALIPSO_Column_Integrated_DB_' ym '.mat']));
setenv('CHAPTER4_COLUMN_INPUT_FILE',getenv('CHAPTER4_COLUMN_OUTPUT_FILE'));
setenv('CHAPTER4_PROJECT_DIR',run_root);
plot_dir = fullfile(run_root,'plots','chapter4');
if ~isfolder(plot_dir), mkdir(plot_dir); end
setenv('CHAPTER4_FIG_DIR',plot_dir);
set(0,'DefaultFigureVisible','off');
addpath(getenv('CHAPTER4_CODE_ROOT'),'-begin');
addpath(fullfile(project,'code','utils','shared','current'),'-begin');
if ~isfile(getenv('CHAPTER4_MATCH_OUTPUT_FILE'))
    run(fullfile(getenv('CHAPTER4_CODE_ROOT'),'ARONET_CALIPSO_Fast_Collocation.m'));
else
    fprintf('CHAPTER4_MATCH_REUSED=%s\n',getenv('CHAPTER4_MATCH_OUTPUT_FILE'));
end
if ~isfile(getenv('CHAPTER4_COLUMN_OUTPUT_FILE'))
    run(fullfile(getenv('CHAPTER4_CODE_ROOT'),'PostProcess_Column_Integration_OneToOne_Weighted_WithTime.m'));
else
    fprintf('CHAPTER4_COLUMN_REUSED=%s\n',getenv('CHAPTER4_COLUMN_OUTPUT_FILE'));
end
assert(isfile(getenv('CHAPTER4_COLUMN_OUTPUT_FILE')),'Chapter4:MissingColumnDB');
setenv('CHAPTER4_PLOT_PARAMETER','1');
run(fullfile(getenv('CHAPTER4_CODE_ROOT'),'画图代码','figure_4_1and4_2.m'));
setenv('CHAPTER4_PLOT_PARAMETER','2');
run(fullfile(getenv('CHAPTER4_CODE_ROOT'),'画图代码','figure_4_1and4_2.m'));
run(fullfile(getenv('CHAPTER4_CODE_ROOT'),'画图代码','figure_4_3.m'));
run(fullfile(getenv('CHAPTER4_CODE_ROOT'),'画图代码','figure_4_4.m'));
run(fullfile(getenv('CHAPTER4_CODE_ROOT'),'画图代码','figure_4_5.m'));
fprintf('CHAPTER4_MONTH_PLOTS_PASS\n');
