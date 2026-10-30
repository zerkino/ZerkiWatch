# tools/check-csharp.ps1 - compiles every C# block of ZerkiWatch.bat ($xxxCode = @' ... '@) with Windows PowerShell 5.1 (C# 5 compiler).
# Without it a C# error only shows up on a user's PC. Single-quoted pieces on purpose: in "..." the text \$(...) would be a PowerShell sub-expression.
# $refs = the extra assemblies the app passes to Add-TypeCached for each block (a block that is not listed is compiled with none).
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$refs = @{ nativeCode = @(); hkCode = @('System.Windows.Forms'); themeCode = @('System.Windows.Forms', 'System.Drawing'); netCode = @('System.Core') }
$rx = '(?s)\$(\w+Code)\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@'
$bad = 0
$cnt = 0
foreach ($m in [regex]::Matches($t, $rx)) {
    $cnt++
    $name = $m.Groups[1].Value
    $dll = Join-Path $env:TEMP ($name + '.dll')
    $r = @()
    if ($refs.ContainsKey($name)) { $r = $refs[$name] }
    try {
        if ($r.Count -gt 0) { Add-Type -TypeDefinition $m.Groups[2].Value -ReferencedAssemblies $r -OutputAssembly $dll -OutputType Library }
        else { Add-Type -TypeDefinition $m.Groups[2].Value -OutputAssembly $dll -OutputType Library }
        Write-Host ($name + ': compiled OK')
    } catch { Write-Host ($name + ': ' + $_.Exception.Message); $bad++ }
}
if ($cnt -lt 4) { Write-Host ('expected at least 4 C# blocks, found ' + $cnt); $bad++ }
if ($bad -gt 0) { exit 1 }
