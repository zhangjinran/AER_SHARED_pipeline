# Confirmed native-profile geolocation/order defect

2026-09-28: read-only audit of published 2007-01-01 T_all against the first sorted global APro orbit confirmed 43,100 optical rows match exactly, but stored Lon/Lat/UTC match the legacy incorrect reshape, not native profile centers. Latitude maximum discrepancy 110.655 degrees, median 27.3034 degrees on retained rows; longitude direct absolute maximum 162.115 degrees; time-order error maximum 1848.31 seconds. This is verified published-product evidence, not inference from map appearance.

Cause: read_calipso_apro_core normalizes coordinate arrays to N-by-3; core_to_table then linearly reshaped into 3-by-N. Native center must be column 2 of N-by-3. Longitude, latitude and time were all misassigned relative to optical bins.

Fix: shared calipso_profile_center validates orientation and extracts the native center without linear reshaping. Applied to canonical T_all and clear_air_collection_from_finalmat (the daily CLEAR producer). Optical bin flattening and scientific filtering remain unchanged. ERA5 spatial indexing now uses actual axes with periodic longitude rather than a clamped zero-based formula.

Existing products are NOT repaired by a code change. The audited adapter-v1 T_all is unsuitable for spatial matching; dependent RH, CCN, Chapter5 and Chapter4 results require rebuilding after validation. CLEAR products from the affected producer also require review/rebuild. No automatic replacement or deletion has occurred. Historical standalone legacy scripts still contain old reshape logic and must not be used as production entry points.

Independent AOD profile-v2 uses native profile centers directly and does not use T_all; it is outside this defect's propagation path.

Canonical-path verification passed: 43,100 retained first-orbit rows, longitude/latitude/time-order differences all exactly zero against native centers, optical fields exactly equal. Synthetic tests passed for both triplet orientations, rejection of ambiguous flattened triplets, periodic longitude and reversed ERA5 axes. See canonical_verify_matlab.log and sample_gate_PASS.txt in the validation run.

Initial fixed-sample test inadvertently invoked the old current-directory producer from F:/AER_RETRA_CASE, and correctly failed. The corrected validation explicitly changes working directory and asserts the resolved canonical producer. Both shared T_all wrappers now change to the new project root and assert the canonical producer path. The failed test candidate is retained only as diagnostic evidence, not published or reused.

A full 2007-01-01 real-RH candidate rebuild has been launched under candidate_era5_real/20070101 in the validation run. This is not a published replacement and does not repair downstream products automatically.

Validation outputs/logs: runs/produce/run_tall_geotime_fix_20260928_001. The existing numerical conversion of Profile_Time to datenum is retained in this targeted order repair. TAI/UTC epoch/leap-second convention is a separate unresolved timing audit; do not interpret this fix as validation of that convention or adjacent-day ERA5 hour selection.
