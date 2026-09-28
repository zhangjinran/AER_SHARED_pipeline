$root = 'F:\AER_RETRA_CASE'
$date = '2022-06-01'
$outroot = Join-Path $root 'CCN_FULL_RERUN_20260821\day_20220601'
New-Item -ItemType Directory -Force -Path $outroot | Out-Null
$log = Join-Path $outroot 'worker.log'
for ($k=1; $k -le 29; $k++) {
    $od = Join-Path $outroot ('orbit_{0:D3}' -f $k)
    New-Item -ItemType Directory -Force -Path $od | Out-Null
    $mat = Join-Path $od 'CALIPSO_results_2022_06_01_hdf.mat'
    if ((Test-Path $mat) -and ((Get-Item $mat).Length -gt 0)) {
        Add-Content $log "SKIP orbit=$k"
        continue
    }
    $cmd = "addpath('$root'); build_calipso_step1_day('$date','hdf','HdfRoot','Z:\\05kmAP','ERA5Dir','$root\\ERA5_CACHE','OutputDir','$od','StartFile',$k,'MaxFiles',1)"
    $arg = "-batch `"$cmd`""
    $p = Start-Process -FilePath 'E:\tool\matlab2025a\bin\matlab.exe' -ArgumentList $arg -Wait -PassThru -WindowStyle Hidden
    $bytes = 0
    if (Test-Path $mat) { $bytes = (Get-Item $mat).Length }
    Add-Content $log "orbit=$k exit=$($p.ExitCode) bytes=$bytes"
}
Add-Content $log 'WORKERS_FINISHED'
