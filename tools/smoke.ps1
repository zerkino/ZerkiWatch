# tools/smoke.ps1 - starts the REAL app on the CI runner, waits for the first refresh, fails on error lines, keeps log + screenshot
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $env:APPDATA 'ZerkiWatch'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$log = Join-Path $dir 'log.txt'
if (Test-Path -LiteralPath $log) { Remove-Item -LiteralPath $log -Force }
# any config line hides the first-run wizard; Perf=1 turns on the PERF log lines (added by LOT 0)
Set-Content -LiteralPath (Join-Path $dir 'config.txt') -Value @('Perf=1', 'Wizard=1') -Encoding ASCII
Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ""' + (Join-Path $root 'ZerkiWatch.bat') + '""') -WindowStyle Hidden
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 1
    if ((Test-Path -LiteralPath $log) -and ((Get-Content -LiteralPath $log -Raw) -match 'first refresh done')) { $ok = $true; break }
}
Start-Sleep -Seconds 65
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
try {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap($b.Width, $b.Height)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save((Join-Path $root 'smoke-screen.png'))
} catch { Write-Host ('screenshot failed: ' + $_.Exception.Message) }
$txt = ''
if (Test-Path -LiteralPath $log) { $txt = Get-Content -LiteralPath $log -Raw; Copy-Item -LiteralPath $log -Destination (Join-Path $root 'smoke-log.txt') }
Write-Host $txt
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*#PS*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
$errs = @($txt -split "`r?`n" | Where-Object { $_ -match 'FATAL|UI error|paint:|Update-Mon:|Update-Bar:|Remote:|Net job:' })
if ((-not $ok) -or ($errs.Count -gt 0)) { Write-Host ('SMOKE FAILED: started=' + $ok + ' errors=' + $errs.Count); exit 1 }
Write-Host 'SMOKE OK'
