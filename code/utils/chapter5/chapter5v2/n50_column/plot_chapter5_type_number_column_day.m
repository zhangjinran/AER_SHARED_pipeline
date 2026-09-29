function output_path = plot_chapter5_type_number_column_day(product_path, output_dir, output_name, render_method)
%PLOT_CHAPTER5_TYPE_NUMBER_COLUMN_DAY Render with the Chapter 5 Robinson renderer.
if nargin<3 || isempty(output_name), output_name='Figure_N50_Column_20070101.png'; end
if nargin<4 || isempty(render_method), render_method='smooth_surface'; end
if ~isfile(product_path), error('CH5ColumnPlot:MissingProduct','Missing %s',product_path); end
if ~isfolder(output_dir), mkdir(output_dir); end
output_path=fullfile(output_dir,output_name);
if isfile(output_path), error('CH5ColumnPlot:NoOverwrite','Refusing to overwrite %s',output_path); end
S=load(product_path,'N50_COLUMN_CH5_V2');
if ~isfield(S,'N50_COLUMN_CH5_V2'), error('CH5ColumnPlot:Schema','Expected product variable is missing.'); end
C=S.N50_COLUMN_CH5_V2;
if ~isequal(size(C.column_mean_cm2),[36 72 2 8])
    error('CH5ColumnPlot:Grid','Expected [36 72 2 8] 5-degree fields.');
end
maps=squeeze(C.column_mean_cm2(:,:,1,:));
v=log10(maps(isfinite(maps)&maps>0));
if isempty(v), error('CH5ColumnPlot:NoPositiveData','No positive Day column values to draw.'); end
v=sort(v(:)); qlo=v(max(1,ceil(.02*numel(v)))); qhi=v(max(1,ceil(.98*numel(v))));
clim=[floor(qlo),ceil(qhi)];
if clim(1)>=clim(2), clim(2)=clim(1)+1; end
if clim(1)<0, clim(1)=0; end

labels={'(a) Marine','(b) Dust','(c) Polluted Cont.','(d) Clean Cont.', ...
    '(e) Polluted Dust','(f) Elevated Smoke','(g) Dusty Marine','(h) Total'};
project_root=fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
common_dir=fullfile(project_root,'plots','common');
addpath(common_dir,'-begin');
fig=figure('Visible','off','Color','w','Position',[50 30 1100 1450]);
tiledlayout(4,2,'TileSpacing','compact','Padding','compact'); colormap(turbo(35));
for k=1:8
    nexttile; D=maps(:,:,k); D(D<=0)=NaN;
    draw_global_robinson(log10(D),-87.5:5:87.5,-177.5:5:177.5, ...
        clim,labels{k},k>=7,render_method);
end
cb=colorbar; cb.Layout.Tile='east'; ticks=clim(1):clim(2);
cb.Ticks=ticks; cb.TickLabels=arrayfun(@(x)sprintf('10^{%d}',x),ticks,'UniformOutput',false);
cb.Label.String='Mean Chapter 5 aerosol-number column (cm^{-2})';
if isfield(C.meta,'period_label'), label=C.meta.period_label; else, label=C.meta.date; end
sgtitle(sprintf('Chapter 5 type-specific aerosol-number column, 0–10 km (%s)',label), ...
    'FontSize',17,'FontWeight','bold');
exportgraphics(fig,output_path,'Resolution',300); close(fig);
fprintf('CH5_COLUMN_PLOT_PASS renderer=%s output=%s log10_limits=[%g,%g]\n', ...
    render_method,output_path,clim(1),clim(2));
end
