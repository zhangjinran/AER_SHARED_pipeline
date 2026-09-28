function plot_ccn_grid_monthly_consumer(monthly_path,out_dir,label)
S=load(monthly_path,'M'); M=S.M; if ~isfolder(out_dir), mkdir(out_dir); end
lon=-177.5:5:177.5; lat=-87.5:5:87.5; labels={'0.15%','0.25%','0.40%'};
for q=1:3
 f=figure('Visible','off','Color','w','Position',[50 80 900 620]); imagesc(lon,lat,M(:,:,q)); set(gca,'YDir','normal'); axis tight equal; colorbar; xlabel('Longitude'); ylabel('Latitude'); title(['Monthly CCN ',labels{q},' - ',label]); exportgraphics(f,fullfile(out_dir,sprintf('CCN_%s_%s.png',strrep(labels{q},'.','p'),label)),'Resolution',180); close(f);
end
f=figure('Visible','off','Color','w','Position',[50 80 1500 430]); for q=1:3, subplot(1,3,q); imagesc(lon,lat,M(:,:,q)); set(gca,'YDir','normal'); axis tight equal; colorbar; title(['CCN ',labels{q}]); end; sgtitle(['Monthly global 5°x5° CCN - ',label]); exportgraphics(f,fullfile(out_dir,['CCN_',label,'_global.png']),'Resolution',180); close(f); fprintf('CCN_MONTHLY_PLOTS_PASS output=%s\n',out_dir);
end
