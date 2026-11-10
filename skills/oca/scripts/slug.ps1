# Usage: slug.ps1 <name>   -> prints "<6hex>-<name>" and creates %TEMP%\oca\site\<6hex>-<name>\
# The 6 hex chars come from the OS CSPRNG, so an artifact path can't be guessed from its name.
param([Parameter(Mandatory)][string]$Name)
$ErrorActionPreference = 'Stop'
$Site = Join-Path (Join-Path ([IO.Path]::GetTempPath()) 'oca') 'site'
# Strip accents (ação -> acao), then anything outside a-z0-9 becomes a separator.
$Name = -join ($Name.Normalize([Text.NormalizationForm]::FormD).ToCharArray() |
  Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
$Name = ($Name.ToLowerInvariant() -creplace '[^a-z0-9]+', '-').Trim('-')
if (-not $Name) { throw 'ERROR: name has no a-z0-9 characters' }
New-Item -ItemType Directory -Force -Path $Site | Out-Null
# Same name -> same folder, so adding a page never breaks a link already shared.
$existing = Get-ChildItem -LiteralPath $Site -Directory -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match "^[0-9a-f]{6}-$([Regex]::Escape($Name))$" } | Select-Object -First 1
if ($existing) { $existing.Name; exit 0 }
$bytes = [byte[]]::new(3)
[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
$hex = -join ($bytes | ForEach-Object { $_.ToString('x2') })
New-Item -ItemType Directory -Force -Path (Join-Path $Site "$hex-$Name") | Out-Null
"$hex-$Name"
