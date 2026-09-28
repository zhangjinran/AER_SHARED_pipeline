[CmdletBinding()]
param(
    [ValidateSet('legacy_reproduction','new_candidate')]
    [string]$Phase = 'legacy_reproduction',
    [string]$RunId = 'run_marine_prior_20260915_001',
    [string]$AttemptId = 'attempt_001',
    [string]$LegacyAttemptId = 'attempt_001',
    [string]$ProjectRoot = 'F:\AER_SHARED_PIPELINE',
    [string]$MatlabExe = 'matlab'
)

$ErrorActionPreference = 'Stop'
$runRoot = Join-Path $ProjectRoot (Join-Path 'runs' $RunId)
$codeRoot = Join-Path $ProjectRoot 'code'
$logRoot = Join-Path $runRoot 'logs\marine_prior'

New-Item -ItemType Directory -Force -Path $runRoot, $logRoot | Out-Null

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$matlabLog = Join-Path $logRoot ("{0}_{1}_{2}_matlab.log" -f $Phase, $AttemptId, $stamp)
$launcherOut = Join-Path $logRoot ("{0}_{1}_{2}_launcher.out.log" -f $Phase, $AttemptId, $stamp)
$launcherErr = Join-Path $logRoot ("{0}_{1}_{2}_launcher.err.log" -f $Phase, $AttemptId, $stamp)

$escapedCodeRoot = $codeRoot.Replace("'", "''")
$escapedRunRoot = $runRoot.Replace("'", "''")
$escapedAttempt = $AttemptId.Replace("'", "''")
$escapedLegacyAttempt = $LegacyAttemptId.Replace("'", "''")
$expr = "restoredefaultpath; addpath('$escapedCodeRoot'); addpath(fullfile('$escapedCodeRoot','priors')); rebuild_marine_prior('RunRoot','$escapedRunRoot','Phase','$Phase','AttemptId','$escapedAttempt','LegacyAttemptId','$escapedLegacyAttempt','ExecuteMopsmap',true);"

try {
    & $MatlabExe -logfile $matlabLog -batch $expr 1> $launcherOut 2> $launcherErr
    if ($LASTEXITCODE -ne 0) {
        throw "MATLAB exited with code $LASTEXITCODE. See $matlabLog and $launcherErr"
    }
}
catch {
    $_ | Out-File -LiteralPath $launcherErr -Append -Encoding utf8
    throw
}

Write-Output "STATUS=PASS"
Write-Output "RUN_ROOT=$runRoot"
Write-Output "MATLAB_LOG=$matlabLog"
