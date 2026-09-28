function output_dir = build_aeronet_validation_input()
%BUILD_AERONET_VALIDATION_INPUT Build the AERONET subset for local Chapter-4 validation.

    root = fileparts(fileparts(mfilename('fullpath')));
    archive = fullfile(root, 'INV_Level15_All_Points_V3.tar.gz');
    extracted = fullfile(root, 'raw', 'ALM15_ALL');
    output_dir = fullfile(root, 'delivery', 'validation_20220501_20220516');
    if ~isfile(archive), error('AERONET:ArchiveMissing', 'Missing %s.', archive); end
    if ~isfolder(extracted) || isempty(dir(fullfile(extracted, '**', '*.all')))
        if ~isfolder(extracted), mkdir(extracted); end
        untar(archive, extracted);
    end
    if ~isfolder(output_dir), mkdir(output_dir); end

    date_start = datetime(2022,5,1, 'TimeZone', 'UTC');
    date_end = datetime(2022,5,16, 'TimeZone', 'UTC');
    [AERONET_Data, Site_Info, Radius, manifest] = read_areonet_all_v3(extracted, date_start, date_end);

    save(fullfile(output_dir, 'AERONET_Data_INVL15_20220501_20220516.mat'), 'AERONET_Data', '-v7.3');
    save(fullfile(output_dir, 'AERONET_Site_Info_INV15_20220501_20220516.mat'), 'Site_Info');
    save(fullfile(output_dir, 'AERONET_dVdlnr_R.mat'), 'Radius');
    writetable(manifest, fullfile(output_dir, 'site_manifest.csv'));
end
