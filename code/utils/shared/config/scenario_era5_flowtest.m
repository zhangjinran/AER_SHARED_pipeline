function sc = scenario_era5_flowtest()
%SCENARIO_ERA5_FLOWTEST Temporary ERA5 flow validation only.
% Uses real ERA5 RH but a temporary below-ground profile trimming rule.

sc = scenario_era5_real();
sc.name = 'era5_flowtest';
sc.rh_mode = 'era5_flowtest';
sc.product_tag = 'era5-flowtest';
sc.scientific_role = 'FLOW_TEST_ONLY';
sc.formal_science_product = false;
sc.height_profile_policy = ...
    'remove_negative_height_then_trim_leading_nonmonotonic_levels';
end
