function report = validate_hdf_mat_adapter_day(date_str, varargin)
%VALIDATE_HDF_MAT_ADAPTER_DAY Strictly compare HDF and converted MAT inputs.
%   REPORT = VALIDATE_HDF_MAT_ADAPTER_DAY('2007-01-01') validates every
%   05kmAP file for that day. Equality means identical field names, classes,
%   sizes and values after the MAT adapter normalizes storage orientation.
%
%   This is a read-only validation and does not touch the converter.

    p = inputParser;
    addRequired(p, 'date_str', @(x) ischar(x) || isstring(x));
    addParameter(p, 'HdfRoot', 'Z:\05kmAP', @(x) ischar(x) || isstring(x));
    addParameter(p, 'MatRoot', 'Z:\CALIPSO_MAT_DB\data\05kmAP', @(x) ischar(x) || isstring(x));
    addParameter(p, 'MaxFiles', inf, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'ReportPath', '', @(x) ischar(x) || isstring(x));
    parse(p, date_str, varargin{:});
    opt = p.Results;

    addpath(fullfile(fileparts(mfilename('fullpath')), '函数'));
    dt = datetime(date_str, 'InputFormat', 'yyyy-MM-dd');
    year_text = datestr(dt, 'yyyy');
    day_text = datestr(dt, 'yyyy_mm_dd');
    hdf_dir = fullfile(char(opt.HdfRoot), year_text, day_text);
    mat_path = fullfile(char(opt.MatRoot), year_text, [day_text '.mat']);

    hdf_files = dir(fullfile(hdf_dir, '*.hdf'));
    if isempty(hdf_files), error('No HDF files found in %s', hdf_dir); end
    if ~isfile(mat_path), error('Day MAT not found: %s', mat_path); end
    loaded = load(mat_path, 'day');
    day = loaded.day;

    mat_names = cellfun(@(x) char(x.filename), day.files, 'UniformOutput', false);
    [~, order] = sort({hdf_files.name});
    hdf_files = hdf_files(order);
    n = min([numel(hdf_files), numel(day.files), opt.MaxFiles]);

    details = repmat(struct('filename','','pass',false,'message',''), n, 1);
    for i = 1:n
        name = hdf_files(i).name;
        mi = find(strcmp(mat_names, name), 1);
        details(i).filename = name;
        if isempty(mi)
            details(i).message = 'File is absent from day.files';
            continue;
        end
        try
            hdf_data = read_calipso_apro_core(fullfile(hdf_files(i).folder, name), 'hdf');
            mat_data = read_calipso_apro_core(day.files{mi}, 'mat');
            [details(i).pass, details(i).message] = strict_struct_equal(hdf_data, mat_data);
        catch ME
            details(i).message = ME.message;
        end
        fprintf('[%d/%d] %s: %s\n', i, n, name, ternary(details(i).pass, 'PASS', details(i).message));
    end

    report = struct();
    report.date = char(date_str);
    report.hdf_count = numel(hdf_files);
    report.mat_count = numel(day.files);
    report.checked_count = n;
    report.pass_count = nnz([details.pass]);
    report.pass = report.hdf_count == report.mat_count && report.pass_count == n;
    report.details = details;
    report.generated_at = datestr(now, 31);

    report_path = char(opt.ReportPath);
    if isempty(report_path)
        report_path = fullfile(fileparts(mfilename('fullpath')), 'output_integrated', ...
            ['adapter_validation_' day_text '.mat']);
    end
    out_dir = fileparts(report_path);
    if ~isfolder(out_dir), mkdir(out_dir); end
    save(report_path, 'report');
    fprintf('Validation result: %d/%d passed. Report: %s\n', report.pass_count, n, report_path);
    if ~report.pass, error('CALIPSO:AdapterMismatch', 'HDF/MAT adapter validation failed.'); end
end

function [ok, message] = strict_struct_equal(a, b)
    fa = sort(fieldnames(a)); fb = sort(fieldnames(b));
    if ~isequal(fa, fb)
        ok = false; message = 'Field sets differ'; return;
    end
    for i = 1:numel(fa)
        f = fa{i};
        if ~strcmp(class(a.(f)), class(b.(f)))
            ok = false; message = sprintf('%s class differs (%s/%s)', f, class(a.(f)), class(b.(f))); return;
        end
        if ~isequal(size(a.(f)), size(b.(f)))
            ok = false; message = sprintf('%s size differs (%s/%s)', f, mat2str(size(a.(f))), mat2str(size(b.(f)))); return;
        end
        if ~isequaln(a.(f), b.(f))
            ok = false; message = sprintf('%s values differ', f); return;
        end
    end
    ok = true; message = 'PASS';
end

function out = ternary(cond, yes, no)
    if cond, out = yes; else, out = no; end
end
