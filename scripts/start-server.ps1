param(
  [int[]]$PreferredPorts = @(4173, 8080, 3000)
)

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($projectRoot))
$hash = -join ($hashBytes[0..7] | ForEach-Object { $_.ToString('x2') })
$statePath = Join-Path ([System.IO.Path]::GetTempPath()) "portfolio-local-server-$hash.json"

if (Test-Path $statePath) {
  $existingState = Get-Content $statePath -Raw | ConvertFrom-Json
  $existingProcess = Get-Process -Id $existingState.ProcessId -ErrorAction SilentlyContinue

  if ($null -ne $existingProcess) {
    Write-Output "Portfolio server is already running at http://127.0.0.1:$($existingState.Port)/"
    return
  }

  Remove-Item $statePath -Force -ErrorAction SilentlyContinue
}

$selectedPort = $null

foreach ($port in $PreferredPorts) {
  try {
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
    $probe.Start()
    $probe.Stop()
    $selectedPort = $port
    break
  } catch {
  }
}

if ($null -eq $selectedPort) {
  throw 'No available port found for the local portfolio server.'
}

$serveScript = Join-Path $PSScriptRoot 'serve-static.ps1'
$process = Start-Process -FilePath powershell.exe -ArgumentList @(
  '-NoProfile',
  '-ExecutionPolicy', 'Bypass',
  '-File', $serveScript,
  '-RootPath', $projectRoot,
  '-Port', $selectedPort
) -WindowStyle Hidden -PassThru

$state = [pscustomobject]@{
  ProcessId = $process.Id
  Port = $selectedPort
  RootPath = $projectRoot
  StartedAt = (Get-Date).ToString('o')
}

$state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
Write-Output "Serving $projectRoot at http://127.0.0.1:$selectedPort/"