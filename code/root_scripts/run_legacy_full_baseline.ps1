$py='C:\Users\ZL\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$out='Z:\ERA5\test_conversion\legacy_hourly_baseline\2007\01\01'; New-Item -ItemType Directory -Force -Path $out | Out-Null
$log='Z:\ERA5\manifests\legacy_full_baseline_20070101.log'; $sw=[Diagnostics.Stopwatch]::StartNew()
for($h=0;$h -le 23;$h++){ "HOUR=$h START $(Get-Date)"|Add-Content $log; & $py 'F:\AER_RETRA_CASE\convert_era5_zraw_one_hour.py' $h $out *>> $log; "HOUR=$h EXIT=$LASTEXITCODE $(Get-Date)"|Add-Content $log }
$sw.Stop(); "TOTAL_SECONDS=$($sw.Elapsed.TotalSeconds)"|Add-Content $log
