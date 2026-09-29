$ErrorActionPreference = 'Stop'
$root = 'F:\AER_SHARED_PIPELINE'
$batch = Join-Path $root 'code\run\tall\tallv2\run_Tallv2_month_downstream.m'
$logDir = Join-Path $root 'runs\produce\run_200701_Tallv2_downstream_001\logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$progress = Join-Path $logDir 'progress.log'
$active = Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'" | Where-Object { $_.CommandLine -match 'run_Tallv2_month_downstream' }
if ($active) { throw 'A Tallv2 downstream MATLAB instance is already running.' }
if (-not (Test-Path -LiteralPath $batch)) { throw "Runner missing: $batch" }
foreach ($stage in @('ccn','chapter5','chapter4')) {
    $marker = Join-Path $logDir ("$stage.complete")
    if (Test-Path -LiteralPath $marker) { continue }
    $categoryDir = Join-Path $root "runs\$stage\run_200701_Tallv2_001\logs"
    New-Item -ItemType Directory -Force -Path $categoryDir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $base = Join-Path $categoryDir "${stage}_200701_Tallv2_$stamp"
    "START $stage $(Get-Date -Format o)" | Add-Content -LiteralPath $progress
    $expr = "restoredefaultpath; cd('F:/AER_SHARED_PIPELINE'); addpath('F:/AER_SHARED_PIPELINE/code/run/tall/tallv2'); run_Tallv2_month_downstream('$stage');"
    $proc = Start-Process 'E:\tool\matlab2025a\bin\matlab.exe' -WorkingDirectory $root -WindowStyle Hidden `
        -ArgumentList @('-batch',('"'+$expr+'"'),'-logfile',('"'+$base+'_matlab.log"')) `
        -RedirectStandardOutput ($base+'.out.log') -RedirectStandardError ($base+'.err.log') -PassThru -Wait
    $proc.Refresh()
    $matlog = $base+'_matlab.log'
    $ok = (Test-Path -LiteralPath $matlog) -and ((Get-Content -LiteralPath $matlog -Raw) -match "TALLV2_MONTH_DOWNSTREAM_COMPLETE $stage")
    if (-not $ok -or ($null -ne $proc.ExitCode -and $proc.ExitCode -ne 0)) {
        "FAILED $stage exit=$($proc.ExitCode) matlab_log=$matlog" | Add-Content -LiteralPath $progress
        throw "Tallv2 downstream $stage failed. Inspect $matlog"
    }
    "PASS $stage $(Get-Date -Format o)" | Add-Content -LiteralPath $progress
    'PASS' | Set-Content -LiteralPath $marker
}
'ALL_TALLV2_MONTH_DOWNSTREAM_COMPLETE' | Add-Content -LiteralPath $progress
