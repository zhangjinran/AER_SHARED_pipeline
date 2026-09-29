function out = compute_chapter5_sample_contributions_v2(T, extinction_n, cfg)
%COMPUTE_CHAPTER5_SAMPLE_CONTRIBUTIONS_V2
% Uses immutable OMCAM-v2 component physics, then combines components only
% within the original T_all row for legacy-compatible Chapter 5 Types.

if nargin < 3 || isempty(cfg), cfg = chapter5_v2_config(); end
required = {'Ext','Back','Depol','Type','RH'};
if ~istable(T) || ~all(ismember(required,T.Properties.VariableNames))
    error('Chapter5v2:Schema','T must contain: %s.',strjoin(required,', '));
end
n = height(T);
if ismember('sample_id',T.Properties.VariableNames)
    sample_id = double(T.sample_id(:));
    if any(~isfinite(sample_id)) || numel(unique(sample_id)) ~= n
        error('Chapter5v2:SampleId','sample_id must be finite and unique within one daily T_all input.');
    end
else
    sample_id = (1:n)';
end
original_type = double(T.Type(:));

% This CCN_v2 routine returns pre-fss N50/N100 component numbers.  No CCN
% GRID, supersaturation multiplier, or CCN denominator enters this adapter.
addpath(fullfile(cfg.ccn_v2_root,'config'),'-begin');
addpath(fullfile(cfg.ccn_v2_root,'science_core'),'-begin');
base = compute_ccn_sample_contributions_v2(T, extinction_n, cfg.ccn_v2);
component_n = double(base.ccn020_component_cm3);
if ~isequal(size(component_n),[n 5])
    error('Chapter5v2:CoreShape','CCN_v2 core returned an unexpected component array.');
end

valid = logical(base.valid(:));
legacy_value = nan(n,1);
for k = 1:n
    if ~valid(k), continue; end
    switch original_type(k)
        case 1, legacy_value(k) = component_n(k,1);                     % marine N50
        case 2, legacy_value(k) = component_n(k,2);                     % dust N100
        case 3, legacy_value(k) = component_n(k,3);                     % PC N50
        case 4, legacy_value(k) = component_n(k,4);                     % CC N50
        case 5, legacy_value(k) = component_n(k,2) + component_n(k,3); % dust + PC
        case 6, legacy_value(k) = component_n(k,5);                     % smoke N50
        case 7, legacy_value(k) = component_n(k,2) + component_n(k,1); % dust + marine
        otherwise, valid(k) = false;
    end
end
legacy_value(~valid) = NaN;

out = struct();
out.sample_id = sample_id;
out.original_type = original_type;
out.valid = valid;
out.n50_marine = component_n(:,1);
out.n100_dust = component_n(:,2);
out.n50_polluted_continental = component_n(:,3);
out.n50_clean_continental = component_n(:,4);
out.n50_elevated_smoke = component_n(:,5);
out.component_alpha_km_inv = base.component_alpha_km_inv;
out.number_factor = base.number_factor;
out.chapter5_type_value_cm3 = legacy_value;
out.mixed_beta_conserved = base.mixed_beta_conserved;
end
