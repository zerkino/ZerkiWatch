# Checks the language files:
#  - every key used by ZerkiWatch.bat exists in lang\fr.txt (reference language)
#  - every language file has exactly the same keys as fr.txt
#  - placeholders {0}, {1}... are the same in every language
#  - the embedded copy in ZerkiWatch.bat is up to date
# Exit code 1 when something is wrong.   Usage:  powershell -File tools\check-lang.ps1
$root = Split-Path -Parent $PSScriptRoot
$bat = [System.IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'), [System.Text.Encoding]::ASCII)
$bad = 0
function Read-Lang([string]$path) {
    $d = @{}
    foreach ($ln in [System.IO.File]::ReadAllLines($path, [System.Text.Encoding]::UTF8)) {
        $t = $ln.Trim()
        if (($t -eq '') -or $t.StartsWith('#') -or $t.StartsWith('[')) { continue }
        $i = $t.IndexOf('=')
        if ($i -gt 0) { $d[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1) }
    }
    return $d
}
$langs = @{}
foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt')) { $langs[$f.BaseName] = Read-Lang $f.FullName }
if (-not $langs.ContainsKey('fr')) { Write-Host 'lang\fr.txt is missing'; exit 1 }
$ref = $langs['fr']
$used = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($rx in @("\(Tf? '([A-Za-z0-9_.]+)'", "LG\['(p\.[A-Za-z0-9_.]+)'\]", "\{\{(p\.[A-Za-z0-9_.]+)\}\}", "tf\('(p\.[a-z_0-9]+)'", "\? '(p\.[a-z_]+)' : '(p\.[a-z_]+)'")) {
    foreach ($m in [regex]::Matches($bat, $rx)) {
        for ($g = 1; $g -lt $m.Groups.Count; $g++) { [void]$used.Add($m.Groups[$g].Value) }
    }
}
[void]$used.Remove('p.lang')
foreach ($k in $used) { if (-not $ref.ContainsKey($k)) { Write-Host ('MISSING in fr.txt: ' + $k); $bad++ } }
foreach ($k in $ref.Keys) { if ((-not $used.Contains($k)) -and ($k -ne 'lang.name')) { Write-Host ('Unused key in fr.txt: ' + $k) } }
foreach ($c in $langs.Keys) {
    if ($c -eq 'fr') { continue }
    $d = $langs[$c]
    foreach ($k in $ref.Keys) {
        if (-not $d.ContainsKey($k)) { Write-Host ($c + ': missing key ' + $k); $bad++; continue }
        $a = (([regex]::Matches($ref[$k], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object) -join '')
        $b = (([regex]::Matches($d[$k], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object) -join '')
        if ($a -ne $b) { Write-Host ($c + ': placeholders differ in ' + $k); $bad++ }
    }
    foreach ($k in $d.Keys) { if (-not $ref.ContainsKey($k)) { Write-Host ($c + ': unknown key ' + $k); $bad++ } }
}
# embedded copy up to date?
$cnt = 0
foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt')) {
    foreach ($ln in [System.IO.File]::ReadAllLines($f.FullName, [System.Text.Encoding]::UTF8)) {
        $t = $ln.Trim()
        if (($t -eq '') -or $t.StartsWith('#')) { continue }
        $cnt++
    }
}
$bi = $bat.IndexOf("`$langData = @'"); $be = $bat.IndexOf("'@", $bi + 10)
$emb = $bat.Substring($bi, $be - $bi).Split("`n").Count - 2
if ($emb -ne $cnt) { Write-Host ('Embedded data is out of date (' + $emb + ' vs ' + $cnt + ' lines). Run tools\embed-lang.ps1'); $bad++ }
# the $langHash line (start-up skips lang\*.txt files identical to the embedded copy) must match the files
$hm = [regex]::Match($bat, '(?m)^\$langHash = @\{(.*)\}\s*$')
if (-not $hm.Success) { Write-Host 'The $langHash line is missing in ZerkiWatch.bat. Run tools\embed-lang.ps1'; $bad++ }
else {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    foreach ($f in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt')) {
        $norm = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8).Replace("`r`n", "`n").Trim()
        $hh = ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($norm)))).Replace('-', '').Substring(0, 16).ToLower()
        if ($hm.Groups[1].Value -notmatch ("'" + $f.BaseName.ToLower() + "' = '" + $hh + "'")) { Write-Host ('$langHash is out of date for ' + $f.BaseName + '. Run tools\embed-lang.ps1'); $bad++ }
    }
}
foreach ($c in ($langs.Keys | Sort-Object)) { Write-Host ('  ' + $c + ': ' + $langs[$c].Count + ' keys') }
if ($bad -gt 0) { Write-Host ($bad.ToString() + ' problem(s).'); exit 1 }
Write-Host 'Language files OK.'
