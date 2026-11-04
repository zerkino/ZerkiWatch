# tools/test-apps.ps1 - the per-application lists must show EVERY application that moved a byte (no speed threshold, no "top 5"),
# in a unit that keeps a few bytes readable, and the drawing must stay inside its card.
# Runs the REAL Format-Mbps / Format-AppRate / Convert-Rows / Update-Procs / Draw-Rows of ZerkiWatch.bat with a fake ETW snapshot
# (Windows PowerShell 5.1 on the CI runner; the drawing part is skipped where System.Drawing is not usable). Exit 1 on any failure.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
function Get-FnText([string]$name) {
    $m = [regex]::Match($t, '(?m)^function ' + [regex]::Escape($name) + '[ (]')
    if (-not $m.Success) { Write-Host ('function not found in ZerkiWatch.bat: ' + $name); exit 1 }
    $e = $t.IndexOf("`n}", $m.Index)
    if ($e -lt 0) { Write-Host ('end of function not found: ' + $name); exit 1 }
    return $t.Substring($m.Index, $e + 2 - $m.Index)
}
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }

foreach ($fn in @('Format-Mbps', 'Format-AppRate', 'Convert-Rows', 'Update-Procs', 'Draw-Rows')) { Invoke-Expression (Get-FnText $fn) }

# ---- fakes for what the functions call ----
$S = @{ EtwOk = $true; Apps = @(); Svcs = @(); AppSeen = @{}; AppHold = 15; SvcMap = @{}; SvcStamp = [DateTime]::UtcNow; SvcAsk = [DateTime]::UtcNow; SvcNative = $false }
$S.SvcMap[700] = (New-Object 'System.Collections.Generic.List[string]')
$S.SvcMap[700].Add('Fake Service')
function T([string]$k) { if ($k -eq 'app.system') { return 'Windows system' }; if ($k -eq 'app.others') { return 'Others' }; return $k }
function Tf([string]$k, [object[]]$a) { return ($k + ' ' + ($a -join ',')) }
function Get-AppLabel([int]$procId) { if ($procId -ge 9000) { return ('Process ' + $procId) }; return ('App ' + $procId) }
function Get-EtwRows { return $script:fakeRows }

# ---- 1) readable units ----
Check 'no traffic shows --' ((Format-AppRate 0) -eq '--')
Check '48 Mbps stays in Mbps' ((Format-AppRate 48) -eq ((48.0).ToString('0.0') + ' Mbps'))
Check '0.5 Mbps is shown as 500 kbps' ((Format-AppRate 0.5) -eq '500 kbps')
Check '0.00085 Mbps is shown as 850 bps' ((Format-AppRate 0.00085) -eq '850 bps')
Check 'one byte per second (8 bps) is readable' ((Format-AppRate 0.000008) -eq '8 bps')
Check 'a tiny rate never shows 0 bps' ((Format-AppRate 0.0000001) -eq '1 bps')
Check '0.9996 Mbps rounds up to Mbps, not to 1000 kbps' ((Format-AppRate 0.9996) -eq ((1.0).ToString('0.00') + ' Mbps'))
Check '0.9994 Mbps is 999 kbps' ((Format-AppRate 0.9994) -eq '999 kbps')

# ---- 2) every application that moved a byte is listed ----
$r = @()
$r += , @(100.0, 5000000.0, 1000000.0)    # 48 Mbps
$r += , @(101.0, 3.0, 0.0)                # 3 bytes only
$r += , @(102.0, 0.0, 0.0)                # nothing at all: must not be listed
$r += , @(9000.0, 100.0, 0.0)             # ended process
$r += , @(9001.0, 50.0, 0.0)              # another ended process: both go to one "Others" row
$r += , @(700.0, 2000.0, 0.0)             # service
$r += , @(4.0, 10.0, 0.0)                 # kernel
for ($p = 200; $p -lt 240; $p++) { $r += , @([double]$p, [double]($p * 10), 0.0) }   # 40 small applications
$script:fakeRows = $r
Update-Procs
$names = @($S.Apps | ForEach-Object { $_.n })
Check ('all 43 applications are listed (more than 5): ' + $S.Apps.Count) ($S.Apps.Count -eq 43)
Check 'the 3-byte application is listed' ($names -contains 'App 101')
Check 'its rate is readable: 24 bps' ((Format-AppRate ([double](@($S.Apps | Where-Object { $_.n -eq 'App 101' })[0].m))) -eq '24 bps')
Check 'the application with 0 byte is not listed' (-not ($names -contains 'App 102'))
Check 'ended processes are merged in one "Others" row' ((@($names | Where-Object { $_ -eq 'Others' }).Count -eq 1) -and (-not ($names -contains 'Process 9000')))
Check 'the busiest application comes first' ($names[0] -eq 'App 100')
$sortedOk = $true
for ($i = 1; $i -lt $S.Apps.Count; $i++) { if ([double]$S.Apps[$i].m -gt [double]$S.Apps[$i - 1].m) { $sortedOk = $false } }
Check 'the list is sorted, busiest first' $sortedOk
Check 'the service and the kernel are in the services list' (($S.Svcs.Count -eq 2) -and (@($S.Svcs | ForEach-Object { $_.n }) -contains 'Fake Service') -and (@($S.Svcs | ForEach-Object { $_.n }) -contains 'Windows system'))
$json = ConvertTo-Json -InputObject @{ apps = @($S.Apps); svc = @($S.Svcs) } -Compress -Depth 6
$back = ConvertFrom-Json $json
Check 'the iPhone JSON keeps all rows and tiny values' ((@($back.apps).Count -eq 43) -and (@($back.apps | Where-Object { ([double]$_.m) -gt 0 -and ([double]$_.m) -lt 0.0001 }).Count -ge 1))

# ---- 3) a row that went quiet stays 15 s with 0, then goes away ----
$script:fakeRows = @()
Update-Procs
Check 'quiet applications stay listed' ($S.Apps.Count -eq 43)
Check 'and show no rate (--)' ((@($S.Apps | Where-Object { [double]$_.m -gt 0 }).Count -eq 0) -and ((Format-AppRate ([double]$S.Apps[0].m)) -eq '--'))
foreach ($k in @($S.AppSeen.Keys)) { $S.AppSeen[$k] = [DateTime]::UtcNow.AddSeconds(-20) }
Update-Procs
Check 'after 15 s of silence the rows are gone' (($S.Apps.Count -eq 0) -and ($S.Svcs.Count -eq 0) -and ($S.AppSeen.Count -eq 0))
$script:fakeRows = $r
Update-Procs
Check 'the 60-row cap holds' ($S.Apps.Count -le 60)

# ---- 4) drawing: no error, nothing below the card limit, "+ N" line when rows do not fit ----
$canDraw = $true
try {
    Add-Type -AssemblyName System.Drawing
    $bmp = New-Object System.Drawing.Bitmap 600, 400
    $g = [System.Drawing.Graphics]::FromImage($bmp)
} catch { $canDraw = $false; Write-Host ('skip  drawing checks (System.Drawing is not usable here: ' + $_.Exception.Message + ')') }
# the drawing code sits in a string: where System.Drawing does not exist (Linux) the type names would break the compile of the whole script
$drawTests = @'
$fSmall = New-Object System.Drawing.Font('Segoe UI', [single]12, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fRow = New-Object System.Drawing.Font('Segoe UI', [single]12.67, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fRowV = New-Object System.Drawing.Font('Segoe UI Semibold', [single]12.67, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$bText = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$bMuted = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Gray)
$sfEll = New-Object System.Drawing.StringFormat
$sfEll.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
$sfEll.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
$sfRight = New-Object System.Drawing.StringFormat
$sfRight.Alignment = [System.Drawing.StringAlignment]::Far
$sfRight.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
function Get-Ov([int]$a) { return [System.Drawing.Color]::FromArgb($a, 255, 255, 255) }
$cApp = [System.Drawing.Color]::FromArgb(251, 146, 60)
function Test-Blank($bmp, [int]$y0, [int]$h, [int]$x0 = 0, [int]$w = 0) {
    if ($w -le 0) { $w = $bmp.Width }
    $rect = New-Object System.Drawing.Rectangle($x0, $y0, $w, $h)
    $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $len = $bd.Stride * $bd.Height
        $buf = New-Object byte[] $len
        [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $len)
    } finally { $bmp.UnlockBits($bd) }
    return [System.Collections.StructuralComparisons]::StructuralEqualityComparer.Equals($buf, (New-Object byte[] $len))
}
foreach ($n in @(1, 3, 8, 9, 11, 12, 13, 43, 60)) {
    $items = @()
    for ($i = 0; $i -lt $n; $i++) {
        $rate = [double](0.0001 * ($n - $i))
        if (($i % 4) -eq 3) { $rate = 0.0 }
        $items += @{ n = ('Application number ' + $i + ' with a rather long name to test the ellipsis'); m = $rate }
    }
    $g.Clear([System.Drawing.Color]::Transparent)
    $ok = $true
    try { Draw-Rows $g $items 20 20 $cApp 'none' 491 300 } catch { $ok = $false; Write-Host ('      ' + $_.Exception.Message) }
    Check ('Draw-Rows with ' + $n + ' rows: no error') $ok
    Check ('Draw-Rows with ' + $n + ' rows: nothing below the card limit') (Test-Blank $bmp 300 100)
    Check ('Draw-Rows with ' + $n + ' rows: something was drawn') (-not (Test-Blank $bmp 20 100))
}
# 43 rows in 280 px: 13 rows at 19 px (ending at y = 267) then the "+ N" line just under them
$items = @()
for ($i = 0; $i -lt 43; $i++) { $items += @{ n = ('App ' + $i); m = [double](0.001 * (43 - $i)) } }
$g.Clear([System.Drawing.Color]::Transparent)
Draw-Rows $g $items 20 20 $cApp 'none' 491 300
Check 'the "+ N" line is drawn under the last row that fits' (-not (Test-Blank $bmp 268 16 20 200))
# a short list keeps the roomy 26 px rows: the 3rd row starts at y = 72
$g.Clear([System.Drawing.Color]::Transparent)
Draw-Rows $g @(@{ n = 'A'; m = 1.0 }, @{ n = 'B'; m = 0.5 }, @{ n = 'C'; m = 0.25 }) 20 20 $cApp 'none' 491 300
Check 'a short list keeps the roomy rows' ((-not (Test-Blank $bmp 72 18 20 100)) -and (Test-Blank $bmp 100 100))
$g.Dispose(); $bmp.Dispose()
'@
if ($canDraw) { Invoke-Expression $drawTests }
if ($fail -gt 0) { Write-Host ('APPS TEST FAILED: ' + $fail); exit 1 }
Write-Host 'APPS TEST OK'
