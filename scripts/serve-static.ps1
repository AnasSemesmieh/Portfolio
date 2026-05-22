param(
  [Parameter(Mandatory = $true)]
  [string]$RootPath,

  [Parameter(Mandatory = $true)]
  [int]$Port
)

$resolvedRoot = [System.IO.Path]::GetFullPath((Resolve-Path $RootPath).Path)
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()

$contentTypes = @{
  '.html' = 'text/html; charset=utf-8'
  '.css' = 'text/css; charset=utf-8'
  '.js' = 'application/javascript; charset=utf-8'
  '.json' = 'application/json; charset=utf-8'
  '.xml' = 'application/xml; charset=utf-8'
  '.txt' = 'text/plain; charset=utf-8'
  '.svg' = 'image/svg+xml'
  '.png' = 'image/png'
  '.jpg' = 'image/jpeg'
  '.jpeg' = 'image/jpeg'
  '.gif' = 'image/gif'
  '.webp' = 'image/webp'
  '.ico' = 'image/x-icon'
  '.pdf' = 'application/pdf'
}

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    $stream = $null
    $reader = $null

    try {
      $stream = $client.GetStream()
      $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)
      $requestLine = $reader.ReadLine()

      if ([string]::IsNullOrWhiteSpace($requestLine)) {
        continue
      }

      do {
        $line = $reader.ReadLine()
      } while ($null -ne $line -and $line -ne '')

      $parts = $requestLine.Split(' ')
      $rawPath = if ($parts.Length -ge 2) { $parts[1] } else { '/' }
      $relativePath = [Uri]::UnescapeDataString(($rawPath.Split('?')[0]).TrimStart('/').Replace('/', '\'))

      if ([string]::IsNullOrWhiteSpace($relativePath)) {
        $relativePath = 'index.html'
      }

      $targetPath = Join-Path $resolvedRoot $relativePath

      if ((Test-Path $targetPath) -and (Get-Item $targetPath).PSIsContainer) {
        $targetPath = Join-Path $targetPath 'index.html'
      }

      $fullPath = [System.IO.Path]::GetFullPath($targetPath)

      if (-not $fullPath.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $body = [System.Text.Encoding]::UTF8.GetBytes('Forbidden')
        $headers = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 403 Forbidden`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n")
        $stream.Write($headers, 0, $headers.Length)
        $stream.Write($body, 0, $body.Length)
        continue
      }

      if (-not (Test-Path $fullPath -PathType Leaf)) {
        $body = [System.Text.Encoding]::UTF8.GetBytes('Not Found')
        $headers = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n")
        $stream.Write($headers, 0, $headers.Length)
        $stream.Write($body, 0, $body.Length)
        continue
      }

      $extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
      $contentType = if ($contentTypes.ContainsKey($extension)) { $contentTypes[$extension] } else { 'application/octet-stream' }
      $body = [System.IO.File]::ReadAllBytes($fullPath)
      $headers = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n")
      $stream.Write($headers, 0, $headers.Length)
      $stream.Write($body, 0, $body.Length)
    } finally {
      if ($null -ne $reader) { $reader.Dispose() }
      if ($null -ne $stream) { $stream.Dispose() }
      $client.Close()
    }
  }
} finally {
  $listener.Stop()
}