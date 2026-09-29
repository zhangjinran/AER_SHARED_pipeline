# Active AOD v2: native global APro, profile-first

Run `code/run/aod/aodv2/run_aod_apro_day.ps1 -Date 20070101 -RunRoot F:\AER_SHARED_PIPELINE\runs\aod\run_20070101_apro_v2_001` from the pipeline root.
Each launch creates uniquely named stdout, stderr and MATLAB logs. The controller
builds a native-profile product, grids it with one common profile denominator,
publishes by moving candidates, and renders two smooth Robinson grouped figures.
Empty grids are white; valid absent categories are zero and enter the mean.

Read `docs/aod/apro_profile_v2_contract.md` in the project root for the complete
contract and actual source-field inspection. The Jan-1 global APro MAT contains
both AVD planes and the full altitude grid but no Extinction_QC_Flag_532.
Products record this explicitly; no QC values are fabricated.

The five unchanged types are stored once; only reconstructed Type5, Type7 and
Total are additional profile columns. The grid stores both views for plotting,
with exactly equal pure-type values and a single shared profile_count.

## Retired v1 description (historical only)

The following documents the retired T_all implementation. Its day builder,
publisher and month controller now stop with AOD:RetiredTAll. Do not use those
entry points to generate new products. See docs/aod/tall_v1_retirement.md for
the cleanup status of old generated data.

This is an independent application branch. It reads only the formal daily
`T_all` product for scientific observations; it does not read ALay AOD, VFM,
or rerun the APro/HDF reader and profile matcher.

## Scientific outputs

Each daily/monthly 5° × 5° grid stores eight channels (Types 1–7 and Total)
for two methods:

1. `Direct_APro_Extinction`: sum `Ext [km^-1] × dz [km]` by APRO `Type`
   within the profile, then pool profile sums/counts into each grid cell.
2. `Chapter5_CCN_Component_Reconstruction`: Types 1, 2, 3, 4, and 6 retain
   direct APro `Ext`; Type 5 reconstructs dust + polluted-continental
   extinction, and Type 7 reconstructs dust + marine extinction using the
   same-row Type, Back, Depol, dust split, and lidar ratios from CCN-v2.
   Those layer contributions are integrated and combined within the profile
   before gridding. These reconstructed mixed-type values are not forced to
   equal the direct APro extinction integral.

The shared mixed-type parameters are read from the frozen CCN-v2 config:
depolarization endpoints 0.05/0.31; lidar ratios dust 44, polluted
continental 70, marine 23. No particle-size or OMCAM prior is involved in
AOD integration.

The APro value-domain gates are Ext ≤ 1.25 km⁻¹, total Back ≤
0.05 (km sr)⁻¹, and Depol in [0,1], with positive Ext/Back required where
used. These bounds were checked against the actual 2007-01-01 V5-00 APro
HDF dataset attributes. Invalid Ext rows are omitted from both methods;
mixed rows failing Back/Depol checks are omitted from the reconstructed
profile/type column, while their direct-Ext result remains independently
available. Rejection counts are included in daily product metadata.

## Vertical geometry and limitations

The AOD routine groups T_all rows by `FileName`, `Lon`, `Lat`, and `UTC` to
recover profile columns. It derives `dz` only when the available retained
height centers demonstrate one complete, uniform grid spacing. If centers
show gaps or multiple resolutions, it fails closed instead of inventing a
bin width. The Jan-01 smoke test found 306 retained centers with a uniform
spacing of 0.059957504 km. This is a gate to recheck across every date before
full-month production.

Because T_all does not retain `Extinction_QC_Flag_532` or rejected APRO
bins, the product represents the accepted T_all rows and cannot reapply the
source QC-flag policy or claim a complete-column retrieval where source bins
were omitted.

## Layout and execution

- `config/`, `science_core/`, `producers/`, `publishers/`, `consumers/`,
  `batch/`, `validation/`, `utils/`: AOD-only implementation.
- `products/aod/aod_grid_day/<key>/YYYY/MM/DD/`: immutable daily products.
- `products/aod/aod_grid_month/<key>/YYYY/MM/`: pooled monthly products.
- `runs/aod/run_<period>_.../`: frozen date inventory, logs, staging, plots.
- `run_aod_month(year,month,unique_run_root)` is the month controller. It
  freezes the T_all date inventory once, skips missing T_all days, reuses
  only complete existing AOD products, refuses overwrites, pools daily
  profile sums/counts, and writes exactly two smooth Robinson 8-panel plots.

The one-day Jan-01 smoke output is a run-local diagnostic candidate only; it
has not been published into the AOD product tree.
