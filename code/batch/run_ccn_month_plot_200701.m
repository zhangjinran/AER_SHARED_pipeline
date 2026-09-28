% Plot published daily CCN_GRID products for January 2007.
restoredefaultpath; rehash toolboxcache;
project='F:\AER_SHARED_PIPELINE';
addpath(fullfile(project,'code','config'),'-begin');
addpath(fullfile(project,'code','consumers','ccn'),'-begin');
cfg=data_roots();
key='ccn__ap-final-v1__era5-real__grid5deg__ccn-v1';
outdir=fullfile(project,'runs','run_200701_month_001','plots','ccn');
if ~isfolder(outdir), mkdir(outdir); end
for day=1:31
    dt=datetime(2007,1,day); ymd=datestr(dt,'yyyymmdd');
    grid=fullfile(cfg.CCN_GRID_ROOT,key,'2007','01',datestr(dt,'dd'),sprintf('CCN_GRID_%s.mat',ymd));
    if ~isfile(grid)
        fprintf('CCN_PLOT_SKIP_MISSING %s\n',ymd); continue
    end
    plot_ccn_grid_consumer(grid,outdir,datestr(dt,'yyyy-mm-dd'));
end
fprintf('CCN_MONTH_PLOTS_PASS output=%s\n',outdir);
