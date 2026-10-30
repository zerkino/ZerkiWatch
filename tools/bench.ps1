# tools/bench.ps1 - run by the "bench" workflow on windows-latest (Windows PowerShell 5.1). Prints ms per run.
function Measure-Ms([string]$label, [scriptblock]$sb, [int]$n = 1) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    for ($i = 0; $i -lt $n; $i++) { $null = & $sb }
    $sw.Stop()
    Write-Host ('{0,-60} {1,10:N1} ms/run' -f $label, ($sw.Elapsed.TotalMilliseconds / $n))
}
Write-Host ('PowerShell ' + $PSVersionTable.PSVersion + ' | ' + [Environment]::OSVersion.VersionString + ' | CPUs=' + [Environment]::ProcessorCount)
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$code = $t.Substring($t.IndexOf('#PS' + 'START') + 8)
Add-Type -AssemblyName System.Drawing
Measure-Ms 'parse the whole script (AST)' { $e = $null; $k = $null; [void][System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$k, [ref]$e) } 3

# --- languages: the loader of the base commit (functions between "function ConvertFrom-LangEsc" and "# LANGDATA BEGIN") ---
$la = $t.IndexOf('function ConvertFrom-LangEsc'); $lb = $t.IndexOf('# LANGDATA BEGIN')
$ga = $t.IndexOf("`$langData = @'"); $gb = $t.IndexOf("'@", $ga + 20)
if (($la -ge 0) -and ($lb -gt $la) -and ($ga -gt 0)) {
    $langData = $t.Substring($ga + 15, $gb - ($ga + 15))
    $LangDb = @{}
    Invoke-Expression $t.Substring($la, $lb - $la)
    Measure-Ms 'languages: embedded text, current loader' { $LangDb.Clear(); Add-LangLines ($langData -split "`n") '' }
    Measure-Ms 'languages: shipped lang\*.txt (read twice today), same loader' {
        $LangDb.Clear()
        foreach ($lf in @(Get-ChildItem -LiteralPath (Join-Path $root 'lang') -Filter '*.txt')) { Add-LangLines ([System.IO.File]::ReadAllLines($lf.FullName, [System.Text.Encoding]::UTF8)) ($lf.BaseName.ToLower()) }
    }
}

# --- history: the Load-History loop on 10 080 synthetic lines (7 days) ---
$invc = [System.Globalization.CultureInfo]::InvariantCulture
$histEpoch = [DateTime]'2020-01-01'
function Get-MinIdx([DateTime]$d) { return [long][math]::Floor(($d - $histEpoch).TotalMinutes) }
$hl = New-Object System.Collections.ArrayList
$h0 = (Get-Date).AddDays(-6.5)
for ($m = 0; $m -lt 10080; $m++) { [void]$hl.Add($h0.AddMinutes($m).ToString('yyyyMMddHHmm', $invc) + ',12.345,1.234,23.4,45.6,7.8,123456,23456') }
$hlines = $hl.ToArray()
Measure-Ms 'history: Load-History loop, 10 080 lines' {
    $mem = New-Object System.Collections.ArrayList
    $cut = (Get-Date).AddDays(-7)
    foreach ($ln in $hlines) {
        $p = $ln.Split(',')
        if ($p.Count -lt 8) { continue }
        try {
            $dt = [DateTime]::ParseExact($p[0], 'yyyyMMddHHmm', $invc)
            if ($dt -lt $cut) { continue }
            $rec = New-Object 'double[]' 8
            $rec[0] = [double](Get-MinIdx $dt)
            for ($i = 1; $i -lt 8; $i++) { $rec[$i] = [double]::Parse($p[$i], $invc) }
            [void]$mem.Add($rec)
        } catch { }
    }
}

# --- painting ---
Measure-Ms 'New-Object System.Drawing.PointF x 20 000' { for ($i = 0; $i -lt 20000; $i++) { $p = New-Object System.Drawing.PointF([single]$i, [single]2) } }
Measure-Ms '[System.Drawing.PointF]::new x 20 000' { for ($i = 0; $i -lt 20000; $i++) { $p = [System.Drawing.PointF]::new([single]$i, [single]2) } }
Measure-Ms 'New-Object SolidBrush + Dispose x 2 000' { for ($i = 0; $i -lt 2000; $i++) { $b = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Red); $b.Dispose() } }

# --- services (background job of the app) ---
Measure-Ms 'services: Get-CimInstance Win32_Service (running)' { Get-CimInstance -ClassName Win32_Service -Filter "State='Running'" | Out-Null } 3

# --- firewall on a throw-away group with TEST-NET ranges (NEVER the real ZerkiWatch rules) ---
$grp = 'ZW-BENCH'
$rng = @('192.0.2.0-192.0.2.255', '198.51.100.0-198.51.100.255')
Measure-Ms 'cmdlet  Get-NetFirewallRule -Group (first call)' { Get-NetFirewallRule -Group $grp -ErrorAction SilentlyContinue }
Measure-Ms 'cmdlet  create 2 rules + remove them' {
    1..2 | ForEach-Object { New-NetFirewallRule -DisplayName ('ZW bench ' + $_) -Group $grp -Direction Outbound -Action Block -RemoteAddress $rng -Enabled True | Out-Null }
    Get-NetFirewallRule -Group $grp | Remove-NetFirewallRule
}
Measure-Ms 'COM     enumerate all rules (mode check)' { $p = New-Object -ComObject HNetCfg.FwPolicy2; foreach ($r in $p.Rules) { $null = $r.Grouping } } 3
Measure-Ms 'COM     create 2 rules + remove them' {
    $p = New-Object -ComObject HNetCfg.FwPolicy2
    foreach ($d in @(@('ZW bench a', 2), @('ZW bench b', 1))) {
        $r = New-Object -ComObject HNetCfg.FWRule
        $r.Name = $d[0]; $r.Grouping = $grp; $r.Direction = $d[1]; $r.Action = 0; $r.Protocol = 256; $r.Profiles = 2147483647
        $r.RemoteAddresses = ($rng -join ','); $r.Enabled = $true
        $p.Rules.Add($r)
    }
    foreach ($n in 'ZW bench a', 'ZW bench b') { $p.Rules.Remove($n) }
} 3
Measure-Ms 'cmdlet  Get-NetRoute (Test-Box today)' { Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Out-Null }
Measure-Ms 'cmdlet  Clear-DnsClientCache (switch today)' { Clear-DnsClientCache -ErrorAction SilentlyContinue }
