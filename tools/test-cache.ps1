# tools/test-cache.ps1 - the helper-type cache must live in a folder that only SYSTEM and Administrators can write.
# Runs the REAL Get-CacheDir / Test-AdminOwned / Add-TypeCached of ZerkiWatch.bat on the CI runner (Windows PowerShell 5.1, elevated), in a temporary folder.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$t = [IO.File]::ReadAllText((Join-Path $root 'ZerkiWatch.bat'))
$a = $t.IndexOf('# Compiled helper types are cached as a DLL')
$b = $t.IndexOf("`n" + '$native = $false', $a)
if (($a -lt 0) -or ($b -lt 0)) { Write-Host 'cache code not found in ZerkiWatch.bat'; exit 1 }
$base = Join-Path ([IO.Path]::GetTempPath()) ('zwcache-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $base | Out-Null
$env:ProgramData = $base
Invoke-Expression $t.Substring($a, $b - $a)
$fail = 0
function Check([string]$what, [bool]$ok) { if ($ok) { Write-Host ('ok    ' + $what) } else { Write-Host ('FAIL  ' + $what); $script:fail++ } }
$cdir = Get-CacheDir
Check 'cache folder created' (($cdir -ne $null) -and (Test-Path -LiteralPath $cdir))
if ($cdir -ne $null) {
    $acl = (New-Object System.IO.DirectoryInfo($cdir)).GetAccessControl()
    $rules = @($acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]))
    $sids = @($rules | ForEach-Object { $_.IdentityReference.Value } | Sort-Object)
    Check 'inheritance from the parent is cut' $acl.AreAccessRulesProtected
    Check 'only Administrators and SYSTEM have access' (($sids -join ',') -eq 'S-1-5-18,S-1-5-32-544')
    Check 'owner is Administrators' ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -eq 'S-1-5-32-544')
    Check 'no rule grants access to Users / Everyone / Authenticated Users' (@($sids | Where-Object { @('S-1-5-32-545', 'S-1-1-0', 'S-1-5-11') -contains $_ }).Count -eq 0)
}
# 1) a normal compile goes through the cache
Add-TypeCached 'public static class ZwCacheTest1 { public static int V() { return 41; } }'
Check 'type compiled and usable' ([ZwCacheTest1]::V() -eq 41)
$dlls = @(Get-ChildItem -LiteralPath $cdir -Filter 't*.dll')
Check 'a DLL was written to the cache' ($dlls.Count -ge 1)
Check 'that DLL is owned by Administrators/SYSTEM' ((Test-AdminOwned $dlls[0].FullName))
# 2) a DLL planted with another owner must be ignored and rebuilt
$code2 = 'public static class ZwCacheTest2 { public static int V() { return 7; } }'
$sha = [System.Security.Cryptography.SHA256]::Create()
$hs = ([BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($code2)))).Replace('-', '').Substring(0, 16)
$planted = Join-Path $cdir ('t' + $hs + '.dll')
[IO.File]::WriteAllBytes($planted, [byte[]](1, 2, 3, 4))
$planted_ok = $false
try {
    $fs = New-Object System.Security.AccessControl.FileSecurity
    $fs.SetOwner((New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-545')))
    [IO.File]::SetAccessControl($planted, $fs)
    $planted_ok = (-not (Test-AdminOwned $planted))
} catch { Write-Host ('note: cannot give the planted file another owner here (' + $_.Exception.Message + ')') }
if ($planted_ok) {
    Add-TypeCached $code2
    Check 'planted DLL (owner = Users) was not loaded: the real type works' ([ZwCacheTest2]::V() -eq 7)
    Check 'planted DLL was replaced by an Administrators-owned one' (Test-AdminOwned $planted)
} else { Write-Host 'skip  planted-DLL check (owner could not be changed on this runner)' }
Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
if ($fail -gt 0) { Write-Host ('CACHE TEST FAILED: ' + $fail); exit 1 }
Write-Host 'CACHE TEST OK'
