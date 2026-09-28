# APro profile-first monthly AOD

Entry: code/aod/batch/run_aod_apro_month.ps1 -Month YYYYMM -RunRoot <runs/aod/new-run>

Freeze the canonical global APro month listing at the start in reports/frozen_inventory.mat and CSV. A missing date is recorded as MISSING_APRO; an unavailable directory or empty month listing fails rather than silently producing an empty month. Restart uses the same inventory. Failed loads use the existing NAS retry helper and ultimately fail rather than becoming missing dates.

Reuse formal daily profile/grid products. Produce missing daily products sequentially with the existing profile-first scientific code; do not generate daily plots. Keep individual day reports/staging below days/YYYYMMDD. No existing products are overwritten.

Pool daily sum_direct_ext, sum_component_reconstruction and common profile_count. Divide only after all READY days pass. This is native-profile weighting, not an average of daily means. Preserve sums and counts in products/aod/aod_grid_month for future pooling. Types 1,2,3,4,6 must be exactly equal, including missing-value locations, between the two methods at daily and monthly levels. Total equals the sum of seven original-type contributions. An unequal-count synthetic case tests pooling.

Publish monthly MAT, manifest, source inventory and _SUCCESS. Plot two eight-panel monthly figures with the same existing smooth Robinson renderer under the dedicated run/plots directory. Missing grids remain white. Source QC limitations are inherited from daily products.
