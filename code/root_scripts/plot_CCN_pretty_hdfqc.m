root='F:\AER_RETRA_CASE'; day=fullfile(root,'CCN_FULL_RERUN_20260821','day_20220601'); A=load(fullfile(day,'CCN_2022_06_01_grid_hdfqc.mat'),'M');
lon=-177.5:5:177.5; lat=-87.5:5:87.5; [X,Y]=meshgrid(lon,lat);
f=figure('Color','w','Position',[50 50 1500 760]); tiledlayout(2,2,'TileSpacing','compact','Padding','compact'); ss=[.15 .25 .40];
for q=1:3
 nexttile; D=A.M(:,:,q); D(D<=0)=NaN; Z=max(2,min(7,log10(D)));
 contourf(X,Y,Z,35,'LineStyle','none'); set(gca,'YDir','normal'); xlim([-180 180]); ylim([-90 90]); hold on; load coastlines; plot(coastlon,coastlat,'Color',[.25 .25 .25],'LineWidth',.55); hold off;
 set(gca,'Color',[.95 .95 .95],'Layer','top','XTick',-180:60:180,'YTick',-60:30:60,'FontSize',9); grid on; box on; title(sprintf('CCN %.2f%%',ss(q)),'FontWeight','bold'); xlabel('Longitude'); ylabel('Latitude'); caxis([2 7]);
end
nexttile; axis off; text(.05,.80,'2022-06-01','FontSize',18,'FontWeight','bold'); text(.05,.62,'Global 5°×5° CCN smoke test','FontSize',13); text(.05,.46,'HDF valid-range QC + logarithmic color scale','FontSize',12); text(.05,.28,'log_{10}(CCN cm^{-3}) = 2–7','FontSize',12);
colormap(parula(35)); cb=colorbar; cb.Layout.Tile='east'; cb.Label.String='log_{10}(CCN cm^{-3})'; cb.Ticks=2:7; cb.TickLabels={'10^2','10^3','10^4','10^5','10^6','10^7'}; sgtitle('Global CCN Distribution','FontSize',20,'FontWeight','bold'); exportgraphics(f,fullfile(day,'CCN_2022_06_01_pretty.png'),'Resolution',180); close(f);
