function output_dir = build_aeronet_full_input()
%BUILD_AERONET_FULL_INPUT Create the 2007-2022 AERONET input on Z:\05kmAP days.

    root = fileparts(fileparts(mfilename('fullpath')));
    archive = fullfile(root, 'INV_Level15_All_Points_V3.tar.gz');
    extracted = fullfile(root, 'raw', 'ALM15_ALL');
    output_dir = fullfile(root, 'delivery', 'full_20070101_20221231_z05kmap_days');
    calipso_root = 'Z:\05kmAP';
    if ~isfile(archive), error('AERONET:ArchiveMissing', 'Missing %s.', archive); end
    if ~isfolder(extracted) || isempty(dir(fullfile(extracted, '**', '*.all')))
        if ~isfolder(extracted), mkdir(extracted); end
        untar(archive, extracted);
    end
    if ~isfolder(output_dir), mkdir(output_dir); end

    days = strings(0,1);
    for year = 2007:2022
        year_dir = fullfile(calipso_root, string(year));
        entries = dir(fullfile(year_dir, '????_??_??'));
        days = [days; string({entries.name})']; %#ok<AGROW>
    end
    days = unique(days);
    valid_days = datetime(replace(days, '_', '-'), 'InputFormat', 'yyyy-MM-dd', 'TimeZone', 'UTC');
    valid_days = sort(valid_days);
    whitelist = table(string(datestr(valid_days, 'yyyy-mm-dd')), 'VariableNames', {'calipso_day'});
    writetable(whitelist, fullfile(output_dir, 'calipso_05kmap_day_whitelist.csv'));

    date_start = datetime(2007,1,1, 'TimeZone', 'UTC');
    date_end = datetime(2022,12,31, 'TimeZone', 'UTC');
    [AERONET_Data, Site_Info, Radius, manifest] = read_areonet_all_v3(extracted, date_start, date_end, valid_days);

    save(fullfile(output_dir, 'AERONET_Data_INVL15_20070101_20221231_Z05kmAP.mat'), 'AERONET_Data', '-v7.3');
    save(fullfile(output_dir, 'AERONET_Site_Info_INV15_20070101_20221231_Z05kmAP.mat'), 'Site_Info');
    save(fullfile(output_dir, 'AERONET_dVdlnr_R.mat'), 'Radius');
    writetable(manifest, fullfile(output_dir, 'site_manifest.csv'));
end
