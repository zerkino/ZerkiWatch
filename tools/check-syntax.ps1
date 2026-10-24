# Parses the PowerShell part of ZerkiWatch.bat and Installer.bat and fails on syntax errors.
# Note: run it with Windows PowerShell 5.1 (the version the app really uses):  powershell -File tools\check-syntax.ps1
$root = Split-Path -Parent $PSScriptRoot
$bad = 0
foreach ($n in @('ZerkiWatch.bat', 'Installer.bat', 'Build-EXE.bat')) {
    $t = [System.IO.File]::ReadAllText((Join-Path $root $n), [System.Text.Encoding]::ASCII)
    $i = $t.IndexOf('#PS' + 'START')
    $code = $t.Substring($i + 8)
    $err = $null; $tok = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$tok, [ref]$err)
    if ($err.Count -gt 0) { $bad++; foreach ($e in $err) { Write-Host ($n + ': line ' + $e.Extent.StartLineNumber + ': ' + $e.Message) } } else { Write-Host ($n + ': OK') }
    if ($t -match '[^\x00-\x7F]') { Write-Host ($n + ': contains non-ASCII characters (must stay pure ASCII)'); $bad++ }
}
if ($bad -gt 0) { exit 1 }
