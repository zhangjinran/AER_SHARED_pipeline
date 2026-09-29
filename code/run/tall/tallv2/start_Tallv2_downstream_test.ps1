$ErrorActionPreference='Stop'
$root='F:\AER_SHARED_PIPELINE';$run=Join-Path $root 'runs\produce\run_20070101_Tallv2_pipeline_001'
$logs=Join-Path $run 'logs';New-Item -ItemType Directory -Force -Path $logs|Out-Null
$source=Join-Path $root 'runs\produce\run_tall_geotime_fix_20260928_001\candidate_era5_real\20070101\CALIPSO_results_2007_01_01_mat.mat'
$gate=Join-Path (Split-Path $source) 'candidate_gate.txt'
$target=Join-Path $root 'products\tall\t_all_v2\tall__ap-final-v1__era5-real__geotime-v2__qc-v1\2007\01\01'
if(-not (Test-Path -LiteralPath (Join-Path $target '_SUCCESS'))){
 if(Test-Path -LiteralPath $target){throw 'Incomplete target; inspect instead of overwriting'}
 $g=Get-Content -LiteralPath $gate -Raw
 if($g -notmatch 'rows=882444' -or $g -notmatch 'RH_finite=761849' -or $g -notmatch 'geolocation=native-profile-center-v2'){throw 'Candidate gate mismatch'}
 if(-not (Test-Path -LiteralPath (Join-Path $root 'runs\produce\run_tall_geotime_fix_20260928_001\sample_gate_PASS.txt'))){throw 'Sample gate absent'}
 if((Get-Item -LiteralPath $source).Length -le 0){throw 'Empty candidate'}
 New-Item -ItemType Directory -Path $target -Force | Out-Null
 $raw='Z:\CALIPSO_MAT_FINAL\CHAPTER5_AP\05kmAP\2007\2007_01_01.mat'
 @([pscustomobject]@{path=$raw;role='global_APro'},[pscustomobject]@{path='Z:\ERA5\mat\2007\01\01';role='ERA5_hourly'},[pscustomobject]@{path=$gate;role='candidate_gate'})|Export-Csv -LiteralPath (Join-Path $target 'input_inventory.csv') -NoTypeInformation
 @('product_key=tall__ap-final-v1__era5-real__geotime-v2__qc-v1','date=2007-01-01','rows=882444','RH_finite=761849','RH_NaN=120595','geolocation=native-profile-center-v2','leapsecond_adjustment=not_applied_user_accepted','status=PASS')|Set-Content -LiteralPath (Join-Path $target 'manifest.txt')
 # Explicit same-volume move: no second large MAT copy.
 Move-Item -LiteralPath $source -Destination (Join-Path $target 'T_all_20070101.mat')
 'PASS'|Set-Content -LiteralPath (Join-Path $target '_SUCCESS')
}
'TALLV2_PUBLISHED'|Write-Output
$failures=@()
foreach($stage in @('ccn','clear','chapter5','chapter4')){
 $active=Get-CimInstance Win32_Process -Filter "Name='MATLAB.exe'"|Where-Object {$_.CommandLine -like '*run_Tallv2_downstream_test*'}
 if($active){throw 'Duplicate downstream MATLAB detected'}
 $category=switch($stage){'clear'{'produce'} default{$stage}}
 $leaf=if($stage -eq 'clear'){'run_20070101_Tallv2_clear_001'}else{'run_20070101_Tallv2_001'}
 $stageLogs=Join-Path $root "runs\$category\$leaf\logs";New-Item -ItemType Directory -Force -Path $stageLogs|Out-Null
 $stamp=Get-Date -Format yyyyMMdd_HHmmss;$base=Join-Path $stageLogs "${stage}_Tallv2_$stamp"
 "START $stage $(Get-Date -Format o)"|Add-Content (Join-Path $logs 'progress_Tallv2.log')
 $expr="restoredefaultpath; cd('F:/AER_SHARED_PIPELINE'); addpath('F:/AER_SHARED_PIPELINE/code/run/tall/tallv2'); run_Tallv2_downstream_test('$stage');"
 $p=Start-Process 'E:\tool\matlab2025a\bin\matlab.exe' -WorkingDirectory $root -WindowStyle Hidden -ArgumentList @('-batch',('"'+$expr+'"'),'-logfile',('"'+$base+'_matlab.log"')) -RedirectStandardOutput ($base+'.out.log') -RedirectStandardError ($base+'.err.log') -PassThru
 $p.WaitForExit();$code=$p.ExitCode
 $log=if(Test-Path -LiteralPath ($base+'_matlab.log')){Get-Content -LiteralPath ($base+'_matlab.log') -Raw}else{''}
 if($code -ne 0 -or $log -notmatch "Tallv2_STAGE_COMPLETE $stage"){$failures+=$stage;"FAILED $stage exit=$code log=$base"|Add-Content (Join-Path $logs 'progress_Tallv2.log')}
 else{"PASS $stage $(Get-Date -Format o)"|Add-Content (Join-Path $logs 'progress_Tallv2.log')}
}
if($failures.Count){throw "Downstream failures: $($failures -join ',')"}
'ALL_TALLV2_TESTS_COMPLETE'|Add-Content (Join-Path $logs 'progress_Tallv2.log')
