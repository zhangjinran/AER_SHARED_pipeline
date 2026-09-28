function report = test_ccn_v2_day_gate(candidate_path, report_path)
%TEST_CCN_V2_DAY_GATE Enforce the frozen daily 3-D product contract.
S=load(candidate_path,'sum_component','sum_total','sample_count','meta');
assert(isequal(size(S.sum_component),[90 72 133 5 3]),'CCNv2:DayShape','Bad component grid shape.');
assert(isequal(size(S.sum_total),[90 72 133 3]),'CCNv2:DayShape','Bad total grid shape.');
assert(isequal(size(S.sample_count),[90 72 133]),'CCNv2:DayShape','Bad count grid shape.');
x=sum(S.sum_component,4); delta=max(abs(S.sum_total(:)-x(:)));
assert(isfinite(delta)&&delta<1e-9,'CCNv2:Conservation','Component sum does not equal total.');
assert(all(isfinite(S.sum_component(:)))&&all(S.sum_component(:)>=0),'CCNv2:Finite','Invalid component sums.');
assert(all(isfinite(S.sample_count(:)))&&all(S.sample_count(:)>=0),'CCNv2:Count','Invalid sample count.');
assert(numel(S.meta.altitude_km)==133,'CCNv2:Altitude','Bad canonical altitude axis.');
report=table(S.meta.input_rows,S.meta.retained_samples,delta,'VariableNames',{'input_rows','retained_samples','max_component_total_difference'});
if nargin>1&&~isempty(report_path),writetable(report,report_path);end
fprintf('CCN_V2_DAY_GATE PASS retained=%d maxdelta=%.3g\n',S.meta.retained_samples,delta);
end
