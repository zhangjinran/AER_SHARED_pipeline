%RUN_CCN_DAY_BATCH Build and publish one immutable daily CCN_GRID product.
% Invoked by run_ccn_month.ps1.  The producer receives only the formal
% shared T_all product; CALIPSO_STATS and Chapter 4/5 artifacts are not read.
restoredefaultpath;
rehash toolboxcache;

date_text = getenv('CCN_BATCH_DATE');
run_root = getenv('CCN_RUN_ROOT');
if isempty(date_text) || isempty(run_root)
    error('run_ccn_day_batch:MissingEnvironment', ...
        'CCN_BATCH_DATE and CCN_RUN_ROOT are required.');
end
dt = datetime(date_text,'InputFormat','yyyy-MM-dd');
project = 'F:\AER_SHARED_PIPELINE';
addpath(fullfile(project,'code','config'), '-begin');
addpath(fullfile(project,'code','producers','ccn_grid'), '-begin');
addpath(fullfile(project,'code','publishers'), '-begin');

cfg = data_roots();
key = 'ccn__ap-final-v1__era5-real__grid5deg__ccn-v1';
ymd = datestr(dt,'yyyymmdd');
final_dir = fullfile(cfg.CCN_GRID_ROOT,key,datestr(dt,'yyyy'), ...
    datestr(dt,'mm'),datestr(dt,'dd'));
if isfile(fullfile(final_dir,'_SUCCESS'))
    fprintf('CCN_DAY_SKIP_EXISTING %s\n', date_text);
    return
end

tall = fullfile(cfg.SHARED_TALL_ROOT, ...
    'tall__ap-final-v1__era5-real__adapter-v1__qc-v1', ...
    datestr(dt,'yyyy'),datestr(dt,'mm'),datestr(dt,'dd'), ...
    sprintf('T_all_%s.mat',ymd));
if ~isfile(tall)
    error('run_ccn_day_batch:MissingTAll','Missing formal T_all: %s',tall);
end

candidate_dir = fullfile(run_root,'staging','ccn',ymd);
if ~isfolder(candidate_dir), mkdir(candidate_dir); end
candidate = fullfile(candidate_dir,sprintf('CCN_GRID_%s.mat',ymd));
if isfile(candidate), delete(candidate); end
fprintf('CCN_DAY_START %s\nTALL=%s\nCANDIDATE=%s\n',date_text,tall,candidate);
build_ccn_grid_from_shared_tall(tall,candidate);
S = load(candidate,'M','cnt','total','valid_total','meta');
if ~isequal(size(S.M),[36 72 3]) || ~isequal(size(S.cnt),[36 72]) || ...
        ~isscalar(S.total) || ~isscalar(S.valid_total) || S.valid_total < 0
    error('run_ccn_day_batch:CandidateGate','Candidate CCN_GRID schema gate failed.');
end
fprintf('CCN_DAY_GATE_PASS total=%d valid_total=%d occupied=%d\n', ...
    S.total,S.valid_total,nnz(S.cnt));
published = publish_ccn_grid_day(date_text,candidate);
fprintf('CCN_DAY_PUBLISHED %s\n',published);
