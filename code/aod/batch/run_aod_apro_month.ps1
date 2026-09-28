param([Parameter(Mandatory=$true)][ValidatePattern('^\d{6}$')][string]$Month,
      [Parameter(Mandatory=$true)][string]$RunRoot)
$ErrorActionPreference='Stop'
$resolved=[IO.Path]::GetFullPath($RunRoot)
if(-not $resolved.StartsWith('F:\AER_SHARED_PIPELINE\runs\aod\',[StringComparison]::OrdinalIgnoreCase)){throw 'RunRoot must be under runs/aod'}
$active=Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'" | Where-Object {$_.CommandLine -match 'run_aod_apro_(month|day)'}
if($active){throw 'Existing AOD MATLAB detected; do not launch a second instance.'}
$logs=Join-Path $resolved 'logs';New-Item -ItemType Directory -Force -Path $logs | Out-Null
$attempt=Get-Date -Format 'yyyyMMdd_HHmmss';$base=Join-Path $logs "month_$attempt"
$safeRun=$resolved.Replace("'","''").Replace('\','/')
$expression="restoredefaultpath; addpath('F:/AER_SHARED_PIPELINE/code/aod/batch'); run_aod_apro_month('$Month','$safeRun');"
& 'E:\tool\matlab2025a\bin\matlab.exe' -batch $expression -logfile "${base}_matlab.log" 1> "${base}.out.log" 2> "${base}.err.log"
if($LASTEXITCODE -ne 0){throw "AOD month failed ($LASTEXITCODE); inspect $base"}
