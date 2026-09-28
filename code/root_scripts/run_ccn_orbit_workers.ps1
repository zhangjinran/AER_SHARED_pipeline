$root='F:\AER_RETRA_CASE'; $day=Join-Path $root 'CCN_FULL_RERUN_20260821\day_20220601'; $log=Join-Path $day 'ccn_workers.log';
for($k=1;$k -le 29;$k++){
 $in=Join-Path $day ('orbit_{0:D3}\CALIPSO_results_2022_06_01_hdf.mat' -f $k); $out=Join-Path $day ('orbit_{0:D3}\CCN_grid.mat' -f $k); if(!(Test-Path $in)){Add-Content $log "MISSING $k"; continue}; if((Test-Path $out)-and((Get-Item $out).Length -gt 0)){Add-Content $log "SKIP $k";continue};
 $cmd="addpath('$root\\函数'); process_one_orbit_CCN('$in','$out')"; $arg="-batch `"$cmd`""; $p=Start-Process -FilePath 'E:\tool\matlab2025a\bin\matlab.exe' -ArgumentList $arg -Wait -PassThru -WindowStyle Hidden; $sz=0;if(Test-Path $out){$sz=(Get-Item $out).Length};Add-Content $log "orbit=$k exit=$($p.ExitCode) bytes=$sz";
}
Add-Content $log 'CCN_WORKERS_FINISHED'
