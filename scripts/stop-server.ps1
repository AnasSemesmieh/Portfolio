$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($projectRoot))
$hash = -join ($hashBytes[0..7] | ForEach-Object { $_.ToString('x2') })
$statePath = Join-Path ([System.IO.Path]::GetTempPath()) "portfolio-local-server-$hash.json"

if (-not (Test-Path $statePath)) {
  Write-Output 'No local portfolio server state file was found.'
  return
}

$state = Get-Content $statePath -Raw | ConvertFrom-Json
$process = Get-Process -Id $state.ProcessId -ErrorAction SilentlyContinue

if ($null -ne $process) {
  Stop-Process -Id $state.ProcessId -Force
  Write-Output "Stopped portfolio server on port $($state.Port)."
} else {
  Write-Output 'The local portfolio server was not running.'
}

Remove-Item $statePath -Force -ErrorAction SilentlyContinue