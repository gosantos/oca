# Usage: publish.ps1 [-Public] [-Dir <path>]
# Serves Dir (default %TEMP%\opencode-artifacts\site) on 127.0.0.1:<random> and opens a Cloudflare quick tunnel.
param([switch]$Public, [string]$Dir)
$ErrorActionPreference = 'Stop'
$T = Join-Path ([IO.Path]::GetTempPath()) 'opencode-artifacts'
if (-not $Dir) { $Dir = Join-Path $T 'site' }
$State = Join-Path $T '.state'
New-Item -ItemType Directory -Force -Path $Dir, $State | Out-Null
$Dir = (Resolve-Path $Dir).Path
$Here = $PSScriptRoot
function Alive($name) { $p = Join-Path $State "$name.pid"; (Test-Path $p) -and (Get-Process -Id (Get-Content $p) -ErrorAction SilentlyContinue) }

# Already running? reuse.
if ((Test-Path "$State\base") -and (Alive 'server') -and (Alive 'tunnel')) {
  "URL=$(Get-Content "$State\url")"; "BASE=$(Get-Content "$State\base")"; "PORT=$(Get-Content "$State\port")"; "DIR=$(Get-Content "$State\dir")"; exit 0
}
& (Join-Path $Here 'stop.ps1') | Out-Null

$cf = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cf) { 'ERROR: cloudflared not found (only hard dependency): winget install Cloudflare.cloudflared'; exit 2 }

# Random free port 30000-59999.
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
function RandBytes($n) { $b = [byte[]]::new($n); $rng.GetBytes($b); $b }
$used = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port
do { $Port = 30000 + ([BitConverter]::ToUInt32((RandBytes 4), 0) % 30000) } while ($used -contains $Port)

# 256 bits from the OS CSPRNG as hex: path prefix that must be known to reach anything (everything else is 404).
$Secret = if ($Public) { '' } else { -join ((RandBytes 32) | ForEach-Object { $_.ToString('x2') }) }

$ps = (Get-Process -Id $PID).Path
$env:ARTIFACTS_SECRET = $Secret
$srv = Start-Process -FilePath $ps -WindowStyle Hidden -PassThru `
  -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Here\server.ps1`"", '-Root', "`"$Dir`"", '-Port', $Port `
  -RedirectStandardOutput "$State\server.log" -RedirectStandardError "$State\server.err"
Remove-Item Env:ARTIFACTS_SECRET
$srv.Id | Set-Content "$State\server.pid"
Start-Sleep -Milliseconds 800

# Quick tunnel: outbound-only, no inbound ports opened, random trycloudflare.com hostname.
$log = "$State\tunnel.log"
$tun = Start-Process -FilePath $cf.Source -WindowStyle Hidden -PassThru `
  -ArgumentList 'tunnel', '--no-autoupdate', '--url', "http://127.0.0.1:$Port" `
  -RedirectStandardOutput "$State\tunnel.out" -RedirectStandardError $log
$tun.Id | Set-Content "$State\tunnel.pid"
$Url = $null
for ($i = 0; $i -lt 60 -and -not $Url; $i++) {
  Start-Sleep -Milliseconds 500
  if (Test-Path $log) { $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1; if ($m) { $Url = $m.Matches[0].Value } }
}
if (-not $Url) { 'ERROR: tunnel did not come up'; Get-Content $log -Tail 20; exit 4 }

$Base = if ($Secret) { "$Url/$Secret" } else { $Url }
$Url | Set-Content "$State\url"; $Base | Set-Content "$State\base"; $Port | Set-Content "$State\port"; $Dir | Set-Content "$State\dir"
"URL=$Url"; "BASE=$Base"; "PORT=$Port"; "DIR=$Dir"; 'RUNTIME=powershell'
