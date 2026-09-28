$root='F:\AER_RETRA_CASE'; $base=Join-Path $root 'CCN_FULL_RERUN_20260821\month_202206'; $log=Join-Path $base 'ccn_month_serial.log'; Add-Content $log "START $(Get-Date)"
$files=Get-ChildItem -LiteralPath $base -Recurse -Filter 'CALIPSO_results_*_hdf.mat' -File
foreach($f in $files){$out=Join-Path $f.DirectoryName 'CCN_grid_hdfqc.mat'; if(!(Test-Path -LiteralPath $out)){$cmd="addpath('$root\函数'); process_one_orbit_CCN('$($f.FullName)','$out')"; & 'E:\tool\matlab2025a\bin\matlab.exe' -batch $cmd; $ec=$LASTEXITCODE; $sz=0;if(Test-Path -LiteralPath $out){$sz=(Get-Item -LiteralPath $out).Length}; Add-Content $log "$($f.FullName) exit=$ec bytes=$sz"}}
Add-Content $log "FINISHED $(Get-Date)"
