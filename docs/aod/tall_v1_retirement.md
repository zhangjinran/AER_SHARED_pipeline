# T_all AOD v1 retirement

Status: deletion was BLOCKED_BY_EXECUTION_POLICY; none of the files below
were deleted. Old T_all build/publication entry points have been disabled.
User requested deletion and replacement with the native APro profile-first
implementation. Only the following generated outputs are targeted. Original
T_all, global APro MAT, all unrelated products and all prior logs are retained.

- products/aod/aod_grid_day/aod__tall-apro-v1__ext-direct-ch5ccn-components-v1__grid5deg-v1/2007/01/01/AOD_GRID_20070101.mat
- Same date directory: manifest.txt, input_inventory.csv, _SUCCESS
- runs/aod/run_20070101_aod_001/staging/AOD_GRID_20070101.mat
- runs/aod/run_20070101_smoke_20260926_001/staging/AOD_GRID_20070101.mat
- runs/aod/run_20070101_smoke_20260926_001/staging/attempt_003/AOD_GRID_20070101.mat
- runs/aod/run_20070101_aod_001/plots/AOD_Direct_Extinction_20070101.png
- runs/aod/run_20070101_aod_001/plots/AOD_Chapter5_CCN_Components_20070101.png

Reason: the obsolete product used a filtered T_all input and per-type
presence-conditioned denominators. It is not the approved native-profile
product. Targeted derived files can be regenerated. Their execution logs
must remain in the old runs. The current blocked deletion retained all files.
