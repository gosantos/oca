$State = Join-Path ([IO.Path]::GetTempPath()) 'opencode-artifacts\.state'
foreach ($p in 'tunnel', 'server') {
  $f = Join-Path $State "$p.pid"
  if (Test-Path $f) { Stop-Process -Id (Get-Content $f) -Force -ErrorAction SilentlyContinue; Remove-Item $f }
}
foreach ($f in 'url', 'base', 'port', 'dir', 'metrics') { Remove-Item (Join-Path $State $f) -ErrorAction SilentlyContinue }
'stopped'
