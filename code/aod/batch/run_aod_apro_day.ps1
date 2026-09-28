param([Parameter(Mandatory=$true)][ValidatePattern('^\d{8}$')][string]$Date,
      [Parameter(Mandatory=$true)][string]$RunRoot)
$ErrorActionPreference='Stop'
$allowed='F:\AER_SHARED_PIPELINE\runs\aod\'
$resolved=[IO.Path]::GetFullPath($RunRoot)
if(-not $resolved.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'RunRoot must be under runs\aod'}
$active=Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'" | Where-Object { $_.CommandLine -like '*run_aod_apro_day*' -and $_.CommandLine -like "*$Date*" }
if($active){throw 'An AOD day process already exists; inspect it before restarting.'}
$logs=Join-Path $resolved 'logs';New-Item -ItemType Directory -Force -Path $logs | Out-Null
$attempt=Get-Date -Format 'yyyyMMdd_HHmmss'
$base=Join-Path $logs "production_$attempt"
$safeRun=$resolved.Replace("'","''").Replace('\','/')
$expression="restoredefaultpath; addpath('F:/AER_SHARED_PIPELINE/code/aod/batch'); run_aod_apro_day('$Date','$safeRun');"
& 'E:\tool\matlab2025a\bin\matlab.exe' -batch $expression -logfile "${base}_matlab.log" 1> "${base}.out.log" 2> "${base}.err.log"
if($LASTEXITCODE -ne 0){throw "MATLAB failed (exit $LASTEXITCODE); inspect $base"}
