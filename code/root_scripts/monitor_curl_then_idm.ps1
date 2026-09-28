$j = Get-Content 'F:\ERA5_DOWNLOAD\logs\result.json' -Raw | ConvertFrom-Json
$url = $j.asset.value.href
$log = 'F:\ERA5_DOWNLOAD\logs\curl_until_normal.log'
$idm = 'E:\tool\Internet.Download.Manager.中文免激活绿色版+v6.39.2.v3\IDM\IDMan.exe'
$dir = 'F:\ERA5_DOWNLOAD\data'
$name = 'ERA5_PL_R_Z_20070101_03_global_025_16lev.grib'
$good = 0
"START $(Get-Date -Format s) threshold=0.5MiB/s" | Out-File $log -Encoding utf8
while ($good -lt 2) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  curl.exe --max-time 60 -sS -L --range 0-1048575 -o NUL $url 2>> ($log + '.err')
  $sw.Stop()
  $speed = 1MB / [math]::Max($sw.Elapsed.TotalSeconds, 0.001) / 1MB
  $line = "$(Get-Date -Format s) speed=$([math]::Round($speed,3))MiB/s seconds=$([math]::Round($sw.Elapsed.TotalSeconds,1)) exit=$LASTEXITCODE"
  $line | Tee-Object -FilePath $log -Append
  if ($speed -ge 0.5) { $good++ } else { $good=0 }
  if ($good -lt 2) { Start-Sleep -Seconds 60 }
}
Start-Process -FilePath $idm -ArgumentList @('/d',$url,'/p',$dir,'/f',$name,'/n') -WindowStyle Hidden
"IDM_STARTED $(Get-Date -Format s)" | Tee-Object -FilePath $log -Append
