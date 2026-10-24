@echo off
rem ===========================================================================
rem  Build-EXE.bat - builds ZerkiWatch.exe from ZerkiWatch.bat (needs Internet once,
rem  to download the free PS2EXE tool). Put it in the SAME folder as ZerkiWatch.bat.
rem  Fabrique ZerkiWatch.exe a partir de ZerkiWatch.bat (Internet requis une fois).
rem ===========================================================================
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$t=[IO.File]::ReadAllText($env:SELF); iex ($t.Substring($t.IndexOf('#PS'+'START')+8))"
echo.
pause
exit /b
#PSSTART
$ErrorActionPreference = 'Stop'
$fr = $false
try { $fr = ([System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName -eq 'fr') } catch { }
function M([string]$en, [string]$frt) { if ($fr) { return $frt } else { return $en } }
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $dir = Split-Path -Parent $env:SELF
    $src = Join-Path $dir 'ZerkiWatch.bat'
    if (-not (Test-Path -LiteralPath $src)) { throw (M 'ZerkiWatch.bat not found: put Build-EXE.bat in the same folder.' 'ZerkiWatch.bat est introuvable : mettez Build-EXE.bat dans le meme dossier.') }

    Write-Host (M 'Extracting the program...' 'Extraction du programme...')
    $t = [IO.File]::ReadAllText($src)
    $i = $t.IndexOf('#PS' + 'START')
    if ($i -lt 0) { throw (M 'Unexpected ZerkiWatch.bat (marker not found).' 'ZerkiWatch.bat inattendu (marqueur introuvable).') }
    $ps1 = Join-Path $dir 'ZerkiWatch-tmp.ps1'
    [IO.File]::WriteAllText($ps1, $t.Substring($i + 8), [Text.Encoding]::ASCII)

    Write-Host (M 'Downloading the PS2EXE tool (free)...' 'Telechargement de l''outil PS2EXE (gratuit)...')
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null
    Install-Module -Name ps2exe -Scope CurrentUser -Force
    Import-Module ps2exe

    Write-Host (M 'Building ZerkiWatch.exe...' 'Creation de ZerkiWatch.exe...')
    $exe = Join-Path $dir 'ZerkiWatch.exe'
    $opts = @{ inputFile = $ps1; outputFile = $exe; noConsole = $true; requireAdmin = $true; STA = $true; title = 'ZerkiWatch' }
    $ico = Join-Path $dir 'ZerkiWatch.ico'
    $mm = [regex]::Match($t, '\$iconB64 = ''([A-Za-z0-9+/=]+)''')
    if ($mm.Success) { [IO.File]::WriteAllBytes($ico, [Convert]::FromBase64String($mm.Groups[1].Value)) }
    if (Test-Path -LiteralPath $ico) { $opts['iconFile'] = $ico }
    Invoke-ps2exe @opts
    Remove-Item -LiteralPath $ps1 -Force -ErrorAction SilentlyContinue

    if (Test-Path -LiteralPath $exe) {
        Write-Host ''
        Write-Host ((M 'DONE: ' 'TERMINE : ') + $exe) -ForegroundColor Green
    } else {
        throw (M 'The .exe was not created.' 'Le fichier .exe n''a pas ete cree.')
    }
} catch {
    Write-Host ''
    Write-Host ((M 'ERROR: ' 'ERREUR : ') + $_.Exception.Message) -ForegroundColor Red
    Remove-Item -LiteralPath (Join-Path (Split-Path -Parent $env:SELF) 'ZerkiWatch-tmp.ps1') -Force -ErrorAction SilentlyContinue
}
