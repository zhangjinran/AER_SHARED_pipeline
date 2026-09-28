function report = test_chapter5_v2_unit_gate(report_path)
%TEST_CHAPTER5_V2_UNIT_GATE Validate frozen prior and sample-level contract.

if nargin < 1, report_path = ''; end
cfg = chapter5_v2_config();
assert(isfile(cfg.parameter_file),'Chapter5v2:Prior','Missing immutable parameter prior.');
assert(isfile(cfg.extinction_file),'Chapter5v2:Prior','Missing immutable extinction prior.');
assert(isfile(cfg.prior_manifest),'Chapter5v2:Prior','Missing immutable prior manifest.');
assert(cfg.volume_scale_conversion == 1e9,'Chapter5v2:Unit','Volume conversion must be 1e9.');

P = load(cfg.parameter_file,'data');
assert(isfield(P,'data'),'Chapter5v2:Prior','Parameter prior lacks data.');
assert(abs(P.data.v_i_fine(1)-0.14) < eps && abs(P.data.v_i_coarse(1)-0.86) < eps, ...
    'Chapter5v2:Marine','Frozen Marine volume fractions do not match latest AERONET values.');
assert(abs(P.data.r_mean_fine(1)-0.1137) < eps && abs(P.data.r_mean_coarse(1)-1.8756) < eps, ...
    'Chapter5v2:Marine','Frozen Marine radii do not match latest AERONET values.');

E = load(cfg.extinction_file,'Extinction_N');
fields = {'CM','DU','PC','CC','SM'};
for k = 1:numel(fields)
    tab = E.Extinction_N.(fields{k});
    assert(isequal(tab(:,1),(0:99)'),'Chapter5v2:RHAxis','%s RH axis must be 0:99.',fields{k});
    assert(all(isfinite(tab(:,2)) & tab(:,2)>0),'Chapter5v2:Prior','%s extinction must be finite and positive.',fields{k});
end

T = table(repmat(0.02,7,1),repmat(5e-4,7,1), ...
    [0.10;0.20;0.10;0.10;0.18;0.10;0.18],(1:7)',repmat(50,7,1), ...
    (1001:1007)','VariableNames',{'Ext','Back','Depol','Type','RH','sample_id'});
out = compute_chapter5_sample_contributions_v2(T,E.Extinction_N,cfg);
assert(all(out.valid),'Chapter5v2:Sample','Representative Type 1--7 rows must be valid.');
assert(out.mixed_beta_conserved,'Chapter5v2:Mixed','Mixed beta conservation failed.');
assert(all(out.n50_marine(2:6)==0),'Chapter5v2:Routing','Non-marine rows leaked marine contribution.');
assert(out.n50_marine(7)>0 && out.n100_dust(7)>0,'Chapter5v2:Type7','Type 7 must retain same-row dust and marine.');
assert(out.n100_dust(5)>0 && out.n50_polluted_continental(5)>0,'Chapter5v2:Type5','Type 5 must retain same-row dust and PC.');
assert(abs(out.chapter5_type_value_cm3(5) - (out.n100_dust(5)+out.n50_polluted_continental(5))) < 1e-10, ...
    'Chapter5v2:Type5','Type 5 composition is not sample-local.');
assert(abs(out.chapter5_type_value_cm3(7) - (out.n100_dust(7)+out.n50_marine(7))) < 1e-10, ...
    'Chapter5v2:Type7','Type 7 composition is not sample-local.');
assert(isequal(out.sample_id,T.sample_id) && isequal(out.original_type,T.Type), ...
    'Chapter5v2:Provenance','sample_id/original_type changed through sample adapter.');

Tbad = T(1,:);
Tbad.RH = 100;
bad = compute_chapter5_sample_contributions_v2(Tbad,E.Extinction_N,cfg);
assert(~bad.valid && isnan(bad.chapter5_type_value_cm3), ...
    'Chapter5v2:Invalid','Out-of-range RH must remain invalid, not receive a fallback.');

report = table(string(datetime('now')),height(T),nnz(out.valid),out.mixed_beta_conserved, ...
    cfg.volume_scale_conversion,string(cfg.prior_root), ...
    'VariableNames',{'timestamp','representative_samples','valid_samples','mixed_beta_conserved', ...
    'volume_scale_conversion','prior_root'});
if ~isempty(report_path)
    folder=fileparts(report_path);
    if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
    writetable(report,report_path);
end
fprintf('CHAPTER5_V2_UNIT_GATE PASS samples=%d prior=%s\n',height(T),cfg.prior_root);
end
