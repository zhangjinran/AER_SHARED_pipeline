function final_dir = controlled_publish_month_dir(tmp_dir, final_dir, expected_dates, product_type)
%CONTROLLED_PUBLISH_MONTH_DIR Replace a monthly product only for coverage growth.
% tmp_dir must already contain the data MAT, manifest.txt and input_inventory.csv.
expected_dates=sort(string(expected_dates(:)));
success=fullfile(final_dir,'_SUCCESS'); parent=fileparts(final_dir);
if isfolder(final_dir)
    if ~isfile(success), error('MonthPublish:IncompleteExisting','Existing final directory lacks _SUCCESS: %s',final_dir); end
    old=readtable(fullfile(final_dir,'input_inventory.csv'),'TextType','string');
    if ~all(ismember(["Date","Status"],string(old.Properties.VariableNames))), error('MonthPublish:OldInventory','Invalid old inventory: %s',final_dir); end
    old_dates=sort(string(old.Date(string(old.Status)=="processed" | string(old.Status)=="ready")));
    if isequal(old_dates,expected_dates), rmdir(tmp_dir,'s'); return; end
    if ~all(ismember(old_dates,expected_dates))
        error('MonthPublish:CoverageConflict','Existing %s coverage is not a subset of the frozen date set.',product_type);
    end
    backup=tempname(parent);
    movefile(final_dir,backup);
    try
        movefile(tmp_dir,final_dir);
        fid=fopen(fullfile(final_dir,'replacement_receipt.txt'),'w');
        fprintf(fid,'product_type=%s\nold_processed_days=%d\nnew_processed_days=%d\nreplaced_time=%s\n',product_type,numel(old_dates),numel(expected_dates),char(datetime('now'))); fclose(fid);
        rmdir(backup,'s');
    catch ME
        if ~isfolder(final_dir) && isfolder(backup), movefile(backup,final_dir); end
        rethrow(ME)
    end
else
    movefile(tmp_dir,final_dir);
end
end
