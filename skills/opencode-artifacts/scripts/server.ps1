# Static server for Windows PowerShell 5.1+ / pwsh, using the built-in .NET HttpListener.
# 127.0.0.1 only (no admin rights needed), serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal.
# The site root itself is never served (404), so a stray index.html can't become a public listing.
param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][int]$Port)
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
$Secret = "$env:ARTIFACTS_SECRET".Trim()
$Public = $env:ARTIFACTS_PUBLIC -eq '1'
# Fail closed: a missing or malformed secret must never widen the served paths.
if (-not $Public -and $Secret -notmatch '^[0-9a-f]{64}$') {
  throw 'ERROR: ARTIFACTS_SECRET must be 64 lowercase hex chars (or set ARTIFACTS_PUBLIC=1)'
}
$Prefix = if ($Public) { '' } else { "/$Secret" }
$Types = @{ '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css'; '.js' = 'text/javascript'; '.json' = 'application/json'
  '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.webp' = 'image/webp'; '.csv' = 'text/csv' }

$l = [Net.HttpListener]::new()
$l.Prefixes.Add("http://127.0.0.1:$Port/")
$l.Start()
while ($l.IsListening) {
  $ctx = $l.GetContext(); $req = $ctx.Request; $res = $ctx.Response
  try {
    foreach ($h in @{ 'X-Content-Type-Options' = 'nosniff'; 'Referrer-Policy' = 'no-referrer'; 'Cache-Control' = 'no-store'; 'X-Robots-Tag' = 'noindex'; 'X-Frame-Options' = 'DENY'; 'Content-Security-Policy' = "frame-ancestors 'none'" }.GetEnumerator()) {
      $res.Headers[$h.Key] = $h.Value
    }
    $u = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
    if ($req.HttpMethod -ne 'GET' -and $req.HttpMethod -ne 'HEAD') { $res.StatusCode = 405; continue }
    if (-not $Public -and $u -eq $Prefix) { $res.StatusCode = 301; $res.Headers['Location'] = "$Prefix/"; continue }
    if (-not $u.StartsWith("$Prefix/")) { $res.StatusCode = 404; continue }
    $u = $u.Substring($Prefix.Length)
    if ($u -eq '/' -or $u -eq '') { $res.StatusCode = 404; continue }
    if ($u -match '(^|[\\/])\.') { $res.StatusCode = 404; continue }
    $f = [IO.Path]::GetFullPath((Join-Path $Root ($u.TrimStart('/') -replace '/', '\')))
    if (Test-Path -LiteralPath $f -PathType Container) {
      # Relative links only resolve correctly from the directory URL with a trailing slash.
      if (-not $u.EndsWith('/')) { $res.StatusCode = 301; $res.Headers['Location'] = "$($req.Url.AbsolutePath)/"; continue }
      $f = Join-Path $f 'index.html'
    }
    # Files directly in the site root are never served, so a stray listing stays private.
    if (-not $f.StartsWith("$Root\", [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetDirectoryName($f) -eq $Root -or -not (Test-Path -LiteralPath $f -PathType Leaf)) { $res.StatusCode = 404; continue }
    $ext = [IO.Path]::GetExtension($f).ToLower()
    $res.ContentType = if ($Types[$ext]) { $Types[$ext] } else { 'application/octet-stream' }
    $bytes = [IO.File]::ReadAllBytes($f)
    $res.ContentLength64 = $bytes.Length
    if ($req.HttpMethod -eq 'GET') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
  } catch { try { $res.StatusCode = 500 } catch {} }
  finally { try { $res.Close() } catch {} }
}
