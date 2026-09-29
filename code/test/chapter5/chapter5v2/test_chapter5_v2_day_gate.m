function report = test_chapter5_v2_day_gate(candidate_path, report_path)
%TEST_CHAPTER5_V2_DAY_GATE Validate a candidate daily sample product.
if nargin < 2, report_path = ''; end
S = load(candidate_path,'CALIPSO_STATS_CH5_V2');
assert(isfield(S,'CALIPSO_STATS_CH5_V2'),'Chapter5v2:DayGate','Candidate variable missing.');
A = S.CALIPSO_STATS_CH5_V2;
assert(isequal(size(A.grid),[36 72]),'Chapter5v2:DayGate','Grid must be 36x72.');
assert(strcmp(A.meta.status,'candidate_unpublished'),'Chapter5v2:DayGate','Candidate status is wrong.');
assert(A.meta.volume_scale_conversion==1e9,'Chapter5v2:DayGate','Wrong unit conversion recorded.');
seen_ids = zeros(0,1); type_rows = zeros(1,7); component_sum_error = 0;
for i=1:36
    for j=1:72
        for dn = {'Day','Night'}
            if ~isfield(A.grid(i,j),dn{1}), continue; end
            % MATLAB struct arrays share field names across all 36x72 cells.
            % Cells without observations therefore carry Day/Night as []
            % doubles after another cell first creates that field.
            if ~isstruct(A.grid(i,j).(dn{1})), continue; end
            for mo = fieldnames(A.grid(i,j).(dn{1}))'
                block=A.grid(i,j).(dn{1}).(mo{1});
                for tf = fieldnames(block)'
                    tab=block.(tf{1}).data;
                    assert(all(isfinite(tab.sample_id)),'Chapter5v2:DayGate','Nonfinite sample id.');
                    assert(all(isfinite(tab.Nd_dry_OMCAM_v2) & tab.Nd_dry_OMCAM_v2>=0),'Chapter5v2:DayGate','Invalid retained Nd.');
                    typ=tab.original_type;
                    type_rows=type_rows+arrayfun(@(x)nnz(typ==x),1:7);
                    expected=zeros(height(tab),1);
                    expected(typ==1)=tab.N50_marine(typ==1);
                    expected(typ==2)=tab.N100_dust(typ==2);
                    expected(typ==3)=tab.N50_polluted_continental(typ==3);
                    expected(typ==4)=tab.N50_clean_continental(typ==4);
                    expected(typ==5)=tab.N100_dust(typ==5)+tab.N50_polluted_continental(typ==5);
                    expected(typ==6)=tab.N50_elevated_smoke(typ==6);
                    expected(typ==7)=tab.N100_dust(typ==7)+tab.N50_marine(typ==7);
                    component_sum_error=max(component_sum_error,max(abs(expected-tab.Nd_dry_OMCAM_v2),[],'omitnan'));
                    seen_ids=[seen_ids;tab.sample_id]; %#ok<AGROW>
                end
            end
        end
    end
end
assert(numel(unique(seen_ids))==numel(seen_ids),'Chapter5v2:DayGate','sample_id duplicated after grid bucketing.');
assert(numel(seen_ids)==A.meta.valid_rows,'Chapter5v2:DayGate','Valid row count mismatch.');
assert(component_sum_error<1e-10,'Chapter5v2:DayGate','Type component composition mismatch.');
report=table(string(datetime('now')),A.meta.input_rows,A.meta.valid_rows,type_rows,component_sum_error, ...
    'VariableNames',{'timestamp','input_rows','valid_rows','type_valid_counts','max_component_sum_error'});
if ~isempty(report_path)
    folder=fileparts(report_path); if ~isempty(folder) && ~isfolder(folder),mkdir(folder);end
    writetable(report,report_path);
end
fprintf('CHAPTER5_V2_DAY_GATE PASS rows=%d valid=%d\n',A.meta.input_rows,A.meta.valid_rows);
end
