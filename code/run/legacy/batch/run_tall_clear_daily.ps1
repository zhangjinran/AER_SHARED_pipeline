param(
    [Parameter(Mandatory=$true)][datetime]$StartDate,
    [Parameter(Mandatory=$true)][datetime]$EndDate,
    [string]$RunId = ('produce\run_tall_clear_' + (Get-Date -Format 'yyyyMMdd_HHmmss')),
    [string]$MatlabExe = 'E:\tool\matlab2025a\bin\matlab.exe'
)

$ErrorActionPreference = 'Stop'
$root = 'F:\AER_SHARED_PIPELINE'
$code = Join-Path $root 'code'
if ($RunId -notmatch '^produce[\\/]run_[A-Za-z0-9_-]+$') {
    if ($RunId -match '^[A-Za-z0-9_-]+$') { $RunId = "produce\$RunId" }
    else { throw 'RunId must be produce\run_<id> (or a bare run_<id>, which is placed under produce).' }
}
$RunId = $RunId -replace '/', '\'
$runRoot = Join-Path $root ('runs\' + $RunId)
$logRoot = Join-Path $runRoot 'logs\tall_clear'
$inventoryPath = Join-Path $runRoot 'date_inventory.csv'
if ($StartDate.Date -gt $EndDate.Date) { throw 'StartDate must not be later than EndDate.' }
if (-not (Test-Path -LiteralPath $MatlabExe -PathType Leaf)) { throw "MATLAB executable not found: $MatlabExe" }
if (Test-Path -LiteralPath $runRoot) { throw "Run directory already exists; choose a new RunId: $runRoot" }
New-Item -ItemType Directory -Path $logRoot -Force | Out-Null

$rows = [System.Collections.Generic.List[object]]::new()
function Test-Product([string]$Dir, [string]$MatName) {
    foreach ($name in @($MatName, 'manifest.txt', 'input_inventory.csv', '_SUCCESS')) {
        $path = Join-Path $Dir $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        if ((Get-Item -LiteralPath $path).Length -le 0) { return $false }
    }
    return $true
}
function Test-NasFile([string]$Path) {
    for ($attempt=1; $attempt -le 5; $attempt++) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) { return $true }
        if ($attempt -lt 5) { Start-Sleep -Seconds (2 * $attempt) }
    }
    return $false
}
function Save-Status([string]$Date, [string]$Status, [string]$Detail, [object]$ExitCode) {
    $script:rows.Add([pscustomobject]@{Date=$Date;Status=$Status;Detail=$Detail;ExitCode=$ExitCode})
    $script:rows | Export-Csv -LiteralPath $script:inventoryPath -NoTypeInformation -Encoding UTF8
    Write-Output "DATE=$Date STATUS=$Status DETAIL=$Detail"
}

for ($date=$StartDate.Date; $date -le $EndDate.Date; $date=$date.AddDays(1)) {
    $iso = $date.ToString('yyyy-MM-dd')
    $ymd = $date.ToString('yyyyMMdd')
    $yyyy = $date.ToString('yyyy')
    $mm = $date.ToString('MM')
    $dd = $date.ToString('dd')
    $finalMat = "Z:\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP\$yyyy\$($date.ToString('yyyy_MM_dd')).mat"
    $era5Dir = "Z:\ERA5\mat\$yyyy\$mm\$dd"
    $tallDir = Join-Path $root "products\tall\t_all\tall__ap-final-v1__era5-real__adapter-v1__qc-v1\$yyyy\$mm\$dd"
    $clearDir = Join-Path $root "products\chapter5\clear_air_stats\clear__ap-final-v1__grid5deg__z60m__clear-v1\$yyyy\$mm\$dd"
    $tallName = "T_all_$ymd.mat"
    $clearName = "CLEAR_AIR_STATS_$ymd.mat"
    $tallOk = Test-Product $tallDir $tallName
    $clearOk = Test-Product $clearDir $clearName
    if ($tallOk -and $clearOk) { Save-Status $iso 'PASS_EXISTING' 'both formal products complete' 0; continue }
    if ((Test-Path -LiteralPath $tallDir) -and -not $tallOk) { Save-Status $iso 'BLOCKED' 'incomplete T_all formal directory' $null; continue }
    if ((Test-Path -LiteralPath $clearDir) -and -not $clearOk) { Save-Status $iso 'BLOCKED' 'incomplete CLEAR_AIR_STATS formal directory' $null; continue }
    if (-not (Test-NasFile $finalMat)) { Save-Status $iso 'SKIPPED' 'missing Final CALIPSO MAT' $null; continue }
    if (-not (Test-Path -LiteralPath $era5Dir -PathType Container)) { Save-Status $iso 'SKIPPED' 'missing ERA5 day directory' $null; continue }
    $missingHours = @()
    for ($hour=0; $hour -lt 24; $hour++) {
        $hourFile = Join-Path $era5Dir ('ERA5_{0}_{1:D2}.mat' -f $ymd,$hour)
        if (-not (Test-NasFile $hourFile)) { $missingHours += $hour }
    }
    if ($missingHours.Count -gt 0) { Save-Status $iso 'SKIPPED' ('missing ERA5 hours: ' + ($missingHours -join ',')) $null; continue }

    $log = Join-Path $logRoot "day_${ymd}_matlab.log"
    $out = Join-Path $logRoot "day_${ymd}_launcher.out.log"
    $err = Join-Path $logRoot "day_${ymd}_launcher.err.log"
    $env:TALL_CLEAR_BATCH_DATE = $iso
    $matlabCode = "try, cd('$root'); restoredefaultpath; addpath('$code\config','-begin'); addpath('$code\root_scripts','-begin'); addpath('$code\producers\chapter5','-begin'); addpath('$code\producers\t_all','-begin'); addpath('$code\functions','-begin'); addpath('$code\publishers','-begin'); clear get_ERA5_meta build_calipso_step1_day; assert(strcmpi(which('get_ERA5_meta'),fullfile('$code','functions','get_ERA5_meta.m')),'Wrong ERA5 meta adapter on path'); assert(strcmpi(which('build_calipso_step1_day'),fullfile('$code','root_scripts','build_calipso_step1_day.m')),'Wrong CALIPSO step-1 adapter on path'); d=getenv('TALL_CLEAR_BATCH_DATE'); dt=datetime(d,'InputFormat','yyyy-MM-dd'); yy=datestr(dt,'yyyy'); mm=datestr(dt,'mm'); dd=datestr(dt,'dd'); ymd=datestr(dt,'yyyymmdd'); cfg=data_roots(); ap=fullfile(cfg.CALIPSO_AP_ROOT,yy,[datestr(dt,'yyyy_mm_dd') '.mat']); td=fullfile(cfg.SHARED_TALL_ROOT,'tall__ap-final-v1__era5-real__adapter-v1__qc-v1',yy,mm,dd); cd=fullfile(cfg.PROJECT_ROOT,'products','chapter5','clear_air_stats','clear__ap-final-v1__grid5deg__z60m__clear-v1',yy,mm,dd); if ~isfile(fullfile(td,'_SUCCESS')), candidate=build_shared_tall_day(d,'era5_real'); s=load_with_nas_retry(candidate,'T_all'); assert(height(s.T_all)>0 && nnz(isfinite(s.T_all.RH))>0,'T_all gate failed'); clear s; publish_shared_tall_day(d,'era5_real'); end; if ~isfile(fullfile(cd,'_SUCCESS')), stage=fullfile(cfg.PROJECT_ROOT,'products','chapter5','clear_air_stats','clear__ap-final-v1__grid5deg__z60m__clear-v1','_staging',yy,mm,dd,['CLEAR_AIR_STATS_' ymd '.mat']); build_clear_air_stats_day(d,ap,stage); publish_clear_air_stats_day(d,stage,ap); end; fprintf('TALL_CLEAR_DAY_DONE date=%s\n',d); catch ME, disp(getReport(ME,'extended','hyperlinks','off')); exit(1); end"
    try {
        $args = "-logfile `"$log`" -batch `"$matlabCode`""
        $proc = Start-Process -FilePath $MatlabExe -ArgumentList $args -RedirectStandardOutput $out -RedirectStandardError $err -Wait -PassThru -WindowStyle Hidden
        $exitCode = $proc.ExitCode
    } finally {
        Remove-Item Env:TALL_CLEAR_BATCH_DATE -ErrorAction SilentlyContinue
    }
    $tallOk = Test-Product $tallDir $tallName
    $clearOk = Test-Product $clearDir $clearName
    if ($exitCode -eq 0 -and $tallOk -and $clearOk) {
        Save-Status $iso 'PASS' 'both formal products complete' $exitCode
    } else {
        Save-Status $iso 'FAILED' "T_all=$tallOk CLEAR_AIR_STATS=$clearOk; see $log" $exitCode
        break
    }
}
