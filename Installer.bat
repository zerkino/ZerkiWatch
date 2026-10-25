@echo off
rem ===========================================================================
rem  Installer.bat - install or uninstall ZerkiWatch (https://github.com/zerkino/ZerkiWatch)
rem  Put it in the SAME folder as ZerkiWatch.exe (or ZerkiWatch.bat).
rem  Double-click, accept the administrator prompt, then choose 1 (Install) or 2 (Uninstall).
rem ===========================================================================
set "SELF=%~f0"
set "ARG=%~1"
fltmc >nul 2>&1
if errorlevel 1 goto elev
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SELF); iex ($t.Substring($t.IndexOf('#PS'+'START')+8))"
echo.
pause
exit /b
:elev
if "%ARG%"=="" (
  powershell -NoProfile -Command "Start-Process -FilePath $env:SELF -Verb RunAs"
) else (
  powershell -NoProfile -Command "Start-Process -FilePath $env:SELF -ArgumentList $env:ARG -Verb RunAs"
)
exit /b
#PSSTART
$ErrorActionPreference = 'Stop'
$IL = @{
    'fr' = @{
        'title' = 'ZerkiWatch - Installation'
        'banner' = 'ZERKIWATCH - Installation'
        'already' = '(D\u00e9j\u00e0 install\u00e9 dans {0})'
        'm1' = '  1 - Installer (ou mettre \u00e0 jour)'
        'm2' = '  2 - D\u00e9sinstaller'
        'm3' = '  3 - Quitter'
        'choice' = 'Votre choix (1, 2 ou 3)'
        'yn' = 'O/N'
        'yes' = 'O'
        'nosrc' = 'ZerkiWatch.exe (ou ZerkiWatch.bat) est introuvable. Mettez Installer.bat dans le m\u00eame dossier.'
        'closing' = 'Fermeture de ZerkiWatch s''il tourne...'
        'copying' = 'Copie dans {0} ...'
        'shortcuts' = 'Cr\u00e9ation des raccourcis (bureau et menu D\u00e9marrer)...'
        'uninst_name' = 'D\u00e9sinstaller'
        'registering' = 'D\u00e9claration dans Param\u00e8tres, Applications...'
        'ask_auto' = 'Lancer ZerkiWatch automatiquement quand vous ouvrez votre session Windows ?'
        'auto_on' = 'Lancement automatique : activ\u00e9.'
        'auto_off' = 'Lancement automatique : non activ\u00e9.'
        'done_inst' = 'INSTALLATION TERMIN\u00c9E.'
        'program' = 'Programme : {0}'
        'sc_done' = 'Raccourcis : bureau et menu D\u00e9marrer (dossier ZerkiWatch).'
        'ask_launch' = 'Lancer ZerkiWatch maintenant ?'
        'ask_uninst' = 'Voulez-vous vraiment d\u00e9sinstaller ZerkiWatch ?'
        'cancelled' = 'Annul\u00e9.'
        'closing2' = 'Fermeture de ZerkiWatch...'
        'rules' = 'Remise d''Internet (suppression des r\u00e8gles de blocage)...'
        'rm_auto' = 'Suppression du lancement automatique...'
        'rm_sc' = 'Suppression des raccourcis...'
        'ask_data' = 'Supprimer aussi l''historique, le journal et la configuration ({0}) ?'
        'data_fail' = 'Impossible de supprimer le dossier de donn\u00e9es (fichier utilis\u00e9).'
        'rm_prog' = 'Suppression du programme...'
        'prog_fail' = 'Impossible de supprimer le dossier du programme.'
        'done_un' = 'D\u00c9SINSTALLATION TERMIN\u00c9E.'
        'err' = 'ERREUR : {0}'
        'desc' = 'ZerkiWatch : couper ou remettre Internet, surveiller le PC'
    }
    'en' = @{
        'title' = 'ZerkiWatch - Setup'
        'banner' = 'ZERKIWATCH - Setup'
        'already' = '(Already installed in {0})'
        'm1' = '  1 - Install (or update)'
        'm2' = '  2 - Uninstall'
        'm3' = '  3 - Quit'
        'choice' = 'Your choice (1, 2 or 3)'
        'yn' = 'Y/N'
        'yes' = 'Y'
        'nosrc' = 'ZerkiWatch.exe (or ZerkiWatch.bat) not found. Put Installer.bat in the same folder.'
        'closing' = 'Closing ZerkiWatch if it is running...'
        'copying' = 'Copying to {0} ...'
        'shortcuts' = 'Creating shortcuts (desktop and Start menu)...'
        'uninst_name' = 'Uninstall'
        'registering' = 'Registering in Settings, Apps...'
        'ask_auto' = 'Start ZerkiWatch automatically when you sign in to Windows?'
        'auto_on' = 'Automatic start: on.'
        'auto_off' = 'Automatic start: off.'
        'done_inst' = 'INSTALLATION COMPLETE.'
        'program' = 'Program: {0}'
        'sc_done' = 'Shortcuts: desktop and Start menu (ZerkiWatch folder).'
        'ask_launch' = 'Start ZerkiWatch now?'
        'ask_uninst' = 'Do you really want to uninstall ZerkiWatch?'
        'cancelled' = 'Cancelled.'
        'closing2' = 'Closing ZerkiWatch...'
        'rules' = 'Restoring Internet (removing the blocking rules)...'
        'rm_auto' = 'Removing automatic start...'
        'rm_sc' = 'Removing shortcuts...'
        'ask_data' = 'Also delete the history, log and settings ({0})?'
        'data_fail' = 'Could not delete the data folder (file in use).'
        'rm_prog' = 'Removing the program...'
        'prog_fail' = 'Could not delete the program folder.'
        'done_un' = 'UNINSTALL COMPLETE.'
        'err' = 'ERROR: {0}'
        'desc' = 'ZerkiWatch: cut or restore Internet, monitor your PC'
    }
}

$lc = 'en'
try { if ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr') { $lc = 'fr' } } catch { }
function L([string]$k) {
    $s = $IL[$lc][$k]
    if ($s -eq $null) { $s = $IL['en'][$k] }
    return [regex]::Replace([string]$s, '\\u([0-9a-fA-F]{4})', ([System.Text.RegularExpressions.MatchEvaluator]{ param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) }))
}
function Lf([string]$k, [string]$a) { return ((L $k).Replace('{0}', $a)) }
try { $Host.UI.RawUI.WindowTitle = (L 'title') } catch { }

$InstDir = Join-Path $env:ProgramFiles 'ZerkiWatch'
$Groups = @('ZerkiWatch-LocalOnly', 'ZerkiWatch-Remote', 'ModeReseau-LocalUniquement', 'ModeReseau-Telecommande')
$srcDir = Split-Path -Parent $env:SELF
$cDesk = [Environment]::GetFolderPath('CommonDesktopDirectory')
$cProg = [Environment]::GetFolderPath('CommonPrograms')
$uDesk = [Environment]::GetFolderPath('DesktopDirectory')
$uProg = [Environment]::GetFolderPath('Programs')
$progName = 'ZerkiWatch'
$regKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ZerkiWatch'
$dataDir = Join-Path $env:APPDATA 'ZerkiWatch'

function Ask-YesNo([string]$q) {
    $a = Read-Host ($q + ' (' + (L 'yn') + ')')
    return (([string]$a).Trim().ToUpper().StartsWith((L 'yes')))
}

function Stop-App {
    foreach ($pr in @(Get-Process -Name 'ZerkiWatch', 'Mode-Reseau' -ErrorAction SilentlyContinue)) {
        try { $pr.Kill(); [void]$pr.WaitForExit(4000) } catch { }
    }
    try {
        foreach ($cp in @(Get-CimInstance -ClassName Win32_Process -Filter "Name='powershell.exe'" -ErrorAction Stop)) {
            if (([int]$cp.ProcessId -ne $PID) -and ([string]$cp.CommandLine).Contains('IndexOf(''#PS''')) {
                try { Stop-Process -Id ([int]$cp.ProcessId) -Force -ErrorAction Stop } catch { }
            }
        }
    } catch { }
    try { & logman.exe stop ZerkiWatchNet -ets 2>&1 | Out-Null } catch { }
    try { & logman.exe stop ModeReseauNet -ets 2>&1 | Out-Null } catch { }
    Start-Sleep -Milliseconds 800
}

function New-Shortcut([string]$lnk, [string]$target, [string]$arguments, [string]$icon, [string]$workDir) {
    $sh = New-Object -ComObject WScript.Shell
    $s = $sh.CreateShortcut($lnk)
    $s.TargetPath = $target
    $s.Arguments = $arguments
    $s.WorkingDirectory = $workDir
    $s.IconLocation = $icon
    $s.Description = (L 'desc')
    $s.Save()
}

function Install-App {
    $exeSrc = Join-Path $srcDir 'ZerkiWatch.exe'
    $batSrc = Join-Path $srcDir 'ZerkiWatch.bat'
    $icoSrc = Join-Path $srcDir 'ZerkiWatch.ico'
    $useExe = $false
    if (Test-Path -LiteralPath $exeSrc) { $useExe = $true }
    if (-not (Test-Path -LiteralPath $batSrc)) { throw (L 'nosrc') }
    if ($useExe) { $mainName = 'ZerkiWatch.exe'; $mainSrc = $exeSrc } else { $mainName = 'ZerkiWatch.bat'; $mainSrc = $batSrc }

    Write-Host ''
    Write-Host (L 'closing')
    Stop-App

    Write-Host (Lf 'copying' $InstDir)
    if (-not (Test-Path -LiteralPath $InstDir)) { New-Item -ItemType Directory -Path $InstDir -Force | Out-Null }
    $main = Join-Path $InstDir $mainName
    if ($mainSrc -ne $main) { Copy-Item -LiteralPath $mainSrc -Destination $main -Force }
    try { Unblock-File -LiteralPath $main -ErrorAction SilentlyContinue } catch { }
    # ZerkiWatch.exe is a small launcher: it starts ZerkiWatch.bat located in the same folder
    if ($useExe) {
        $batDst = Join-Path $InstDir 'ZerkiWatch.bat'
        if ($batSrc -ne $batDst) { Copy-Item -LiteralPath $batSrc -Destination $batDst -Force }
        try { Unblock-File -LiteralPath $batDst -ErrorAction SilentlyContinue } catch { }
    }
    $langSrc = Join-Path $srcDir 'lang'
    if (Test-Path -LiteralPath $langSrc) { Copy-Item -LiteralPath $langSrc -Destination $InstDir -Recurse -Force }

    $ico = Join-Path $InstDir 'ZerkiWatch.ico'
    if (Test-Path -LiteralPath $icoSrc) {
        if ($icoSrc -ne $ico) { Copy-Item -LiteralPath $icoSrc -Destination $ico -Force }
    } elseif (Test-Path -LiteralPath $batSrc) {
        $t = [IO.File]::ReadAllText($batSrc)
        $mm = [regex]::Match($t, '\$iconB64 = ''([A-Za-z0-9+/=]+)''')
        if ($mm.Success) { [IO.File]::WriteAllBytes($ico, [Convert]::FromBase64String($mm.Groups[1].Value)) }
    }
    if (Test-Path -LiteralPath $ico) { $iconLoc = $ico + ',0' } else { $iconLoc = $main + ',0' }

    $inst = Join-Path $InstDir 'Installer.bat'
    if ($env:SELF -ne $inst) { Copy-Item -LiteralPath $env:SELF -Destination $inst -Force }

    Write-Host (L 'shortcuts')
    New-Shortcut (Join-Path $cDesk ($progName + '.lnk')) $main '' $iconLoc $InstDir
    $menuDir = Join-Path $cProg $progName
    if (-not (Test-Path -LiteralPath $menuDir)) { New-Item -ItemType Directory -Path $menuDir -Force | Out-Null }
    New-Shortcut (Join-Path $menuDir ($progName + '.lnk')) $main '' $iconLoc $InstDir
    New-Shortcut (Join-Path $menuDir ((L 'uninst_name') + ' ' + $progName + '.lnk')) $inst 'uninstall' $iconLoc $InstDir

    Write-Host (L 'registering')
    New-Item -Path $regKey -Force | Out-Null
    Set-ItemProperty -Path $regKey -Name 'DisplayName' -Value 'ZerkiWatch'
    Set-ItemProperty -Path $regKey -Name 'DisplayIcon' -Value $iconLoc
    Set-ItemProperty -Path $regKey -Name 'InstallLocation' -Value $InstDir
    Set-ItemProperty -Path $regKey -Name 'UninstallString' -Value ('"' + $inst + '" uninstall')
    Set-ItemProperty -Path $regKey -Name 'Publisher' -Value 'zerkino'
    Set-ItemProperty -Path $regKey -Name 'URLInfoAbout' -Value 'https://github.com/zerkino/ZerkiWatch'
    Set-ItemProperty -Path $regKey -Name 'NoModify' -Value 1 -Type DWord
    Set-ItemProperty -Path $regKey -Name 'NoRepair' -Value 1 -Type DWord

    Write-Host ''
    Unregister-ScheduledTask -TaskName 'ModeReseau' -Confirm:$false -ErrorAction SilentlyContinue
    if (Ask-YesNo (L 'ask_auto')) {
        if ($useExe) { $act = New-ScheduledTaskAction -Execute $main -Argument 'tray' }
        else { $act = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c "' + $main + '" tray') }
        $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $trig = New-ScheduledTaskTrigger -AtLogOn -User $user
        try { $trig.Delay = 'PT15S' } catch { }
        $prin = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        $setg = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -StartWhenAvailable
        Register-ScheduledTask -TaskName 'ZerkiWatch' -Action $act -Trigger $trig -Principal $prin -Settings $setg -Force | Out-Null
        Write-Host (L 'auto_on') -ForegroundColor Green
    } else {
        Unregister-ScheduledTask -TaskName 'ZerkiWatch' -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host (L 'auto_off')
    }

    Write-Host ''
    Write-Host (L 'done_inst') -ForegroundColor Green
    Write-Host (Lf 'program' $main)
    Write-Host (L 'sc_done')
    if (Ask-YesNo (L 'ask_launch')) {
        Start-Process -FilePath $main -WorkingDirectory $InstDir
    }
}

function Uninstall-App {
    Write-Host ''
    if (-not (Ask-YesNo (L 'ask_uninst'))) { Write-Host (L 'cancelled'); return }

    Write-Host (L 'closing2')
    Stop-App

    Write-Host (L 'rules')
    foreach ($g in $Groups) {
        try {
            $rules = @(Get-NetFirewallRule -Group $g -ErrorAction SilentlyContinue)
            if ($rules.Count -gt 0) { $rules | Remove-NetFirewallRule -ErrorAction SilentlyContinue }
        } catch { }
    }
    # HTTPS of the iPhone remote: port binding + ZerkiWatch certificates
    try { $null = & cmd.exe /c 'netsh.exe http delete sslcert ipport=0.0.0.0:8765 2>&1' } catch { }
    try { Get-ChildItem Cert:\LocalMachine\My | Where-Object { ($_.Subject -eq 'CN=ZerkiWatch iPhone remote') -or ($_.Subject -eq 'CN=ZerkiWatch Local CA') } | Remove-Item -ErrorAction SilentlyContinue } catch { }

    Write-Host (L 'rm_auto')
    try { Unregister-ScheduledTask -TaskName 'ZerkiWatch' -Confirm:$false -ErrorAction SilentlyContinue } catch { }
    try { Unregister-ScheduledTask -TaskName 'ModeReseau' -Confirm:$false -ErrorAction SilentlyContinue } catch { }

    Write-Host (L 'rm_sc')
    foreach ($f in @((Join-Path $cDesk ($progName + '.lnk')), (Join-Path $uDesk ($progName + '.lnk')))) {
        try { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } } catch { }
    }
    foreach ($d in @((Join-Path $cProg $progName), (Join-Path $uProg $progName))) {
        try { if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force } } catch { }
    }

    try { if (Test-Path -LiteralPath $regKey) { Remove-Item -Path $regKey -Recurse -Force } } catch { }

    if (Test-Path -LiteralPath $dataDir) {
        if (Ask-YesNo (Lf 'ask_data' $dataDir)) {
            try { Remove-Item -LiteralPath $dataDir -Recurse -Force } catch { Write-Host (L 'data_fail') }
        }
    }

    Write-Host (L 'rm_prog')
    if (Test-Path -LiteralPath $InstDir) {
        $inside = $env:SELF.StartsWith($InstDir, [StringComparison]::OrdinalIgnoreCase)
        if ($inside) {
            Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ping 127.0.0.1 -n 4 >nul & rd /s /q "' + $InstDir + '"') -WindowStyle Hidden
        } else {
            try { Remove-Item -LiteralPath $InstDir -Recurse -Force } catch { Write-Host (L 'prog_fail') }
        }
    }
    Write-Host ''
    Write-Host (L 'done_un') -ForegroundColor Green
}

try {
    if (($env:ARG -eq 'uninstall') -or ($env:ARG -eq 'desinstaller')) {
        Uninstall-App
    } else {
        $done = $false
        while (-not $done) {
            Clear-Host
            Write-Host '==============================='
            Write-Host ('   ' + (L 'banner'))
            Write-Host '==============================='
            if (Test-Path -LiteralPath $InstDir) { Write-Host (Lf 'already' $InstDir) }
            Write-Host ''
            Write-Host (L 'm1')
            Write-Host (L 'm2')
            Write-Host (L 'm3')
            Write-Host ''
            $c = (Read-Host (L 'choice')).Trim()
            if ($c -eq '1') { Install-App; $done = $true }
            elseif ($c -eq '2') { Uninstall-App; $done = $true }
            elseif ($c -eq '3') { $done = $true }
        }
    }
} catch {
    Write-Host ''
    Write-Host (Lf 'err' $_.Exception.Message) -ForegroundColor Red
}
