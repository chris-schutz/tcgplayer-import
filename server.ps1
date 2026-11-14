# TCG Import Builder - tiny local server
# Serves the app at http://localhost:8765 and relays card-data lookups to tcgcsv.com
# (tcgcsv doesn't allow direct browser requests, so this relay is what makes images work).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$port = 8765
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$page = Join-Path $root 'TCG Import Builder.html'
$cacheDir = Join-Path $root 'cache'
if (-not (Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir | Out-Null }
$exportDir = Join-Path $root 'exports'
if (-not (Test-Path $exportDir)) { New-Item -ItemType Directory -Path $exportDir | Out-Null }

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
try { $listener.Start() } catch {
  # an older copy is running: ask it to stop, then take over
  try { $q = New-Object System.Net.WebClient; $q.Headers['X-TCGIB'] = 'quit'; $q.DownloadString("http://localhost:$port/__quit") | Out-Null } catch {}
  Start-Sleep 2
  try { $listener.Start() } catch {
    Write-Host "Port $port is still in use by an older copy of the importer." -ForegroundColor Red
    Write-Host "Close any other 'TCG Import Builder' black windows, then run Start TCG Importer.bat again."
    Read-Host "Press Enter to close"; exit
  }
}
# tuck this window away (backup for when the .bat couldn't start it minimized)
try {
  Add-Type -Name Win -Namespace TcgIb -MemberDefinition '[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int n);'
  [TcgIb.Win]::ShowWindow([TcgIb.Win]::GetConsoleWindow(), 6) | Out-Null
} catch {}
Write-Host "TCG Import Builder running at http://localhost:$port/" -ForegroundColor Green
Write-Host "Leave this window open while you use it. Close it to stop."
Start-Process "http://localhost:$port/"

function Send($stream, [int]$code, [string]$type, [byte[]]$body) {
  $reason = @{200='OK';403='Forbidden';404='Not Found';502='Bad Gateway';400='Bad Request'}[$code]
  $hdr = "HTTP/1.1 $code $reason`r`nContent-Type: $type`r`nContent-Length: $($body.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $h = [Text.Encoding]::ASCII.GetBytes($hdr)
  $stream.Write($h, 0, $h.Length)
  if ($body.Length) { $stream.Write($body, 0, $body.Length) }
}

$web = New-Object System.Net.WebClient
while ($true) {
  $client = $listener.AcceptTcpClient()
  try {
    # Chrome opens spare "preconnect" sockets that never send anything; don't let them stall real requests
    $client.ReceiveTimeout = 2000
    $stream = $client.GetStream()
    $reader = New-Object System.IO.StreamReader($stream, [Text.Encoding]::ASCII, $false, 4096, $true)
    $line = $reader.ReadLine()
    $len = 0; $hostHdr = ''; $origin = ''; $marker = ''
    while (($h = $reader.ReadLine()) -ne $null -and $h -ne '') {
      if ($h -match '^Content-Length:\s*(\d+)') { $len = [int]$Matches[1] }
      elseif ($h -match '^Host:\s*(.+)$') { $hostHdr = $Matches[1].Trim().ToLower() }
      elseif ($h -match '^Origin:\s*(.+)$') { $origin = $Matches[1].Trim().ToLower() }
      elseif ($h -match '^X-TCGIB:\s*(.+)$') { $marker = $Matches[1].Trim() }
    }
    if (-not $line) { continue }
    $parts = $line.Split(' ')
    $path = [Uri]::UnescapeDataString($parts[1].Split('?')[0])

    # Security: only answer this app's own page. Other websites you visit can't read from,
    # write to, or stop this server (blocks DNS-rebinding and cross-site requests).
    $okHosts = @("localhost:$port", "127.0.0.1:$port")
    $okOrigins = @('', "http://localhost:$port", "http://127.0.0.1:$port")
    if ($okHosts -notcontains $hostHdr -or $okOrigins -notcontains $origin) {
      Send $stream 403 'text/plain' ([Text.Encoding]::UTF8.GetBytes('forbidden')); continue
    }

    if ($path -eq '/__quit' -and $marker -eq 'quit') {
      Send $stream 200 'text/plain' ([Text.Encoding]::UTF8.GetBytes('bye'))
      $client.Close(); $listener.Stop()
      Write-Host "A newer copy took over. This window can be closed."; exit
    }
    elseif ($path -eq '/exports-list') {
      # every exported batch, so the page can warn before the same cards are exported twice
      $items = @(Get-ChildItem -Path $exportDir -Filter *.csv -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | ForEach-Object {
        @{ name = $_.Name; t = [long](($_.LastWriteTimeUtc - [datetime]'1970-01-01').TotalMilliseconds); text = [IO.File]::ReadAllText($_.FullName) } })
      $json = if ($items.Count) { ConvertTo-Json -InputObject $items -Depth 3 -Compress } else { '[]' }
      Send $stream 200 'application/json' ([Text.Encoding]::UTF8.GetBytes($json))
    }
    elseif ($path -eq '/' -or $path -eq '/index.html') {
      Send $stream 200 'text/html; charset=utf-8' ([IO.File]::ReadAllBytes($page))
    }
    elseif ($parts[0] -eq 'POST' -and $origin -ne '' -and $path -match '^/save/([A-Za-z0-9_\-]+\.csv)$') {
      # body is base64 of the CSV; keeps byte/char counts identical
      $name = $Matches[1]
      $buf = New-Object char[] $len; $got = 0
      while ($got -lt $len) { $n = $reader.Read($buf, $got, $len - $got); if ($n -le 0) { break }; $got += $n }
      $bytes = [Convert]::FromBase64String((New-Object string($buf, 0, $got)))
      [IO.File]::WriteAllBytes((Join-Path $exportDir $name), $bytes)
      Write-Host "Saved exports\$name"
      Send $stream 200 'text/plain' ([Text.Encoding]::UTF8.GetBytes("exports\$name"))
    }
    elseif ($path -match '^/tcgsku/(\d+)$') {
      # SKU ids per product from TCGplayer's public product-details endpoint. SKU ids never change, so cache forever.
      $prodId = $Matches[1]
      $file = Join-Path $cacheDir "sku_$prodId.json"
      if (Test-Path $file) { $bytes = [IO.File]::ReadAllBytes($file) }
      else {
        try {
          $wc = New-Object System.Net.WebClient
          $wc.Encoding = [Text.Encoding]::UTF8
          $wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) TCG-Import-Builder/1.0'
          $wc.Headers['Accept'] = 'application/json'
          $wc.Headers['Origin'] = 'https://www.tcgplayer.com'
          $raw = $wc.DownloadString("https://mp-search-api.tcgplayer.com/v2/product/$prodId/details")
          $j = $raw | ConvertFrom-Json
          $slim = @{ productId = [int]$prodId; skus = @($j.skus) } | ConvertTo-Json -Depth 4 -Compress
          $bytes = [Text.Encoding]::UTF8.GetBytes($slim)
          [IO.File]::WriteAllBytes($file, $bytes)
        } catch {
          Send $stream 502 'text/plain' ([Text.Encoding]::UTF8.GetBytes("sku lookup failed: $($_.Exception.Message)")); continue
        }
      }
      Send $stream 200 'application/json' $bytes
    }
    elseif ($path -match '^/tcgcsv/tcgplayer/(categories|\d+/groups|\d+/\d+/products|\d+/\d+/prices)$') {
      $rel = $Matches[1]
      $file = Join-Path $cacheDir (($rel -replace '/', '_') + '.json')
      $maxAge = if ($rel -eq 'categories') { 30 } else { 1 }
      if ((Test-Path $file) -and ((Get-Date) - (Get-Item $file).LastWriteTime).TotalDays -lt $maxAge) {
        $bytes = [IO.File]::ReadAllBytes($file)
      } else {
        try {
          $web.Headers['User-Agent'] = 'TCG-Import-Builder/1.0'
          $bytes = $web.DownloadData("https://tcgcsv.com/tcgplayer/$rel")
          [IO.File]::WriteAllBytes($file, $bytes)
        } catch {
          if (Test-Path $file) { $bytes = [IO.File]::ReadAllBytes($file) }
          else { Send $stream 502 'text/plain' ([Text.Encoding]::UTF8.GetBytes('tcgcsv unavailable')); continue }
        }
      }
      Send $stream 200 'application/json' $bytes
    }
    else {
      Send $stream 404 'text/plain' ([Text.Encoding]::UTF8.GetBytes('not found'))
    }
  } catch {
    # an idle preconnect socket timing out is normal, so stay quiet about it
    $e = $_.Exception; while ($e.InnerException) { $e = $e.InnerException }
    if (-not ($e -is [System.IO.IOException] -or $e -is [System.Net.Sockets.SocketException])) {
      Write-Host "Request error: $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
  } finally {
    $client.Close()
  }
}
