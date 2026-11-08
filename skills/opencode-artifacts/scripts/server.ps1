# Static server for Windows PowerShell 5.1+ / pwsh, using the built-in .NET HttpListener.
# 127.0.0.1 only (no admin rights needed), serves only under /<ARTIFACTS_SECRET>/, no listing, no dotfiles, no traversal.
param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][int]$Port)
$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
$Secret = $env:ARTIFACTS_SECRET
$Prefix = if ($Secret) { "/$Secret" } else { '' }
$Types = @{ '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css'; '.js' = 'text/javascript'; '.json' = 'application/json'
  '.svg' = 'image/svg+xml'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.webp' = 'image/webp'; '.csv' = 'text/csv' }

$l = [Net.HttpListener]::new()
$l.Prefixes.Add("http://127.0.0.1:$Port/")
$l.Start()
while ($l.IsListening) {
  $ctx = $l.GetContext(); $req = $ctx.Request; $res = $ctx.Response
  try {
    foreach ($h in @{ 'X-Content-Type-Options' = 'nosniff'; 'Referrer-Policy' = 'no-referrer'; 'Cache-Control' = 'no-store'; 'X-Robots-Tag' = 'noindex' }.GetEnumerator()) {
      $res.Headers[$h.Key] = $h.Value
    }
    $u = [Uri]::UnescapeDataString($req.Url.AbsolutePath)
    if ($req.HttpMethod -ne 'GET' -and $req.HttpMethod -ne 'HEAD') { $res.StatusCode = 405; continue }
    if ($u -eq $Prefix) { $res.StatusCode = 301; $res.Headers['Location'] = "$Prefix/"; continue }
    if (-not $u.StartsWith("$Prefix/")) { $res.StatusCode = 404; continue }
    $u = $u.Substring($Prefix.Length)
    if ($u -match '(^|[\\/])\.') { $res.StatusCode = 404; continue }
    $f = [IO.Path]::GetFullPath((Join-Path $Root ($u.TrimStart('/') -replace '/', '\')))
    if (Test-Path -LiteralPath $f -PathType Container) { $f = Join-Path $f 'index.html' }
    if (-not $f.StartsWith("$Root\", [StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $f -PathType Leaf)) { $res.StatusCode = 404; continue }
    $ext = [IO.Path]::GetExtension($f).ToLower()
    $res.ContentType = if ($Types[$ext]) { $Types[$ext] } else { 'application/octet-stream' }
    $bytes = [IO.File]::ReadAllBytes($f)
    $res.ContentLength64 = $bytes.Length
    if ($req.HttpMethod -eq 'GET') { $res.OutputStream.Write($bytes, 0, $bytes.Length) }
  } catch { try { $res.StatusCode = 500 } catch {} }
  finally { try { $res.Close() } catch {} }
}
