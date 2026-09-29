function output_path=plot_chapter5v2_day_gate_20070101(stats_path,clear_path,output_dir)
% One-day view of the same Chapter5_v2 pooled numerator/denominator rule.
assert(isfile(stats_path)&&isfile(clear_path),'LayoutPlot:Input','Missing current-attempt candidate.');
if ~isfolder(output_dir),mkdir(output_dir);end
project_root='F:\AER_SHARED_PIPELINE';
addpath(fullfile(project_root,'code','utils','chapter5','chapter5v2','config'),'-begin');
addpath(fullfile(project_root,'plots','common'),'-begin');
cfg=chapter5_v2_config();
A=builtin('load',stats_path,'CALIPSO_STATS_CH5_V2');
B=builtin('load',clear_path,'CLEAR_STATS');
G=A.CALIPSO_STATS_CH5_V2.grid;
H=B.CLEAR_STATS.grid;
clear_centers=(0.03:0.06:14.97)';clear_mask=clear_centers<=cfg.grid.altitude_limit_km;
nd_sum=zeros(36,72,7);aerosol_count=zeros(36,72);clear_count=zeros(36,72);
for i=1:36
 for j=1:72
  if isfield(H(i,j),'Day') && isstruct(H(i,j).Day) && isfield(H(i,j).Day,'Jan')
   vp=H(i,j).Day.Jan.count_vert_prof;
   clear_count(i,j)=sum(vp(clear_mask));
  end
  if ~isfield(G(i,j),'Day') || ~isstruct(G(i,j).Day) || ~isfield(G(i,j).Day,'Jan'),continue;end
  block=G(i,j).Day.Jan;
  for t=1:7
   tf=sprintf('Type%d',t);
   if ~isfield(block,tf),continue;end
   tab=block.(tf).data;
   ok=isfinite(tab.Nd_dry_OMCAM_v2) & tab.Nd_dry_OMCAM_v2>=0 & tab.Height<=cfg.grid.altitude_limit_km;
   nd_sum(i,j,t)=nd_sum(i,j,t)+sum(tab.Nd_dry_OMCAM_v2(ok));
   aerosol_count(i,j)=aerosol_count(i,j)+nnz(ok);
  end
 end
end
denom=aerosol_count+clear_count;
names={'(a) Marine: N_{50}','(b) Dust: N_{100}', ...
 '(c) Polluted Continental: N_{50}','(d) Clean Continental: N_{50}', ...
 '(e) Polluted Dust: N_{100,dust} + N_{50,PC}', ...
 '(f) Elevated Smoke: N_{50}', ...
 '(g) Dusty Marine: N_{100,dust} + N_{50,marine}'};
fig=figure('Visible','off','Color','w','Position',[50 30 1180 1450]);
tiledlayout(4,2,'TileSpacing','compact','Padding','compact');colormap(turbo(35));
for t=1:7
 nexttile;D=nan(36,72);ok=denom>0;Z=nd_sum(:,:,t);D(ok)=Z(ok)./denom(ok);D(D<=0)=NaN;
 draw_global_5deg_robinson(log10(D),[0 4.5],names{t},t>=6);
end
nexttile;axis off;
text(.04,.86,'2007-01-01 | one-day test candidate','FontSize',16,'FontWeight','bold');
text(.04,.70,sprintf('Day | 5° x 5° | <= %.1f km',cfg.grid.altitude_limit_km),'FontSize',12);
text(.04,.55,'Map = sum(Nd) / (aerosol count + clear-air count)','FontSize',11);
text(.04,.40,'Dust-containing types use N_{100}; other components use N_{50}.','FontSize',11);
text(.04,.25,'Input: current Gate daily Stats and Clear-Air candidates.','FontSize',11);
cb=colorbar;cb.Layout.Tile='east';
cb.Ticks=log10([1 3 10 30 100 300 1000 3000 10000]);
cb.TickLabels={'1','3','10','30','100','300','1000','3000','10000'};
cb.Label.String='One-day pooled mean number concentration (cm^{-3})';
% The lower-right tile already carries the date; a global title collides
% with the top map labels in the retained Chapter 5 layout.
output_path=fullfile(output_dir,'Figure_5_1_Chapter5_v2_day_20070101.png');
exportgraphics(fig,output_path,'Resolution',300);close(fig);
fprintf('CHAPTER5_V2_DAY_PLOT_PASS %s aerosol=%d clear=%d\n',output_path, ...
 sum(aerosol_count,'all'),sum(clear_count,'all'));
end
