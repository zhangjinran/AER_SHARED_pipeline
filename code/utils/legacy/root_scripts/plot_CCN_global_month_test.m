% Global 5x5-degree CCN map using existing Nd_dry_OMCAM values.
month_name = 'Jun';
daynight = {'Day','Night'};
S = load('CALIPSO_STATS_Monthly.mat','CALIPSO_STATS');
G = S.CALIPSO_STATS.grid;
[nlat,nlon] = size(G);
ccn = nan(nlat,nlon,3);
for i = 1:nlat
    for j = 1:nlon
        vals = [];
        for d = 1:numel(daynight)
            if ~isfield(G(i,j),daynight{d}) || ~isfield(G(i,j).(daynight{d}),month_name), continue; end
            M = G(i,j).(daynight{d}).(month_name);
            for t = 1:7
                name = sprintf('Type%d',t);
                if isfield(M,name) && isfield(M.(name),'data')
                    T = M.(name).data;
                    if ismember('Nd_dry_OMCAM',T.Properties.VariableNames)
                        x = T.Nd_dry_OMCAM;
                        vals = [vals; x(isfinite(x) & x >= 0)]; %#ok<AGROW>
                    end
                end
            end
        end
        if ~isempty(vals)
            n = mean(vals,'omitnan');
            ccn(i,j,:) = [n, 1.35*n, 1.70*n];
        end
    end
end
lon = -177.5:5:177.5;
lat = -87.5:5:87.5;
fprintf('finite grid cells: %d/%d\n',sum(any(isfinite(ccn(:,:,1)),2),'all'),numel(ccn(:,:,1)));
fprintf('CCN15 min/max: %g / %g\n',min(ccn(:,:,1),[],'all','omitnan'),max(ccn(:,:,1),[],'all','omitnan'));
f = figure('Color','w','Position',[50 80 1500 430]);
ss = [0.15 0.25 0.40];
for k = 1:3
    subplot(1,3,k);
    Z = ccn(:,:,k); Z(~isfinite(Z)) = NaN;
    imagesc(lon,lat,Z); set(gca,'YDir','normal'); axis tight equal;
    xlabel('Longitude'); ylabel('Latitude');
    title(sprintf('CCN %.2f%% - %s',ss(k),month_name));
    colorbar;
    finiteZ = Z(isfinite(Z));
    if ~isempty(finiteZ), caxis([0 prctile(finiteZ,99)]); end
end
sgtitle('Global 5°x5° CCN distribution from existing CALIPSO statistics');
exportgraphics(f,sprintf('CCN_global_%s_test.png',month_name),'Resolution',180);
close(f);
