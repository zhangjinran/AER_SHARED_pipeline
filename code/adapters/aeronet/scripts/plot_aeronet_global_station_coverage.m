function output_path = plot_aeronet_global_station_coverage()
%PLOT_AERONET_GLOBAL_STATION_COVERAGE Preview map for Chapter-5 validation.

    root = fileparts(fileparts(mfilename('fullpath')));
    input_path = fullfile(root, 'delivery', 'full_20070101_20221231_z05kmap_days', ...
        'AERONET_Data_INVL15_20070101_20221231_Z05kmAP.mat');
    output_dir = fullfile(root, 'delivery', 'full_20070101_20221231_z05kmap_days', 'preview');
    if ~isfolder(output_dir), mkdir(output_dir); end

    S = load(input_path, 'AERONET_Data');
    sites = fieldnames(S.AERONET_Data);
    n = numel(sites);
    lon = nan(n,1); lat = nan(n,1); count = nan(n,1);
    for i = 1:n
        q = S.AERONET_Data.(sites{i});
        lon(i) = q.longitude;
        lat(i) = q.latitude;
        count(i) = numel(q.time_UTC);
    end

    fig = figure('Color', 'w', 'Position', [100 100 1500 680]);
    ax = axes(fig); hold(ax, 'on');
    set(ax, 'Color', [0.94 0.97 1.00], 'Box', 'on', 'LineWidth', 1.0, ...
        'FontSize', 12, 'Layer', 'top', 'XGrid', 'on', 'YGrid', 'on', ...
        'GridColor', [0.75 0.78 0.82], 'GridAlpha', 0.45);
    xlim(ax, [-180 180]); ylim(ax, [-60 85]);
    xticks(ax, -180:30:180); yticks(ax, -60:20:80);
    xlabel(ax, 'Longitude (degrees)'); ylabel(ax, 'Latitude (degrees)');
    title(ax, {'AERONET V3 Inversion Coverage for CALIPSO N50 Validation', ...
        '2007-01-01 to 2022-12-31 | Color and marker size: valid inversion records'}, ...
        'FontWeight', 'bold');

    log_count = log10(count);
    marker_size = 14 + 50 * (log_count - min(log_count)) ./ ...
        max(eps, max(log_count) - min(log_count));
    scatter(ax, lon, lat, marker_size, log10(count), 'filled', ...
        'MarkerEdgeColor', [0.15 0.15 0.15], 'MarkerFaceAlpha', 0.85);
    colormap(ax, turbo(256));
    cb = colorbar(ax);
    cb.Label.String = 'log_{10}(valid AERONET retrieval count)';
    cb.Label.FontWeight = 'bold';
    text(ax, -175, -53, sprintf('%d stations | %s total records', n, ...
        sprintf('%0.3g', sum(count))), 'FontSize', 11, 'FontWeight', 'bold', ...
        'BackgroundColor', 'w', 'Margin', 5);

    output_path = fullfile(output_dir, 'AERONET_Global_Station_Coverage.png');
    exportgraphics(fig, output_path, 'Resolution', 240);
    close(fig);
end
