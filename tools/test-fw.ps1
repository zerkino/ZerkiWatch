# tools/test-fw.ps1 - runs the REAL firewall functions of ZerkiWatch.bat on the CI runner (Windows PowerShell 5.1).
# Throw-away group + TEST-NET ranges (192.0.2.0/24, 198.51.100.0/24 are reserved for documentation): blocking them cuts nothing real.
# NEVER calls the real Set-ModeLocal (it would cut the runner's Internet). Prints timings. Exit 1 on any failure.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Numerics
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$m = [regex]::Match($t, '(?s)\$ModeFnSrc\s*=\s*@' + "'" + '\r?\n(.*?)\r?\n' + "'" + '@')
if (-not $m.Success) { Write-Host 'ModeFnSrc not found'; exit 1 }
$fnSrc = $m.Groups[1].Value
$Group = 'ZW-CI-TEST'
$LegacyGroups = @('ZW-CI-TEST-OLD')
$ExtraIPv4 = @()
$ExtraIPv6 = @()
function T([string]$k) { return $k }
function Tf([string]$k, [object[]]$a) { return $k }
. ([scriptblock]::Create($fnSrc))
$FwRuleOut = 'ZW-CI-TEST out'
$FwRuleIn = 'ZW-CI-TEST in'
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
function Time-It([string]$label, [scriptblock]$sb) { $sw = [Diagnostics.Stopwatch]::StartNew(); $r = & $sb; Write-Host ('{0,-46} {1,9:N1} ms' -f $label, $sw.Elapsed.TotalMilliseconds); return $r }
$rng = @('192.0.2.0-192.0.2.255', '198.51.100.0-198.51.100.255')
try {
    Remove-RulesFast
    Check 'start: INTERNET' ((Get-ModeFast) -eq 'INTERNET')
    $null = Time-It 'Set-ModeLocalFast (first call, 2 rules)' { Set-ModeLocalFast $rng }
    Check 'after local: Get-ModeFast = LOCAL' ((Get-ModeFast) -eq 'LOCAL')
    $cm = @(Get-NetFirewallRule -Group $Group -ErrorAction SilentlyContinue)
    Check 'NetSecurity cmdlets see 2 rules in the group' ($cm.Count -eq 2)
    Check 'both enabled and Block' (@($cm | Where-Object { ($_.Enabled -eq 'True') -and ($_.Action -eq 'Block') }).Count -eq 2)
    Check 'one outbound and one inbound' ((@($cm | Where-Object { $_.Direction -eq 'Outbound' }).Count -eq 1) -and (@($cm | Where-Object { $_.Direction -eq 'Inbound' }).Count -eq 1))
    Check 'profiles = Any' (@($cm | Where-Object { $_.Profile -eq 'Any' }).Count -eq 2)
    $af = @($cm | ForEach-Object { ($_ | Get-NetFirewallAddressFilter).RemoteAddress })
    Check 'remote ranges stored as given' ((($af | ForEach-Object { $_ }) -join ',') -match '192\.0\.2\.0')
    $null = Time-It 'Get-ModeFast (all rules enumerated)' { Get-ModeFast }
    $null = Time-It 'Set-ModeInternetFast' { Set-ModeInternetFast }
    Check 'after internet: Get-ModeFast = INTERNET' ((Get-ModeFast) -eq 'INTERNET')
    Check 'no rule left (cmdlets)' (@(Get-NetFirewallRule -Group $Group -ErrorAction SilentlyContinue).Count -eq 0)
    $null = Time-It 'Set-ModeLocalFast (second call)' { Set-ModeLocalFast $rng }
    $null = Time-It 'Set-ModeInternetFast (second call)' { Set-ModeInternetFast }
    # old group: two enabled rules created with the cmdlets must read as LOCAL and be removed by Remove-RulesFast
    1..2 | ForEach-Object { New-NetFirewallRule -DisplayName ('ZW-CI-TEST old ' + $_) -Group $LegacyGroups[0] -Direction Outbound -Action Block -RemoteAddress $rng[0] -Enabled True | Out-Null }
    Check 'legacy group with 2 enabled rules reads as LOCAL' ((Get-ModeFast) -eq 'LOCAL')
    Remove-RulesFast
    Check 'legacy rules removed by Remove-RulesFast' (@(Get-NetFirewallRule -Group $LegacyGroups[0] -ErrorAction SilentlyContinue).Count -eq 0)
    # the app runs this code in a background runspace
    $bg = @'
param($Group, $LegacyGroups, $ExtraIPv4, $ExtraIPv6, $FnSrc, $Rng)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Numerics
function T([string]$k) { return $k }
function Tf([string]$k, [object[]]$a) { return $k }
. ([scriptblock]::Create($FnSrc))
$FwRuleOut = 'ZW-CI-TEST out'
$FwRuleIn = 'ZW-CI-TEST in'
Set-ModeLocalFast $Rng
$m1 = Get-ModeFast
Set-ModeInternetFast
$m2 = Get-ModeFast
($m1 + ',' + $m2)
'@
    $ps = [powershell]::Create()
    [void]$ps.AddScript($bg).AddArgument($Group).AddArgument($LegacyGroups).AddArgument($ExtraIPv4).AddArgument($ExtraIPv6).AddArgument($fnSrc).AddArgument($rng)
    $h = $ps.BeginInvoke()
    $out = @($ps.EndInvoke($h))
    if ($ps.Streams.Error.Count -gt 0) { Write-Host ($ps.Streams.Error | Out-String) }
    Check 'works inside a background runspace (as in the app)' (($out.Count -gt 0) -and ([string]$out[0] -eq 'LOCAL,INTERNET'))
    $ps.Dispose()
    # FirewallEnabled(profile) must answer a boolean for the three profiles
    $pol = Get-FwPolicy
    foreach ($pt in @(1, 2, 4)) { Check ('FirewallEnabled(' + $pt + ') answers a boolean') ($pol.FirewallEnabled($pt) -is [bool]) }
    Check 'Get-DisabledProfiles runs' ($null -ne (Get-DisabledProfiles))
    # ranges: local addresses stay reachable, internet addresses are inside the blocked ranges
    $rg = @(Time-It 'Get-LocalOnlyRanges' { Get-LocalOnlyRanges })
    Check 'Get-LocalOnlyRanges returns IPv4 and IPv6 ranges' ($rg.Count -ge 8)
    function To-U32([string]$ip) { $b = [System.Net.IPAddress]::Parse($ip).GetAddressBytes(); return ([uint64]$b[0] * 16777216 + [uint64]$b[1] * 65536 + [uint64]$b[2] * 256 + [uint64]$b[3]) }
    function In-Ranges([string]$ip, $ranges) {
        $x = To-U32 $ip
        foreach ($r in $ranges) {
            if ($r -match ':') { continue }
            $p = $r.Split('-'); $a = To-U32 $p[0]; $b = $a; if ($p.Count -gt 1) { $b = To-U32 $p[1] }
            if (($x -ge $a) -and ($x -le $b)) { return $true }
        }
        return $false
    }
    foreach ($ip in @('10.1.2.3', '192.168.1.1', '127.0.0.1', '169.254.1.1', '172.16.0.1', '172.31.255.255', '224.0.0.251', '239.255.255.250')) { Check ('stays reachable: ' + $ip) (-not (In-Ranges $ip $rg)) }
    foreach ($ip in @('1.1.1.1', '8.8.8.8', '93.184.216.34', '172.15.255.255', '172.32.0.0', '192.169.0.1', '100.64.0.1')) { Check ('is blocked: ' + $ip) (In-Ranges $ip $rg) }
} finally {
    try { Remove-RulesFast } catch { }
    Get-NetFirewallRule -Group 'ZW-CI-TEST' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    Get-NetFirewallRule -Group 'ZW-CI-TEST-OLD' -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
}
if ($fail -gt 0) { Write-Host ('FIREWALL TEST FAILED: ' + $fail); exit 1 }
Write-Host 'FIREWALL TEST OK'
