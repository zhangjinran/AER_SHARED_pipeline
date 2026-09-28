function outputs=plot_aod_grid_day(daily_path,output_dir)
%PLOT_AOD_GRID_DAY Render the two daily grouped AOD maps with Chapter 5 style.
cfg=aod_config();
if ~isfile(daily_path) || ~isfile(fullfile(fileparts(daily_path),'_SUCCESS'))
    error('AOD:PlotInput','Daily AOD product is missing or not gated.');
end
if ~isfolder(output_dir),mkdir(output_dir);end
addpath(fullfile(cfg.project_root,'plots','common'),'-begin');
addpath(fullfile(cfg.code_root,'utils'),'-begin');
S=load_aod_mat_retry(daily_path,'AOD_GRID'); M=S.AOD_GRID;
date_ymd=char(M.meta.date);
if numel(date_ymd)~=8 || any(~isstrprop(date_ymd,'digit'))
    error('AOD:PlotContract','Daily product date metadata is malformed.');
end
methods={'mean_direct_ext','mean_component_reconstruction'};
labels={'Direct APro extinction integral','Chapter5/CCN-v2 component reconstruction'};
files={'AOD_Direct_Extinction','AOD_Chapter5_CCN_Components'};
names={'Marine','Dust','Polluted Continental','Clean Continental', ...
    'Polluted Dust: dust + PC','Elevated Smoke', ...
    'Dusty Marine: dust + marine','Total'};
lon=-177.5:5:177.5; lat=-87.5:5:87.5; outputs=cell(2,1);
for m=1:2
    Z=double(M.(methods{m}));
    if ~isequal(size(Z),[36 72 8])
        error('AOD:PlotContract','Expected a 36x72x8 daily grid for %s.',methods{m});
    end
    positive=Z(isfinite(Z)&Z>0);
    if isempty(positive),error('AOD:NoPositiveGrid','No positive AOD values in %s.',methods{m});end
    logv=log10(positive); lim=[floor(min(logv)*10)/10,ceil(max(logv)*10)/10];
    if lim(1)==lim(2),lim=lim+[-0.5 0.5];end
    fig=figure('Visible','off','Color','w','Position',[30 30 1500 1320]);
    tl=tiledlayout(fig,4,2,'TileSpacing','compact','Padding','compact');
    cmap=turbo(35); colormap(fig,cmap);
    for c=1:8
        ax=nexttile(tl); D=Z(:,:,c); D(D<=0)=NaN;
        draw_global_robinson(log10(D),lat,lon,lim,names{c},c>=6,'smooth_surface');
        set(ax,'Color',cmap(1,:));
    end
    cb=colorbar; cb.Layout.Tile='east'; cb.Label.String='log_{10}(AOD)';
    sgtitle(sprintf('%s | %s | profiles=%d',labels{m},date_ymd, ...
        sum(double(M.count_direct_ext(:,:,8)),'all')),'FontSize',17,'FontWeight','bold');
    outputs{m}=fullfile(output_dir,[files{m} '_' date_ymd '.png']);
    if isfile(outputs{m}),close(fig);error('AOD:PlotNoOverwrite','Refusing to overwrite %s',outputs{m});end
    exportgraphics(fig,outputs{m},'Resolution',300);close(fig);
    fprintf('AOD_DAY_PLOT_PASS method=%s file=%s render=smooth_surface caxis=[%.2f %.2f]\n', ...
        methods{m},outputs{m},lim(1),lim(2));
end
end
