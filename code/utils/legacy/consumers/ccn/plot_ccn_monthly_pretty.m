function output_path = plot_ccn_monthly_pretty(monthly_path, output_dir, label)
%PLOT_CCN_MONTHLY_PRETTY Reuse the established pretty CCN map style.
% Input is the formal monthly CCN_GRID product containing M.
S=load(monthly_path,'M'); M=S.M;
if ~isfolder(output_dir), mkdir(output_dir); end
pipeline_root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(pipeline_root,'plots','common')); ss=[.15 .25 .40];
f=figure('Visible','off','Color','w','Position',[50 50 1500 760]);
tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for q=1:3
    nexttile; D=M(:,:,q); D(D<=0)=NaN; Z=max(2,min(7,log10(D)));
    draw_global_5deg_robinson(Z,[2 7],sprintf('CCN %.2f%%',ss(q)),true);
end
nexttile; axis off; text(.05,.80,label,'FontSize',18,'FontWeight','bold'); text(.05,.62,'Global 5°x5° monthly CCN','FontSize',13); text(.05,.46,'Sample-weighted daily CCN_GRID aggregation','FontSize',12); text(.05,.28,'log_{10}(CCN cm^{-3}) = 2–7','FontSize',12);
colormap(turbo(35)); cb=colorbar; cb.Layout.Tile='east'; cb.Label.String='log_{10}(CCN cm^{-3})'; cb.Ticks=2:7; cb.TickLabels={'10^2','10^3','10^4','10^5','10^6','10^7'};
sgtitle('Global CCN Distribution','FontSize',20,'FontWeight','bold');
output_path=fullfile(output_dir,sprintf('CCN_%s_pretty.png',label)); exportgraphics(f,output_path,'Resolution',300); close(f);
fprintf('CCN_PRETTY_PLOT_PASS %s\n',output_path);
end
