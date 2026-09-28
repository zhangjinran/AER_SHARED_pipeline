function pass = compare_calipso_step1_outputs(hdf_path, mat_path)
%COMPARE_CALIPSO_STEP1_OUTPUTS Strictly compare two saved T_all variables.
    h = load(hdf_path, 'T_all'); m = load(mat_path, 'T_all');
    pass = isequaln(h.T_all, m.T_all);
    if ~pass
        error('CALIPSO:OutputMismatch', ...
            'T_all outputs are not strictly identical: %s vs %s', hdf_path, mat_path);
    end
    fprintf('PASS: T_all is strictly identical (%d rows, %d variables).\n', ...
        height(h.T_all), width(h.T_all));
end
