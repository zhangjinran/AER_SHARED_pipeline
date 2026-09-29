function output_path = plot_chapter5_v2_month(monthly_path, output_dir, label)
%PLOT_CHAPTER5_V2_MONTH Render the formal Chapter5_v2 monthly product only.
% No OMCAM, clear-air calculation, or daily-product aggregation occurs here.

if nargin < 3 || isempty(label), label = 'monthly'; end
if ~isfile(monthly_path), error('Chapter5v2:PlotInput','Missing monthly product: %s',monthly_path); end
month_dir = fileparts(monthly_path);
if ~isfile(fullfile(month_dir,'_SUCCESS'))
    error('Chapter5v2:PlotInput','Monthly product lacks _SUCCESS: %s',month_dir);
end
if ~isfolder(output_dir), mkdir(output_dir); end

S = builtin('load',monthly_path,'CHAPTER5_MAP_STATS_V2');
if ~isfield(S,'CHAPTER5_MAP_STATS_V2'), error('Chapter5v2:PlotSchema','Variable CHAPTER5_MAP_STATS_V2 is missing.'); end
C = S.CHAPTER5_MAP_STATS_V2;
required = {'nd_sum','aerosol_count','clear_count','alt_limit_km','processed_dates','missing_dates'};
if ~all(isfield(C,required)), error('Chapter5v2:PlotSchema','Monthly product lacks required fields.'); end

% The legacy Chapter 5 view uses Day data.  Each type is divided by the
% same aerosol-plus-clear-air denominator after monthly pooled summation.
dn = 1;
denom = C.aerosol_count(:,:,dn) + C.clear_count(:,:,dn);
maps = nan(36,72,7);
for t = 1:7
    x = nan(36,72); ok = denom > 0;
    z = C.nd_sum(:,:,dn,t);
    x(ok) = z(ok) ./ denom(ok);
    maps(:,:,t) = x;
end

root = fileparts(fileparts(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))))));
addpath(fullfile(root,'plots','common'),'-begin');
names = { ...
    '(a) Marine: N_{50}', ...
    '(b) Dust: N_{100}', ...
    '(c) Polluted Continental: N_{50}', ...
    '(d) Clean Continental: N_{50}', ...
    '(e) Polluted Dust: N_{100,dust} + N_{50,PC}', ...
    '(f) Elevated Smoke: N_{50}', ...
    '(g) Dusty Marine: N_{100,dust} + N_{50,marine}'};

fig = figure('Visible','off','Color','w','Position',[50 30 1180 1450]);
tiledlayout(4,2,'TileSpacing','compact','Padding','compact');
colormap(turbo(35));
for t = 1:7
    nexttile;
    D = maps(:,:,t); D(D<=0) = NaN;
    draw_global_5deg_robinson(log10(D),[0 4.5],names{t},t>=6);
end
nexttile; axis off;
text(.04,.86,label,'FontSize',16,'FontWeight','bold');
text(.04,.70,sprintf('Day | 5° x 5° | <= %.1f km',C.alt_limit_km),'FontSize',12);
text(.04,.57,sprintf('Pooled days: %d; missing: %d',numel(C.processed_dates),numel(C.missing_dates)),'FontSize',12);
text(.04,.42,'Map = sum(Nd) / (aerosol count + clear-air count)','FontSize',11);
text(.04,.28,'Dust-containing types use N_{100}; other components use N_{50}.','FontSize',11);
text(.04,.14,'Only the formal CHAPTER5_MAP_STATS_V2 product is plotted.','FontSize',11);
cb = colorbar; cb.Layout.Tile = 'east';
cb.Ticks = log10([1 3 10 30 100 300 1000 3000 10000]);
cb.TickLabels = {'1','3','10','30','100','300','1000','3000','10000'};
cb.Label.String = 'Pooled mean number concentration (cm^{-3}; type-specific N threshold)';
sgtitle(sprintf('Chapter 5 v2 Global Aerosol Number Distribution (%s)',label), ...
    'FontSize',18,'FontWeight','bold');

output_path = fullfile(output_dir,'Figure_5_1_Chapter5_v2.png');
exportgraphics(fig,output_path,'Resolution',300);
close(fig);
fprintf('CHAPTER5_V2_PLOT_PASS input=%s output=%s\n',monthly_path,output_path);
end
