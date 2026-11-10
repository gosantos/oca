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

# cloudflared's metrics server answers /ready with 200 only while the tunnel is registered with Cloudflare.
function Ready($port) { try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://127.0.0.1:$port/ready").StatusCode -eq 200 } catch { $false } }

# Already running? reuse. A live process isn't enough: after sleep Cloudflare drops quick tunnels while cloudflared keeps running.
if ((Test-Path "$State\base") -and (Alive 'server') -and (Alive 'tunnel')) {
  if ((Test-Path "$State\metrics") -and (Ready (Get-Content "$State\metrics"))) {
    "URL=$(Get-Content "$State\url")"; "BASE=$(Get-Content "$State\base")"; "PORT=$(Get-Content "$State\port")"; "DIR=$(Get-Content "$State\dir")"; exit 0
  }
  [Console]::Error.WriteLine("WARNING: previous tunnel $(Get-Content "$State\url") expired; starting a new one. Links shared earlier no longer work.")
}
& (Join-Path $Here 'stop.ps1') | Out-Null

$cf = Get-Command cloudflared -ErrorAction SilentlyContinue
if (-not $cf) { 'ERROR: cloudflared not found (only hard dependency): winget install Cloudflare.cloudflared'; exit 2 }

# Random free port 30000-59999.
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
function RandBytes($n) { $b = [byte[]]::new($n); $rng.GetBytes($b); $b }
$used = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners().Port
do { $Port = 30000 + ([BitConverter]::ToUInt32((RandBytes 4), 0) % 30000) } while ($used -contains $Port)
do { $MPort = 30000 + ([BitConverter]::ToUInt32((RandBytes 4), 0) % 30000) } while (($used -contains $MPort) -or $MPort -eq $Port)

# 256 bits from the OS CSPRNG as hex: path prefix that must be known to reach anything (everything else is 404).
$Secret = if ($Public) { '' } else { -join ((RandBytes 32) | ForEach-Object { $_.ToString('x2') }) }
if ($Public) { [Console]::Error.WriteLine('WARNING: -Public serves without a secret path; anyone with the hostname can read the whole site folder.') }

$ps = (Get-Process -Id $PID).Path
$env:ARTIFACTS_SECRET = $Secret
# The servers fail closed unless the secret is 64 hex chars; public mode has to be stated explicitly.
$env:ARTIFACTS_PUBLIC = if ($Public) { '1' } else { '0' }
$srv = Start-Process -FilePath $ps -WindowStyle Hidden -PassThru `
  -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Here\server.ps1`"", '-Root', "`"$Dir`"", '-Port', $Port `
  -RedirectStandardOutput "$State\server.log" -RedirectStandardError "$State\server.err"
Remove-Item Env:ARTIFACTS_SECRET, Env:ARTIFACTS_PUBLIC
$srv.Id | Set-Content "$State\server.pid"
Start-Sleep -Milliseconds 800

# Quick tunnel: outbound-only, no inbound ports opened, random trycloudflare.com hostname.
$log = "$State\tunnel.log"
$tun = Start-Process -FilePath $cf.Source -WindowStyle Hidden -PassThru `
  -ArgumentList 'tunnel', '--no-autoupdate', '--metrics', "127.0.0.1:$MPort", '--url', "http://127.0.0.1:$Port" `
  -RedirectStandardOutput "$State\tunnel.out" -RedirectStandardError $log
$tun.Id | Set-Content "$State\tunnel.pid"
$Url = $null
for ($i = 0; $i -lt 60 -and -not $Url; $i++) {
  Start-Sleep -Milliseconds 500
  if (Test-Path $log) { $m = Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' | Select-Object -First 1; if ($m) { $Url = $m.Matches[0].Value } }
}
if (-not $Url) { 'ERROR: tunnel did not come up'; Get-Content $log -Tail 20; exit 4 }
for ($i = 0; $i -lt 40 -and -not (Ready $MPort); $i++) { Start-Sleep -Milliseconds 500 }

$Base = if ($Secret) { "$Url/$Secret" } else { $Url }
$Url | Set-Content "$State\url"; $Base | Set-Content "$State\base"; $Port | Set-Content "$State\port"; $MPort | Set-Content "$State\metrics"; $Dir | Set-Content "$State\dir"
"URL=$Url"; "BASE=$Base"; "PORT=$Port"; "DIR=$Dir"; 'RUNTIME=powershell'
