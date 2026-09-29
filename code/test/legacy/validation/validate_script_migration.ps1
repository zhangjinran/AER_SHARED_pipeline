param([string]$Root = 'F:\AER_SHARED_PIPELINE')
$old = 'F:\AER_RETRA_CASE'
$scope = @("$Root\code\config","$Root\code\producers","$Root\code\publishers","$Root\code\adapters","$Root\code\consumers","$Root\validation")
$hits = @(rg -n --glob '*.m' --glob '*.py' --glob '*.ps1' ([regex]::Escape($old)) $scope 2>$null)
if ($hits.Count) { $hits | ForEach-Object { $_ }; throw "OLD_PROJECT_HARDCODE_FOUND" }
$required = @(
  "$Root\code\config\data_roots.m",
  "$Root\code\producers\t_all\build_shared_tall_day.m",
  "$Root\code\producers\calipso_stats\build_calipso_stats.m",
  "$Root\code\producers\ccn_grid\build_ccn_grid_from_shared_tall.m",
  "$Root\code\publishers\publish_shared_tall_day.m",
  "$Root\code\publishers\publish_ccn_grid_day.m",
  "$Root\validation\regression\compare_tall_hash_gate.m"
)
$missing = @($required | Where-Object { -not (Test-Path -LiteralPath $_) })
if ($missing.Count) { $missing; throw "REQUIRED_SCRIPT_MISSING" }
"SCRIPT_MIGRATION_PASS"
"checked_root=$Root"
"required_scripts=$($required.Count)"
