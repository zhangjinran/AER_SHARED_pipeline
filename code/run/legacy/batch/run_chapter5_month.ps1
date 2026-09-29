param(
    [int]$Year = 2007,
    [int]$Month = 1,
    [string]$RunId = 'chapter5\run_200701_month_001'
)

$projectRoot = 'F:\AER_SHARED_PIPELINE'
$matlabExe = 'E:\tool\matlab2025a\bin\matlab.exe'
if ($RunId -notmatch '^chapter5[\\/]run_[A-Za-z0-9_-]+$') {
    if ($RunId -match '^[A-Za-z0-9_-]+$') { $RunId = "chapter5\$RunId" }
    else { throw 'RunId must be chapter5\run_<id> (or a bare run_<id>, which is placed under chapter5).' }
}
$RunId = $RunId -replace '/', '\'
$runRoot = Join-Path $projectRoot ('runs\' + $RunId)
$logRoot = Join-Path $runRoot 'logs\chapter5_batch'
$stageRoot = Join-Path $runRoot 'staging\chapter5_month'
$plotRoot = Join-Path $runRoot 'plots\chapter5\monthly'
New-Item -ItemType Directory -Force -Path $logRoot,$stageRoot,$plotRoot | Out-Null

$monthStart = Get-Date -Year $Year -Month $Month -Day 1
$monthEnd = $monthStart.AddMonths(1).AddDays(-1)
$inventory = [System.Collections.Generic.List[object]]::new()

function Test-NasPathRetry([string]$Path, [string]$Label) {
    $maxAttempts = 5
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        if (Test-Path -LiteralPath $Path) {
            if ($attempt -gt 1) { Write-Output "NAS_PATH_PASS label=$Label attempt=$attempt/$maxAttempts path=$Path" }
            return $true
        }
        if ($attempt -lt $maxAttempts) {
            Write-Warning "NAS_PATH_RETRY label=$Label attempt=$attempt/$maxAttempts path=$Path"
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
    Write-Warning "NAS_PATH_MISSING label=$Label attempts=$maxAttempts path=$Path"
    return $false
}

for ($day = 1; $day -le $monthEnd.Day; $day++) {
    $date = Get-Date -Year $Year -Month $Month -Day $day
    $dateText = $date.ToString('yyyy-MM-dd')
    $ymd = $date.ToString('yyyyMMdd')
    $finalMat = "Z:\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP\$Year\$($date.ToString('yyyy_MM_dd')).mat"
    if (-not (Test-NasPathRetry $finalMat 'final_mat')) {
        $inventory.Add([pscustomobject]@{Date=$dateText;Status='missing_final_mat';ExitCode=$null})
        continue
    }
    # era5_real cannot be built without the corresponding hourly ERA5 MATs.
    # Treat absent coverage as an auditable source gap and continue the month.
    $era5DayDir = "Z:\ERA5\mat\$Year\$($date.ToString('MM'))\$($date.ToString('dd'))"
    if (-not (Test-NasPathRetry $era5DayDir 'era5_day_dir')) {
        $inventory.Add([pscustomobject]@{Date=$dateText;Status='missing_era5_mat';ExitCode=$null})
        continue
    }
    $tallSuccess = "F:\AER_SHARED_PIPELINE\products\tall\t_all\tall__ap-final-v1__era5-real__adapter-v1__qc-v1\$Year\$($date.ToString('MM'))\$($date.ToString('dd'))\_SUCCESS"
    $statsSuccess = "F:\AER_SHARED_PIPELINE\products\chapter5\calipso_stats\stats__ap-final-v1__era5-real__adapter-v1__qc-v1__stats-v1\$Year\$($date.ToString('MM'))\$($date.ToString('dd'))\_SUCCESS"
    $clearSuccess = "F:\AER_SHARED_PIPELINE\products\chapter5\clear_air_stats\clear__ap-final-v1__grid5deg__z60m__clear-v1\$Year\$($date.ToString('MM'))\$($date.ToString('dd'))\_SUCCESS"
    if ((Test-Path -LiteralPath $tallSuccess) -and
        (Test-Path -LiteralPath $statsSuccess) -and
        (Test-Path -LiteralPath $clearSuccess)) {
        $inventory.Add([pscustomobject]@{Date=$dateText;Status='complete_existing';ExitCode=0})
        continue
    }
    $log = Join-Path $logRoot ("day_${ymd}_matlab.log")
    $err = Join-Path $logRoot ("day_${ymd}_launcher.err")
    $env:CHAPTER5_BATCH_DATE = $dateText
    $cmd = "run('F:\AER_SHARED_PIPELINE\code\batch\run_chapter5_day_batch.m')"
    $args = "-logfile `"$log`" -batch `"$cmd`""
    $proc = Start-Process -FilePath $matlabExe -ArgumentList $args -RedirectStandardError $err -Wait -PassThru -WindowStyle Hidden
    Remove-Item Env:CHAPTER5_BATCH_DATE -ErrorAction SilentlyContinue
    $inventory.Add([pscustomobject]@{Date=$dateText;Status=if($proc.ExitCode -eq 0){'complete'}else{'failed'};ExitCode=$proc.ExitCode})
    if ($proc.ExitCode -ne 0) { break }
}
$inventory | Export-Csv -LiteralPath (Join-Path $runRoot 'date_inventory.csv') -NoTypeInformation -Encoding UTF8
if ($inventory.Where({$_.Status -eq 'failed'}).Count -gt 0) {
    throw 'One or more daily Chapter 5 builds failed. See date_inventory.csv and day launcher logs.'
}

$ym = '{0:D4}{1:D2}' -f $Year,$Month
$stageMat = Join-Path $stageRoot ("CHAPTER5_MAP_STATS_${ym}.mat")
$monthLog = Join-Path $logRoot ("month_${ym}_matlab.log")
$monthErr = Join-Path $logRoot ("month_${ym}_launcher.err")
$monthCmd = "try, addpath('F:\AER_SHARED_PIPELINE\code\functions','F:\AER_SHARED_PIPELINE\code\producers\chapter5','F:\AER_SHARED_PIPELINE\code\publishers'); build_chapter5_map_stats_month($Year,$Month,'$stageMat'); final=publish_chapter5_map_stats_month($Year,$Month,'$stageMat'); setenv('CHAPTER5_MAP_STATS_INPUT',final); setenv('CHAPTER5_OUTPUT_DIR','$plotRoot'); setenv('CHAPTER5_PLOT_LABEL','$($monthStart.ToString('yyyy-MM'))'); run('F:\AER_SHARED_PIPELINE\plots\chapter5\plot_chapter5_map_stats.m'); exit(0); catch ME, disp(getReport(ME,'extended','hyperlinks','off')); exit(1); end"
$monthArgs = "-logfile `"$monthLog`" -batch `"$monthCmd`""
$monthProc = Start-Process -FilePath $matlabExe -ArgumentList $monthArgs -RedirectStandardError $monthErr -Wait -PassThru -WindowStyle Hidden
if ($monthProc.ExitCode -ne 0) {
    throw "Monthly Chapter 5 map build failed with exit code $($monthProc.ExitCode)."
}
