function output_path = build_clear_air_stats_day(date_str, final_mat_path, output_path)
%BUILD_CLEAR_AIR_STATS_DAY Build one daily CLEAR_STATS product from Final MAT.
% The scientific calculation remains in clear_air_collection_from_finalmat.m.
    arguments
        date_str (1,:) char
        final_mat_path (1,:) char
        output_path (1,:) char
    end
    datetime(date_str,'InputFormat','yyyy-MM-dd'); %#ok<NASGU>
    if ~isfile(final_mat_path), error('ClearStats:MissingFinalMAT','Missing Final MAT: %s',final_mat_path); end
    out_dir=fileparts(output_path); if ~isfolder(out_dir), mkdir(out_dir); end
    old_final=getenv('CHAPTER5_FINALMAT_FILE');
    old_output=getenv('CHAPTER5_CLEAR_OUTPUT_FILE');
    cleanup=onCleanup(@()restore_env(old_final,old_output)); %#ok<NASGU>
    setenv('CHAPTER5_FINALMAT_FILE',final_mat_path);
    setenv('CHAPTER5_CLEAR_OUTPUT_FILE',output_path);
    run(fullfile(fileparts(mfilename('fullpath')),'clear_air_collection_from_finalmat.m'));
    if ~isfile(output_path), error('ClearStats:MissingOutput','Producer did not create %s',output_path); end
end

function restore_env(final_value,output_value)
    setenv('CHAPTER5_FINALMAT_FILE',final_value);
    setenv('CHAPTER5_CLEAR_OUTPUT_FILE',output_value);
end
