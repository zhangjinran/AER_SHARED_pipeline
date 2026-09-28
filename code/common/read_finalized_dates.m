function [ready_dates, skipped] = read_finalized_dates(inventory_path)
%READ_FINALIZED_DATES Read the immutable date decision for one pipeline run.
% Monthly consumers must use this list rather than rescan raw inputs.
if isempty(inventory_path) || ~isfile(inventory_path)
    error('Coverage:MissingFinalizedDates','Missing finalized date inventory: %s',inventory_path);
end
T=readtable(inventory_path,'TextType','string');
need=["Date","Status"];
if ~all(ismember(need,string(T.Properties.VariableNames)))
    error('Coverage:Schema','Date inventory needs Date and Status columns: %s',inventory_path);
end
if isdatetime(T.Date)
    date_text=string(T.Date,'yyyy-MM-dd');
else
    date_text=string(datetime(string(T.Date),'InputFormat','yyyy-MM-dd'),'yyyy-MM-dd');
end
ready_dates=sort(date_text(string(T.Status)=="ready"));
skipped=T(string(T.Status)~="ready",:);
if isempty(ready_dates), error('Coverage:Empty','No ready dates in %s',inventory_path); end
if numel(unique(ready_dates))~=numel(ready_dates)
    error('Coverage:DuplicateDate','Duplicate ready dates in %s',inventory_path);
end
end
