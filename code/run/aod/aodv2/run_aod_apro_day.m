function run_aod_apro_day(date_ymd,run_root,make_plots)
if nargin<3,make_plots=true;end
project_code_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
code_root=fullfile(project_code_root,'utils','aod','aodv2');addpath(genpath(code_root));
addpath(fullfile(project_code_root,'test','aod','aodv2'));
cfg=aod_apro_config(); dt=datetime(date_ymd,'InputFormat','yyyyMMdd');
assert(startsWith(lower(strrep(run_root,'/','\')),lower(fullfile(cfg.project_root,'runs','aod',''))), ...
    'AOD:RunRoot','Run must be inside runs/aod.');
for d={'logs','reports','staging','plots'},if ~isfolder(fullfile(run_root,d{1})),mkdir(fullfile(run_root,d{1}));end,end
try
    test_aod_apro_gate();
    pdir=fullfile(cfg.profile_root,date_ymd(1:4),date_ymd(5:6),date_ymd(7:8));
    gdir=fullfile(cfg.grid_root,date_ymd(1:4),date_ymd(5:6),date_ymd(7:8));
    profile=fullfile(pdir,['AOD_PROFILE_' date_ymd '.mat']); grid=fullfile(gdir,['AOD_GRID_' date_ymd '.mat']);
    input=fullfile(cfg.input_root,date_ymd(1:4),[char(string(dt,'yyyy_MM_dd')) '.mat']);
    if ~isfile(fullfile(pdir,'_SUCCESS'))
        candidate=fullfile(run_root,'staging',['AOD_PROFILE_' date_ymd '.mat']);
        if ~isfile(candidate),build_aod_profile_day(input,date_ymd,candidate);end
        S=load_aod_mat_retry(candidate,'AOD_PROFILE');P=S.AOD_PROFILE;
        assert(strcmp(P.meta.product_key,cfg.profile_key)&&nnz(P.valid_for_grid)>0,'AOD:Gate','Profile candidate contract failed.');
        profile=publish_aod_apro_product(candidate,input,date_ymd,'profile');
    end
    if ~isfile(fullfile(gdir,'_SUCCESS'))
        candidate=fullfile(run_root,'staging',['AOD_GRID_' date_ymd '.mat']);
        if ~isfile(candidate),build_aod_apro_grid_day(profile,date_ymd,candidate);end
        S=load_aod_mat_retry(candidate,'AOD_GRID');G=S.AOD_GRID;
        assert(strcmp(G.meta.product_key,cfg.grid_key)&&sum(G.profile_count,'all')>0,'AOD:Gate','Grid candidate contract failed.');
        grid=publish_aod_apro_product(candidate,profile,date_ymd,'grid');
    end
    S=load_aod_mat_retry(profile,'AOD_PROFILE');P=S.AOD_PROFILE;
    S=load_aod_mat_retry(grid,'AOD_GRID');G=S.AOD_GRID;
    assert(sum(G.profile_count,'all')==nnz(P.valid_for_grid),'AOD:Count','Grid does not count one vote per valid profile.');
    assert(isequaln(G.mean_direct_ext(:,:,[1 2 3 4 6]),G.mean_component_reconstruction(:,:,[1 2 3 4 6])),'AOD:Pure','Pure type grid mismatch.');
    report=fullfile(run_root,'reports','day_gate.txt'); fid=fopen(report,'w');assert(fid>=0,'AOD:Write','Cannot write report.');
    fprintf(fid,'status=PASS\ndate=%s\norbits=%d\nprofiles=%d\nvalid_direct=%d\nvalid_reconstructed=%d\ncommon_grid_profiles=%d\nzero_aerosol_profiles=%d\noccupied_grids=%d\nqc_used=%d\npure_types_identical=true\n', ...
        date_ymd,numel(P.source_files),numel(P.profile_index),nnz(P.valid_direct),nnz(P.valid_reconstructed), ...
        nnz(P.valid_for_grid),P.meta.zero_aerosol_profiles,nnz(G.profile_count),P.meta.qc_used);
    fclose(fid);
    if make_plots,plot_aod_apro_day(grid,fullfile(run_root,'plots'));end
    fprintf('AOD_APRO_RUN_COMPLETE date=%s profiles=%d common=%d\n',date_ymd,numel(P.profile_index),nnz(P.valid_for_grid));
catch ME
    fprintf(2,'AOD_APRO_RUN_FAILED\n%s\n',getReport(ME,'extended','hyperlinks','off'));rethrow(ME);
end
end
