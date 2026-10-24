# Embeds lang/*.txt into ZerkiWatch.bat (between "# LANGDATA BEGIN" and "# LANGDATA END").
# Run after editing any file in lang\:   powershell -ExecutionPolicy Bypass -File tools\embed-lang.ps1
# Non-ASCII characters are written as \uXXXX so that ZerkiWatch.bat stays pure ASCII.
$root = Split-Path -Parent $PSScriptRoot
$bat = Join-Path $root 'ZerkiWatch.bat'
$out = New-Object System.Collections.ArrayList
foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt' | Sort-Object Name)) {
    foreach ($ln in [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)) {
        if (($ln.Trim() -eq '') -or $ln.TrimStart().StartsWith('#')) { continue }
        $sb = New-Object System.Text.StringBuilder
        foreach ($ch in $ln.ToCharArray()) {
            if ([int]$ch -lt 128) { [void]$sb.Append($ch) } else { [void]$sb.Append('\u' + ([int]$ch).ToString('x4')) }
        }
        [void]$out.Add($sb.ToString())
    }
}
$text = [System.IO.File]::ReadAllText($bat, [System.Text.Encoding]::ASCII).Replace("`r`n", "`n")
$b = $text.IndexOf("# LANGDATA BEGIN`n")
$e = $text.IndexOf('# LANGDATA END')
if (($b -lt 0) -or ($e -lt 0)) { throw 'LANGDATA markers not found in ZerkiWatch.bat' }
$b = $b + "# LANGDATA BEGIN`n".Length
$new = $text.Substring(0, $b) + "`$langData = @'`n" + ($out -join "`n") + "`n'@`n" + $text.Substring($e)
[System.IO.File]::WriteAllBytes($bat, [System.Text.Encoding]::ASCII.GetBytes($new.Replace("`n", "`r`n")))
Write-Host ('Embedded ' + $out.Count + ' lines from lang\*.txt into ZerkiWatch.bat')
