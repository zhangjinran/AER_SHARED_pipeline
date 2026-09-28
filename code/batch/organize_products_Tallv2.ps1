$ErrorActionPreference='Stop'
$root='F:\AER_SHARED_PIPELINE';$products=Join-Path $root 'products'
$mapping=[ordered]@{t_all='tall\t_all';calipso_stats='chapter5\calipso_stats';calipso_stats_chapter5_v2='chapter5\calipso_stats_chapter5_v2';calipso_stats_monthly='chapter5\calipso_stats_monthly';chapter5_map_stats='chapter5\chapter5_map_stats';chapter5_map_stats_v2='chapter5\chapter5_map_stats_v2';chapter5_n50_column='chapter5\chapter5_n50_column';clear_air_stats='chapter5\clear_air_stats';ccn_grid='ccn\ccn_grid';ccn_grid_monthly='ccn\ccn_grid_monthly';ccn_v2='ccn\ccn_v2'}
$receipt=Join-Path $root 'docs\architecture\products_migration_Tallv2_20260928.json'
if(Test-Path -LiteralPath $receipt){throw 'Migration receipt exists; inspect before repeating'}
$plan=@()
foreach($entry in $mapping.GetEnumerator()){
 $src=[IO.Path]::GetFullPath((Join-Path $products $entry.Key));$dst=[IO.Path]::GetFullPath((Join-Path $products $entry.Value))
 if(-not $src.StartsWith($products+'\') -or -not $dst.StartsWith($products+'\')){throw 'Out-of-scope target'}
 if(-not (Test-Path -LiteralPath $src -PathType Container)){throw "Missing source $src"}
 if(Test-Path -LiteralPath $dst){throw "Destination exists $dst"}
 $files=@(Get-ChildItem -LiteralPath $src -Recurse -File)
 $plan+= [pscustomobject]@{source=$src;destination=$dst;files=$files.Count;bytes=($files|Measure-Object Length -Sum).Sum;status='planned'}
}
$plan|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $receipt -Encoding utf8
foreach($p in $plan){
 New-Item -ItemType Directory -Force -Path (Split-Path $p.destination) | Out-Null
 Move-Item -LiteralPath $p.source -Destination $p.destination
 $files=@(Get-ChildItem -LiteralPath $p.destination -Recurse -File)
 if($files.Count -ne $p.files -or ($files|Measure-Object Length -Sum).Sum -ne $p.bytes){throw "Inventory mismatch $($p.destination)"}
 $p.status='moved_inventory_verified';$plan|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $receipt -Encoding utf8
}
New-Item -ItemType Directory -Force -Path (Join-Path $products 'chapter4') | Out-Null
# Mechanical path migration only, excluding immutable products and old run records.
$edited=@()
foreach($tree in @('code','plots')){
 foreach($file in Get-ChildItem -LiteralPath (Join-Path $root $tree) -Recurse -File | Where-Object {$_.Extension -in '.m','.ps1','.json','.yaml','.yml'}){
  if($file.FullName -eq $PSCommandPath){continue}
  $old=[IO.File]::ReadAllText($file.FullName);$new=$old
  foreach($entry in $mapping.GetEnumerator()){
   $key=[regex]::Escape($entry.Key);$parts=$entry.Value.Split('\');$cat=$parts[0]
   $new=[regex]::Replace($new,"products\\$key(?=[\\'""/])",('products\'+$entry.Value))
   $new=[regex]::Replace($new,"products/$key(?=[/'""\\])",('products/'+$entry.Value.Replace('\','/')))
   $new=[regex]::Replace($new,"'products'\s*,\s*'$key'",("'products','"+$cat+"','"+$entry.Key+"'"))
  }
  if($new -ne $old){[IO.File]::WriteAllText($file.FullName,$new,[Text.UTF8Encoding]::new($false));$edited+=$file.FullName}
 }
}
$edited|Set-Content (Join-Path $root 'docs\architecture\products_migration_Tallv2_edited_paths.txt')
Write-Output "MIGRATION_PASS directories=$($plan.Count) edited_files=$($edited.Count) AOD_unchanged=true"
