function plot_ccn_grid_consumer(grid_path,out_dir,date_str)
S=load(grid_path,'M','cnt'); M=S.M; if ~isfolder(out_dir),mkdir(out_dir);end
lon=-177.5:5:177.5; lat=-87.5:5:87.5; labels={'0.15%','0.25%','0.40%'};
for q=1:3
 f=figure('Visible','off','Color','w','Position',[50 80 900 620]); imagesc(lon,lat,M(:,:,q));set(gca,'YDir','normal');axis tight equal;colorbar;xlabel('Longitude');ylabel('Latitude');title(['CCN ',labels{q},' - ',date_str]);exportgraphics(f,fullfile(out_dir,sprintf('CCN_%s_%s.png',strrep(labels{q},'.','p'),datestr(datetime(date_str),'yyyymmdd'))),'Resolution',180);close(f);
end
f=figure('Visible','off','Color','w','Position',[50 80 1500 430]);for q=1:3,subplot(1,3,q);imagesc(lon,lat,M(:,:,q));set(gca,'YDir','normal');axis tight equal;colorbar;title(['CCN ',labels{q}]);end;sgtitle(['Global 5°x5° CCN - ',date_str]);exportgraphics(f,fullfile(out_dir,['CCN_',datestr(datetime(date_str),'yyyymmdd'),'_global.png']),'Resolution',180);close(f);
fprintf('PLOTS_WRITTEN=%s\n',out_dir);
end
