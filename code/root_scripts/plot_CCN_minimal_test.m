S = load('test_CCN_minimal_existing_data_output.mat');
O = S.Out;
ccn = [O.CCN_15(:), O.CCN_25(:), O.CCN_40(:)];
ccn = ccn(all(isfinite(ccn),2),:);

f = figure('Color','w','Position',[100 100 900 520]);
subplot(1,2,1);
boxchart(ccn, 'Labels', {'CCN 0.15%','CCN 0.25%','CCN 0.40%'});
ylabel('CCN (cm^{-3})'); title('固定系数 CCN 分布'); grid on;

subplot(1,2,2);
plot(ccn(:,1), ccn(:,2), 'o', 'MarkerSize', 4); hold on;
plot(ccn(:,1), ccn(:,3), 'o', 'MarkerSize', 4);
xlabel('CCN_{0.15%} (cm^{-3})'); ylabel('CCN (cm^{-3})');
legend('CCN_{0.25%}','CCN_{0.40%}','Location','northwest');
title('不同过饱和度固定系数结果'); grid on;

exportgraphics(f, 'CCN_minimal_test_plot.png', 'Resolution', 180);
close(f);
