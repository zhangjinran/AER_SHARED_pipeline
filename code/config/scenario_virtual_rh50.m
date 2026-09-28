function sc = scenario_virtual_rh50()
%SCENARIO_VIRTUAL_RH50
% Scenario definition for constant RH = 50%.
%
% TARGET BEHAVIOR:
%   - CALIPSO AP MAT is required.
%   - ERA5 is NOT required.
%   - get_ERA5_meta must NOT be called by the future adapter.
%   - T_all.RH is explicitly set to 50.
%
% IMPORTANT:
%   This is an interface/sensitivity scenario.
%   It is NOT an ERA5-driven scientific result.

sc.name = 'virtual_rh50';
sc.version = 'v1';

sc.rh_mode = 'virtual_rh50';
sc.rh_source = 'constant';
sc.rh_value = 50;
sc.rh_unit = 'percent';

% Input requirements
sc.require_calipso_ap = true;
sc.require_era5 = false;

% ERA5 behavior
sc.allow_era5_access = false;
sc.require_complete_era5_day = false;

% Missing-RH policy
% No downstream fallback is allowed. RH must already be explicit in T_all.
sc.allow_downstream_rh_fallback = false;
sc.error_if_rh_missing = true;

% Product identity
sc.product_tag = 'virtual-rh50';

% Scientific status
sc.scientific_role = ...
    'interface_and_sensitivity_validation_not_era5_formal_result';

end
