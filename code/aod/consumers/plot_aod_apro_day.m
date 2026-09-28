function outputs=plot_aod_apro_day(product_path,output_dir,replace_current_run)
if nargin<3,replace_current_run=false;end
cfg=aod_apro_config(); assert(isfile(fullfile(fileparts(product_path),'_SUCCESS')),'AOD:Input','Formal grid required.');
S=load_aod_mat_retry(product_path,'AOD_GRID'); G=S.AOD_GRID;
assert(any(strcmp(G.meta.product_key,{cfg.grid_key,cfg.month_key})),'AOD:Input','Expected profile-first grid v2.');
addpath(fullfile(cfg.project_root,'plots','common'));
if ~isfolder(output_dir),mkdir(output_dir);end
fields={'mean_direct_ext','mean_component_reconstruction'};
prefix={'AOD_Direct','AOD_Type57_Reconstructed'};
titles={'APro direct extinction','APro with Type 5/7 component reconstruction'};
V=[G.mean_direct_ext(:);G.mean_component_reconstruction(:)]; V=V(isfinite(V)&V>0);
if isempty(V),lim=[-4 0];else,lim=[floor(min(log10(V))) ceil(max(log10(V)))];end
if lim(1)==lim(2),lim=lim+[-1 1];end
outputs=cell(2,1);
for m=1:2
    outputs{m}=fullfile(output_dir,[prefix{m} '_' G.meta.date '.png']);
    assert(replace_current_run||~isfile(outputs{m}),'AOD:Overwrite','Plot already exists.');
    fig=figure('Visible','off','Color','w','Position',[30 30 1600 1380]);
    cleanup=onCleanup(@()close(fig));
    tl=tiledlayout(fig,4,2,'Padding','loose','TileSpacing','compact'); colormap(fig,turbo(128));
    for t=1:8
        nexttile(tl); D=G.(fields{m})(:,:,t); Z=nan(size(D));
        q=isfinite(D); Z(q)=log10(max(D(q),10^lim(1)));
        ax=draw_global_robinson(Z,-87.5:5:87.5,-177.5:5:177.5,lim,cfg.channels{t},t>=7,'smooth_surface');
        % Calling setm after draw_global_robinson resets this axes' content
        % under the current Mapping Toolbox. Set only ordinary axes color.
        set(ax,'Color','w');
        assert(~isempty(findobj(ax,'Type','surface')),'AOD:Render','Missing map surface.');
        assert(max(abs(clim(ax)-lim))<1e-10,'AOD:Render','Map color limits were reset.');
    end
    cb=colorbar;cb.Layout.Tile='east'; cb.Label.String='AOD (log scale)';
    cb.Ticks=lim(1):lim(2);cb.TickLabels=compose('%.0e',10.^cb.Ticks);
    sgtitle(tl,sprintf('%s | %s | %d valid profiles',titles{m},G.meta.date,sum(G.profile_count,'all')),'FontSize',16);
    exportgraphics(fig,outputs{m},'Resolution',220);clear cleanup;
    fprintf('AOD_PLOT_PASS %s missing=white zero=lower_color render=smooth_surface\n',outputs{m});
end
end
