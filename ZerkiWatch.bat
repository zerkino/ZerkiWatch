@echo off
rem ===========================================================================
rem  ZerkiWatch.bat - portable app: cut / restore Internet and monitor your PC.
rem  Single file. Double-click, accept the administrator prompt, click.
rem  Open source (MIT) - https://github.com/zerkino/ZerkiWatch
rem ===========================================================================
set "SELF=%~f0"
set "ARG=%~1"
fltmc >nul 2>&1
if errorlevel 1 goto elev
start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "try { $t=[IO.File]::ReadAllText($env:SELF); iex ($t.Substring($t.IndexOf('#PS'+'START')+8)) } catch { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show(('Startup error: ' + $_.Exception.Message), 'ZerkiWatch') }"
exit /b
:elev
if "%ARG%"=="" (
  powershell -NoProfile -Command "Start-Process -FilePath $env:SELF -Verb RunAs"
) else (
  powershell -NoProfile -Command "Start-Process -FilePath $env:SELF -ArgumentList $env:ARG -Verb RunAs"
)
exit /b
#PSSTART
try {
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Numerics
[System.Windows.Forms.Application]::EnableVisualStyles()
$ErrorActionPreference = 'Stop'
[System.Windows.Forms.Application]::SetUnhandledExceptionMode([System.Windows.Forms.UnhandledExceptionMode]::CatchException)

# ---------- Version and error log ----------
$APPVER = '6.1.3'
$logDir = Join-Path $env:APPDATA 'ZerkiWatch'
$oldDataDir = Join-Path $env:APPDATA 'ModeReseau'
try {
    if ((-not (Test-Path -LiteralPath $logDir)) -and (Test-Path -LiteralPath $oldDataDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        foreach ($mv in @(@('config.txt', 'config.txt'), @('mot-de-passe.txt', 'password.txt'), @('historique.csv', 'history.csv'), @('totaux.csv', 'totals.csv'), @('apps.csv', 'apps.csv'), @('journal.txt', 'log.txt'))) {
            $srcF = Join-Path $oldDataDir $mv[0]
            if (Test-Path -LiteralPath $srcF) { Copy-Item -LiteralPath $srcF -Destination (Join-Path $logDir $mv[1]) -Force }
        }
    }
} catch { }
$logFile = Join-Path $logDir 'log.txt'
$logLast = @{}
function Write-Log([string]$msg, [string]$key = '') {
    try {
        if ($key -ne '') {
            $n = [DateTime]::UtcNow
            if ($logLast.ContainsKey($key) -and (($n - $logLast[$key]).TotalSeconds -lt 60)) { return }
            $logLast[$key] = $n
        }
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        if ((Test-Path -LiteralPath $logFile) -and ((Get-Item -LiteralPath $logFile).Length -gt 400000)) {
            Move-Item -LiteralPath $logFile -Destination ($logFile + '.old') -Force
        }
        Add-Content -LiteralPath $logFile -Value ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '  ' + $msg) -Encoding ASCII
    } catch { }
}
[System.Windows.Forms.Application]::add_ThreadException({ param($s2, $e2) try { Write-Log ('UI error: ' + $e2.Exception.Message) 'thr' } catch { } })

# ---------- Languages (i18n) ----------
# Texts live in lang/*.txt in the repository and are embedded below by tools/embed-lang.ps1.
# Extra languages can be added without touching the code: drop a file xx.txt in
# "lang" next to the program, or in %APPDATA%\ZerkiWatch\lang.
$LangDb = @{}
function ConvertFrom-LangEsc([string]$s) {
    $s = $s.Replace('\n', "`n")
    return [regex]::Replace($s, '\\u([0-9a-fA-F]{4})', ([System.Text.RegularExpressions.MatchEvaluator]{ param($m) [string][char][Convert]::ToInt32($m.Groups[1].Value, 16) }))
}
function Add-LangLines($lines, [string]$code) {
    foreach ($ln in $lines) {
        $t = ([string]$ln).Trim()
        if (($t -eq '') -or $t.StartsWith('#')) { continue }
        if ($t -match '^\[([A-Za-z\-]{2,10})\]$') {
            $code = $Matches[1].ToLower()
            if (-not $LangDb.ContainsKey($code)) { $LangDb[$code] = @{} }
            continue
        }
        $i = $t.IndexOf('=')
        if (($i -lt 1) -or ($code -eq '')) { continue }
        if (-not $LangDb.ContainsKey($code)) { $LangDb[$code] = @{} }
        $LangDb[$code][$t.Substring(0, $i).Trim()] = ConvertFrom-LangEsc ($t.Substring($i + 1))
    }
}
# LANGDATA BEGIN
$langData = @'
[de]
about.btn=Updates / \u00dcber...
about.newer=Version {0} ist verf\u00fcgbar.
about.offline=GitHub nicht erreichbar (offline?).
about.open=Download-Seite \u00f6ffnen?
about.startup=Beim Start nach Updates suchen (standardm\u00e4\u00dfig aus)
about.uptodate=Sie sind auf dem neuesten Stand.
app.others=Andere (beendete Prozesse)
app.system=Windows-System (geteilt, Kernel)
bal.alert_cut=Internet ist seit {0} Min. getrennt.
bal.alert_speed=Hoher Datenverkehr: {0} Mbps.
bal.alert_speed_app=Hoher Datenverkehr: {0} Mbps (Haupt: {1}).
bal.autostart_fail=Start mit Windows nicht m\u00f6glich: {0}
bal.bar_hidden=Die schwebende Leiste ist ausgeblendet. Rechtsklick auf das Tray-Symbol, dann Schwebende Leiste, um sie wieder anzuzeigen.
bal.busy=Ein Umschalten l\u00e4uft bereits, bitte warten.
bal.cut=Lokaler Modus: Internet ist aus
bal.cut_end=Zeit abgelaufen: Internet wiederhergestellt.
bal.cut_timed=Internet getrennt bis {0}, dann automatisch wiederhergestellt.
bal.dock_na=Die Taskleisten-Integration ist auf diesem PC nicht verf\u00fcgbar.
bal.dock_notaskbar=Taskleiste nicht gefunden oder vertikal: Die Integration funktioniert nur mit einer horizontalen Taskleiste (unten oder oben).
bal.hk_used=Die Tastenkombination {0} wird bereits von einem anderen Programm verwendet. W\u00e4hle im Men\u00fc unter Tastenkombination eine andere.
bal.lang_restart=Neustart, um die Sprache zu \u00fcbernehmen...
bal.minimized=Das Programm l\u00e4uft weiter neben der Uhr. Rechtsklick auf das Symbol zum Beenden.
bal.power=Herunterfahren oder Neustart vom iPhone angefordert: 30 Sekunden zum Abbrechen.
bal.restored=Internet wiederhergestellt
bal.theme_restart=Neustart, um das Design anzuwenden...
bar.internet=INTERNET
bar.local=LOKAL
bar.title=Systemmonitor
cert.fail=Zertifikatexport fehlgeschlagen: {0}
cert.help=Datei gespeichert: {0}\n\nAuf dem iPhone (gleiches WLAN):\n1. Sende diese Datei an das iPhone (AirDrop, Mail, iCloud Drive) oder \u00f6ffne {2} in Safari und tippe auf Erlauben, um das Profil zu laden.\n2. Einstellungen > Profil geladen > Installieren.\n3. Einstellungen > Allgemein > Info > Zertifikatsvertrauenseinstellungen > \u201eZerkiWatch Local CA\u201c aktivieren.\n4. Pr\u00fcfe den SHA-256-Fingerabdruck in den Zertifikatdetails auf dem iPhone:\n{1}\n\n\u00d6ffne danach die Adresse der Fernbedienung erneut.
cert.qr=Scanne diesen Code mit der iPhone-Kamera. Tippe in Safari auf Details einblenden, dann auf diese Website besuchen, und erlaube den Download des Zertifikats.
err.bind=Zertifikat konnte nicht an den Port gebunden werden ({0})
err.cert=Problem mit dem HTTPS-Zertifikat, Fernbedienung nicht gestartet: {0}
err.fatal=Fehler: {0}
err.fw_disabled=Die Windows-Firewall ist ausgeschaltet ({0}). Schalte sie ein und versuche es erneut.
err.fw_stopped=Die Windows-Firewall ist angehalten: Das Internet kann nicht blockiert werden.
err.noca=Kein ZerkiWatch-Zertifikat gefunden. Starte ZerkiWatch als Administrator neu.
err.oldversion=Eine \u00e4ltere Version von Mode reseau l\u00e4uft noch.\nRechtsklick auf das Symbol neben der Uhr, Beenden w\u00e4hlen, dann das Programm neu starten.
err.ranges=Die Adressbereiche konnten nicht berechnet werden.
err.rule_not_created=Firewall-Regel nicht erstellt
err.rules_inactive=Die Blockierregeln sind nicht aktiv.
err.rules_left=Einige Blockierregeln sind noch vorhanden.
err.unavailable=Funktion auf diesem PC nicht verf\u00fcgbar
foot.noip=iPhone-Fernsteuerung aktiv auf Port {0}\nPasswort: {1} (IP-Adresse des PCs nicht gefunden)
foot.off=iPhone-Fernsteuerung nicht verf\u00fcgbar: {0}
foot.remote=iPhone (gleiches Wi-Fi): {0}\nPasswort: {1}
hist.bymonth=NACH MONAT
hist.d30=30 Tage
hist.d7=7 Tage
hist.h1=1 Std
hist.h24=24 Std
hist.last7=LETZTE 7 TAGE
hist.legend_app=Anwendung
hist.legend_svc=Dienst
hist.nodata=Noch keine Daten
hist.nodata_period=Noch keine Daten f\u00fcr diesen Zeitraum
hist.perf=LEISTUNG (%)
hist.received=Empfangen
hist.recv=Download
hist.sendw=Upload
hist.sent=Gesendet
hist.speed=TEMPO (Mbps)
hist.title=VERLAUF
hist.title_win=ZerkiWatch - Verlauf
hist.today=Heute
hist.today_caps=HEUTE
hist.top=TOP-VERBRAUCHER
hist.total=Gesamt: {0}
items.cpu=CPU
items.dl=Empfang
items.dsk=Datentr\u00e4ger
items.full=Vollst\u00e4ndig
items.gpu=GPU
items.mini=Mini (nur Tempo)
items.mode=Netzwerkmodus
items.ram=RAM
items.ul=Senden
lang.name=Deutsch
menu.auto=Mit Windows starten
menu.bar=Schwebende Leiste
menu.bar_full=Schwebende Leiste (CPU, RAM, Tempo)
menu.big=Gro\u00df
menu.cumul=Fortlaufende Summen pro App
menu.cut=Internet trennen
menu.cut_15=15 Minuten
menu.cut_30=30 Minuten
menu.cut_60=1 Stunde
menu.cut_cancel=Automatische R\u00fcckkehr abbrechen
menu.cut_timed=Internet trennen f\u00fcr...
menu.cut_tomorrow=Bis morgen 7:00 Uhr
menu.cut_until=Internet kommt um {0} zur\u00fcck
menu.disk=Datentr\u00e4ger
menu.disks=Angezeigte Datentr\u00e4ger
menu.dock=In die Taskleiste integrieren
menu.history=Verlauf...
menu.hotkey=Tastenkombination
menu.hotkey_cur=Tastenkombination: {0}
menu.hotkey_enable=Tastenkombination aktivieren
menu.hotkey_off=Tastenkombination: aus
menu.iphone=iPhone-Fernsteuerung...
menu.items=Inhalt der Leiste
menu.lang_auto=Automatisch
menu.language=Sprache
menu.log=Protokoll \u00f6ffnen
menu.nodisks=Kein Datentr\u00e4ger erkannt
menu.normal=Normal
menu.open=ZerkiWatch \u00f6ffnen
menu.quit=Beenden
menu.removable=Wechseldatentr\u00e4ger
menu.reset=Leistenposition zur\u00fccksetzen
menu.restore=Internet wiederherstellen
menu.settings=Einstellungen...
menu.size=Leistengr\u00f6\u00dfe
menu.small=Klein
menu.top=Leiste im Vordergrund halten
menu.widget=Desktop-Widget (verschiebbar)
menu.wizard=Einrichtungsassistent...
p.apps=ANWENDUNGEN
p.badpw=Falsches Passwort.
p.busy=Der PC ist besch\u00e4ftigt, versuche es erneut.
p.bymonth=NACH MONAT
p.cancel=Abbrechen
p.changepw=Passwort eingeben
p.connecting=Verbinde...
p.cut_15=15 Min.
p.cut_30=30 Min.
p.cut_60=1 Std.
p.cut_back=Internet kommt in {0} zur\u00fcck
p.cut_cancel=Abbrechen
p.cut_title=INTERNET TRENNEN F\u00dcR
p.cut_tomorrow=Bis morgen 7:00
p.d30=30 Tage
p.d7=7 Tage
p.days=So,Mo,Di,Mi,Do,Fr,Sa
p.dec=,
p.disks=DATENTR\u00c4GER
p.err=Fehler: {0}
p.h1=1 Std
p.h24=24 Std
p.history=VERLAUF
p.l_cancel=Abgebrochen.
p.l_lock=PC gesperrt.
p.l_restart=Neustart in 30 s geplant.
p.l_screen=Bildschirm aus (Maus bewegen zum Aufwecken).
p.l_shutdown=Herunterfahren in 30 s geplant.
p.l_sleep=Wechsle in den Ruhezustand\u2026
p.last7=LETZTE 7 TAGE
p.legend_app=Anwendung
p.legend_svc=Dienst
p.live=LIVE-TEMPO
p.lock=Sperren
p.net_off=NUR LOKAL
p.net_off_sub=Das Internet ist am PC getrennt. Das lokale Netzwerk funktioniert.
p.net_on=INTERNET AN
p.net_on_sub=Tippe auf den Schalter, um das Internet am PC zu trennen.
p.noact=Keine nennenswerte Aktivit\u00e4t
p.nodata=Noch keine Daten
p.nodata_top=Noch keine Daten
p.nodisk=Kein Datentr\u00e4ger gew\u00e4hlt
p.noetw=Messung pro App nicht verf\u00fcgbar
p.noresp=Keine Antwort vom PC.
p.perf=LEISTUNG
p.perf_pct=LEISTUNG (%)
p.power=ENERGIE
p.pwprompt=Passwort:
p.q_restart=PC in 30 Sekunden neu starten?
p.q_shutdown=PC in 30 Sekunden herunterfahren?
p.q_sleep=PC in den Ruhezustand versetzen? Er ist dann vom iPhone aus nicht mehr erreichbar.
p.recv=Download
p.restart=Neustart
p.restart_in=Neustart in {0} s
p.screen=Bildschirm aus
p.send=Upload
p.services=WINDOWS-DIENSTE
p.shutdown=PC herunterfahren
p.shutdown_in=Herunterfahren in {0} s
p.sleep=Ruhezustand
p.speed_mbps=TEMPO (Mbps)
p.today=Heute
p.today_rx=Heute, heruntergeladen
p.today_tx=Heute, hochgeladen
p.toomany=Zu viele Versuche: Warte 1 Minute.
p.top=TOP-VERBRAUCHER
p.unit_g=GB
p.unit_k=KB
p.unit_m=MB
p.unit_t=TB
p.unreach=PC nicht erreichbar.
p.unreach2=PC nicht erreichbar: gleiches Wi-Fi? L\u00e4uft das Programm?
p.usage=AUSLASTUNG
p.wait=Bitte warten...
pin.addr=Adresse (gleiches Wi-Fi): {0}
pin.cancel=Abbrechen
pin.cert=iPhone-Zertifikat
pin.invalid=Passwort zu kurz (mindestens 4 Zeichen).
pin.label=Passwort (mindestens 4 Zeichen):
pin.noaddr=IP-Adresse des PCs nicht gefunden
pin.off=Die Fernsteuerung ist nicht aktiv.
pin.save=Speichern
pin.title=iPhone-Fernsteuerung
power.reason=ZerkiWatch: Anfrage vom iPhone
set.alert_cut=Warnen, wenn Internet getrennt bleibt f\u00fcr
set.alert_speed=Warnen, wenn der Datenverkehr \u00fcbersteigt
set.alerts=Warnungen
set.close=Schlie\u00dfen
set.display=Anzeige
set.general=Allgemein
set.min=Min.
set.pw=Passwort / Adresse...
set.remote=iPhone-Fernbedienung
set.theme=Design
set.theme_auto=Automatisch (Windows)
set.theme_blue=Nachtblau
set.theme_dark=Dunkel
set.theme_gray=Grau
set.theme_green=Gr\u00fcn
set.theme_light=Hell (Beta)
set.theme_violet=Violett
set.title=ZerkiWatch-Einstellungen
short.all={0} - Down {1} - Up {2} Mbps - CPU {3} % - RAM {4} %
short.cpu=CPU {0} %
short.local=Lokaler Modus (Internet aus)
short.on=Internet an
short.ram=RAM {0} %
short.speed=Down {0} / Up {1} Mbps
tip.click=Auf das Symbol klicken: Internet trennen / wiederherstellen
tip.cpu=CPU: {0} %
tip.disk=Datentr\u00e4ger {0}: {1} / {2} ({3} %), Aktivit\u00e4t {4} %
tip.disk_none=Datentr\u00e4ger: keiner
tip.gpu=GPU: {0} %
tip.gpu_none=GPU: --
tip.link=Verbindung: {0}
tip.net=Netzwerk: {0}
tip.net_default=Netzwerk
tip.net_none=keines
tip.ram=RAM: {0} / {1} ({2} %)
tip.rate=Down: {0} Mbps    Up: {1} Mbps
tip.total=Gesamt (Sitzung): {0} heruntergeladen, {1} hochgeladen
tip.unknown=unbekannt
tip.vram=VRAM: {0} / {1}
ui.accessible=Erreichbar
ui.accessible_bang=Erreichbar!
ui.all_ok=Alles in Ordnung.
ui.apps=ANWENDUNGEN
ui.blocked=Blockiert (wie gewollt)
ui.blocked_nobox=Das Internet ist blockiert. Dein Router antwortet nicht auf ping (bei manchen Routern normal): Teste ein Ger\u00e4t in deinem lokalen Netzwerk.
ui.box_noping=Keine ping-Antwort
ui.box_ok=Router erreichbar
ui.cores={0} logische Kerne
ui.cpu=PROZESSOR
ui.cpu_load=Gesamtauslastung
ui.cut_for=Trennen f\u00fcr
ui.disks=DATENTR\u00c4GER
ui.error=Fehler: {0}
ui.gpu_default=Grafikkarte
ui.gpu_load=Grafiklast
ui.gpu_nocounter=Z\u00e4hler nicht verf\u00fcgbar
ui.history=Verlauf
ui.iphone=iPhone
ui.local=NUR LOKAL
ui.local_net=Lokales Netzwerk
ui.local_sub=Das Internet ist f\u00fcr diesen PC getrennt. Das lokale Netzwerk (Router, NAS, Drucker, andere Ger\u00e4te) funktioniert.
ui.mbps_in=Mbps Empfang
ui.network=NETZWERK
ui.no_internet=Kein Internet: Pr\u00fcfe den Router, das Wi-Fi oder ein VPN.
ui.noact=Keine nennenswerte Aktivit\u00e4t
ui.nodisk=Kein Datentr\u00e4ger gew\u00e4hlt
ui.noetw=Messung pro App nicht verf\u00fcgbar
ui.on=INTERNET AN
ui.on_sub=Normale Internetverbindung. Klicke auf den Schalter, um das Internet zu trennen.
ui.ram=SPEICHER
ui.ram_used=Belegter Speicher
ui.recv=DOWNLOAD
ui.retest=Erneut testen
ui.send=UPLOAD
ui.services=WINDOWS-DIENSTE
ui.settings=Einstellungen
ui.tab_home=Start
ui.tab_perf=Leistung
ui.testing=Teste...
ui.unreachable=Nicht erreichbar
ui.vram=VRAM {0} / {1}
ui.wait=Bitte warten...
ui.warn_still=Achtung: Das Internet antwortet noch. Ein VPN, ein Proxy oder eine Verbindungsfreigabe umgeht die Sperre.
unit.g=GB
unit.k=KB
unit.m=MB
unit.t=TB
wiz.cert_hint=Um die iPhone-Fernbedienung ohne Browserwarnung zu nutzen, installiere das ZerkiWatch-Zertifikat einmal auf deinem iPhone (Schritte und QR-Code im Fenster oben).
wiz.finish=Fertig
wiz.intro=Ein paar schnelle Einstellungen zum Start. Alles l\u00e4sst sich sp\u00e4ter \u00e4ndern; dieses Fenster \u00f6ffnest du \u00fcber das Symbolmen\u00fc erneut.
wiz.lang=Sprache
wiz.pin=Passwort der iPhone-Fernbedienung (das erzeugte kann bleiben):
wiz.skip=\u00dcberspringen
wiz.title=Willkommen bei ZerkiWatch
[en]
about.btn=Check for updates...
about.newer=Version {0} is available.
about.offline=Could not reach GitHub (offline?).
about.open=Open the download page?
about.startup=Check for updates at startup (off by default)
about.uptodate=You are up to date.
app.others=Others (ended processes)
app.system=Windows system (shared, kernel)
bal.alert_cut=Internet has been cut for {0} min.
bal.alert_speed=Heavy traffic: {0} Mbps.
bal.alert_speed_app=Heavy traffic: {0} Mbps (top: {1}).
bal.autostart_fail=Could not start with Windows: {0}
bal.bar_hidden=The floating bar is hidden. Right-click the tray icon, then Floating bar to show it again.
bal.busy=A switch is already in progress, please wait.
bal.cut=Local mode: Internet is off
bal.cut_end=Time is up: Internet restored.
bal.cut_timed=Internet cut until {0}, then restored automatically.
bal.dock_na=Taskbar integration is not available on this PC.
bal.dock_notaskbar=Taskbar not found or vertical: integration only works with a horizontal taskbar (bottom or top).
bal.hk_used=The shortcut {0} is already used by another program. Pick another one in the menu, Keyboard shortcut.
bal.lang_restart=Restarting to apply the language...
bal.minimized=The program keeps running near the clock. Right-click the icon to quit.
bal.power=Shutdown or restart requested from the iPhone: 30 seconds to cancel.
bal.restored=Internet restored
bal.theme_restart=Restarting to apply the theme...
bar.internet=INTERNET
bar.local=LOCAL
bar.title=System monitor
cert.fail=Certificate export failed: {0}
cert.help=File saved: {0}\n\nOn the iPhone (same Wi-Fi):\n1. Send this file to the iPhone (AirDrop, mail, iCloud Drive) or open {2} in Safari and tap Allow when asked to download the profile.\n2. Settings > Profile Downloaded > Install.\n3. Settings > General > About > Certificate Trust Settings > turn ON "ZerkiWatch Local CA".\n4. Check the SHA-256 fingerprint in the certificate details on the iPhone:\n{1}\n\nThen open the remote address again.
cert.qr=Scan this code with the iPhone camera. In Safari, tap Show details, then visit this website, and Allow the download of the certificate.
err.bind=could not bind the certificate to the port ({0})
err.cert=HTTPS certificate problem, remote not started: {0}
err.fatal=Error: {0}
err.fw_disabled=Windows Firewall is turned off ({0}). Turn it on and try again.
err.fw_stopped=Windows Firewall is stopped: cannot block the Internet.
err.noca=No ZerkiWatch certificate found. Restart ZerkiWatch as administrator.
err.oldversion=An older version of Mode reseau is still running.\nRight-click its icon near the clock, choose Quit, then start the program again.
err.ranges=Could not compute the address ranges.
err.rule_not_created=firewall rule not created
err.rules_inactive=The blocking rules are not active.
err.rules_left=Some blocking rules are still present.
err.unavailable=Feature not available on this PC
foot.noip=iPhone remote active on port {0}\nPassword: {1} (PC IP address not found)
foot.off=iPhone remote unavailable: {0}
foot.remote=iPhone (same Wi-Fi): {0}\nPassword: {1}
hist.bymonth=BY MONTH
hist.d30=30 days
hist.d7=7 days
hist.h1=1 h
hist.h24=24 h
hist.last7=LAST 7 DAYS
hist.legend_app=Application
hist.legend_svc=Service
hist.nodata=No data yet
hist.nodata_period=No data yet for this period
hist.perf=PERFORMANCE (%)
hist.received=Received
hist.recv=Download
hist.sendw=Upload
hist.sent=Sent
hist.speed=SPEED (Mbps)
hist.title=HISTORY
hist.title_win=ZerkiWatch - History
hist.today=Today
hist.today_caps=TODAY
hist.top=TOP CONSUMERS
hist.total=Total: {0}
items.cpu=CPU
items.dl=Download
items.dsk=Disk
items.full=Full
items.gpu=GPU
items.mini=Mini (speed only)
items.mode=Network mode
items.ram=RAM
items.ul=Upload
lang.name=English
menu.auto=Start with Windows
menu.bar=Floating bar
menu.bar_full=Floating bar (CPU, RAM, speed)
menu.big=Large
menu.cumul=Continuous per-app totals
menu.cut=Cut Internet
menu.cut_15=15 minutes
menu.cut_30=30 minutes
menu.cut_60=1 hour
menu.cut_cancel=Cancel automatic return
menu.cut_timed=Cut Internet for...
menu.cut_tomorrow=Until tomorrow 7:00
menu.cut_until=Internet returns at {0}
menu.disk=Disk
menu.disks=Displayed disks
menu.dock=Integrate into the taskbar
menu.history=History...
menu.hotkey=Keyboard shortcut
menu.hotkey_cur=Keyboard shortcut: {0}
menu.hotkey_enable=Enable the shortcut
menu.hotkey_off=Keyboard shortcut: off
menu.iphone=iPhone remote...
menu.items=Bar contents
menu.lang_auto=Automatic
menu.language=Language
menu.log=Open the log
menu.nodisks=No disk detected
menu.normal=Normal
menu.open=Open ZerkiWatch
menu.quit=Quit
menu.removable=Removable
menu.reset=Reset bar position
menu.restore=Restore Internet
menu.settings=Settings...
menu.size=Bar size
menu.small=Small
menu.top=Keep bar on top
menu.widget=Desktop widget (movable)
menu.wizard=Setup assistant...
p.apps=APPLICATIONS
p.badpw=Wrong password.
p.busy=The PC is busy, try again.
p.bymonth=BY MONTH
p.cancel=Cancel
p.changepw=Enter the password
p.connecting=Connecting...
p.cut_15=15 min
p.cut_30=30 min
p.cut_60=1 h
p.cut_back=Internet returns in {0}
p.cut_cancel=Cancel
p.cut_title=CUT INTERNET FOR
p.cut_tomorrow=Until tomorrow 7:00
p.d30=30 days
p.d7=7 days
p.days=Sun,Mon,Tue,Wed,Thu,Fri,Sat
p.dec=.
p.disks=DISKS
p.err=Error: {0}
p.h1=1 h
p.h24=24 h
p.history=HISTORY
p.l_cancel=Cancelled.
p.l_lock=PC locked.
p.l_restart=Restart scheduled in 30 s.
p.l_screen=Screen off (move the mouse to wake it).
p.l_shutdown=Shutdown scheduled in 30 s.
p.l_sleep=Going to sleep\u2026
p.last7=LAST 7 DAYS
p.legend_app=Application
p.legend_svc=Service
p.live=LIVE SPEED
p.lock=Lock
p.net_off=LOCAL ONLY
p.net_off_sub=The Internet is cut on the PC. The local network works.
p.net_on=INTERNET ON
p.net_on_sub=Tap the switch to cut the Internet on the PC.
p.noact=No notable activity
p.nodata=No data yet
p.nodata_top=No data yet
p.nodisk=No disk selected
p.noetw=Per-app measurement unavailable
p.noresp=No response from the PC.
p.perf=PERFORMANCE
p.perf_pct=PERFORMANCE (%)
p.power=POWER
p.pwprompt=Password:
p.q_restart=Restart the PC in 30 seconds?
p.q_shutdown=Shut down the PC in 30 seconds?
p.q_sleep=Put the PC to sleep? It will no longer be reachable from the iPhone.
p.recv=Download
p.restart=Restart
p.restart_in=Restarting in {0} s
p.screen=Turn off screen
p.send=Upload
p.services=WINDOWS SERVICES
p.shutdown=Shut down PC
p.shutdown_in=Shutting down in {0} s
p.sleep=Sleep
p.speed_mbps=SPEED (Mbps)
p.today=Today
p.today_rx=Today, downloaded
p.today_tx=Today, uploaded
p.toomany=Too many attempts: wait 1 minute.
p.top=TOP CONSUMERS
p.unit_g=GB
p.unit_k=KB
p.unit_m=MB
p.unit_t=TB
p.unreach=PC unreachable.
p.unreach2=PC unreachable: same Wi-Fi? Is the program running?
p.usage=USAGE
p.wait=Please wait...
pin.addr=Address (same Wi-Fi): {0}
pin.cancel=Cancel
pin.cert=iPhone certificate
pin.invalid=Password too short (4 characters minimum).
pin.label=Password (4 characters minimum):
pin.noaddr=PC IP address not found
pin.off=The remote is not active.
pin.save=Save
pin.title=iPhone remote
power.reason=ZerkiWatch: request from the iPhone
set.alert_cut=Alert when Internet stays cut for
set.alert_speed=Alert when traffic exceeds
set.alerts=Alerts
set.close=Close
set.display=Display
set.general=General
set.min=min
set.pw=Password / address...
set.remote=iPhone remote
set.theme=Theme
set.theme_auto=Automatic (Windows)
set.theme_blue=Midnight blue
set.theme_dark=Dark
set.theme_gray=Grey
set.theme_green=Green
set.theme_light=Light (beta)
set.theme_violet=Violet
set.title=ZerkiWatch settings
short.all={0} - Down {1} - Up {2} Mbps - CPU {3} % - RAM {4} %
short.cpu=CPU {0} %
short.local=Local mode (Internet off)
short.on=Internet on
short.ram=RAM {0} %
short.speed=Down {0} / Up {1} Mbps
tip.click=Click the icon: cut / restore Internet
tip.cpu=CPU: {0} %
tip.disk=Disk {0}: {1} / {2} ({3} %), activity {4} %
tip.disk_none=Disk: none
tip.gpu=GPU: {0} %
tip.gpu_none=GPU: --
tip.link=Link: {0}
tip.net=Network: {0}
tip.net_default=network
tip.net_none=none
tip.ram=RAM: {0} / {1} ({2} %)
tip.rate=Down: {0} Mbps    Up: {1} Mbps
tip.total=Total (session): {0} downloaded, {1} uploaded
tip.unknown=unknown
tip.vram=VRAM: {0} / {1}
ui.accessible=Reachable
ui.accessible_bang=Reachable!
ui.all_ok=Everything is fine.
ui.apps=APPLICATIONS
ui.blocked=Blocked (as intended)
ui.blocked_nobox=The Internet is blocked. Your router does not answer ping (normal on some routers): test a device on your local network.
ui.box_noping=No ping response
ui.box_ok=Router reachable
ui.cores={0} logical cores
ui.cpu=PROCESSOR
ui.cpu_load=Overall load
ui.cut_for=Cut for
ui.disks=DISKS
ui.error=Error: {0}
ui.gpu_default=Graphics card
ui.gpu_load=Graphics load
ui.gpu_nocounter=Counter unavailable
ui.history=History
ui.iphone=iPhone
ui.local=LOCAL ONLY
ui.local_net=Local network
ui.local_sub=The Internet is cut for this PC. The local network (router, NAS, printer, other devices) works.
ui.mbps_in=Mbps received
ui.network=NETWORK
ui.no_internet=No Internet: check the router, the Wi-Fi or a VPN.
ui.noact=No notable activity
ui.nodisk=No disk selected
ui.noetw=Per-app measurement unavailable
ui.on=INTERNET ON
ui.on_sub=Normal Internet connection. Click the switch to cut the Internet.
ui.ram=MEMORY
ui.ram_used=Memory in use
ui.recv=DOWNLOAD
ui.retest=Retest
ui.send=UPLOAD
ui.services=WINDOWS SERVICES
ui.settings=Settings
ui.tab_home=Home
ui.tab_perf=Performance
ui.testing=Testing...
ui.unreachable=Unreachable
ui.vram=VRAM {0} / {1}
ui.wait=Please wait...
ui.warn_still=Warning: the Internet still answers. A VPN, a proxy or connection sharing bypasses the block.
unit.g=GB
unit.k=KB
unit.m=MB
unit.t=TB
wiz.cert_hint=To use the iPhone remote without a browser warning, install the ZerkiWatch certificate on your iPhone once (steps and QR code in the window above).
wiz.finish=Finish
wiz.intro=A few quick choices to get started. You can change everything later and reopen this window from the tray menu.
wiz.lang=Language
wiz.pin=iPhone remote password (you can keep the generated one):
wiz.skip=Skip
wiz.title=Welcome to ZerkiWatch
[es]
about.btn=Actualizaciones / acerca de...
about.newer=Hay una versi\u00f3n {0} disponible.
about.offline=No se pudo contactar con GitHub (\u00bfsin conexi\u00f3n?).
about.open=\u00bfAbrir la p\u00e1gina de descarga?
about.startup=Buscar actualizaciones al iniciar (desactivado por defecto)
about.uptodate=Est\u00e1 al d\u00eda.
app.others=Otros (procesos finalizados)
app.system=Sistema Windows (compartido, kernel)
bal.alert_cut=Internet lleva cortado {0} min.
bal.alert_speed=Tr\u00e1fico alto: {0} Mbps.
bal.alert_speed_app=Tr\u00e1fico alto: {0} Mbps (principal: {1}).
bal.autostart_fail=No se pudo iniciar con Windows: {0}
bal.bar_hidden=La barra flotante est\u00e1 oculta. Haz clic derecho en el icono de la bandeja y elige Barra flotante para mostrarla de nuevo.
bal.busy=Ya hay un cambio en curso, espera un momento.
bal.cut=Modo local: Internet desactivado
bal.cut_end=Tiempo cumplido: Internet restablecido.
bal.cut_timed=Internet cortado hasta las {0}; despu\u00e9s se restablece solo.
bal.dock_na=La integraci\u00f3n en la barra de tareas no est\u00e1 disponible en este PC.
bal.dock_notaskbar=Barra de tareas no encontrada o vertical: la integraci\u00f3n solo funciona con una barra de tareas horizontal (abajo o arriba).
bal.hk_used=El atajo {0} ya lo usa otro programa. Elige otro en el men\u00fa, Atajo de teclado.
bal.lang_restart=Reiniciando para aplicar el idioma...
bal.minimized=El programa sigue en ejecuci\u00f3n junto al reloj. Haz clic derecho en el icono para salir.
bal.power=Apagado o reinicio solicitado desde el iPhone: 30 segundos para cancelar.
bal.restored=Internet restablecido
bal.theme_restart=Reiniciando para aplicar el tema...
bar.internet=INTERNET
bar.local=LOCAL
bar.title=Monitor del sistema
cert.fail=Error al exportar el certificado: {0}
cert.help=Archivo guardado: {0}\n\nEn el iPhone (misma Wi-Fi):\n1. Env\u00eda este archivo al iPhone (AirDrop, correo, iCloud Drive) o abre {2} en Safari y pulsa Permitir para descargar el perfil.\n2. Ajustes > Perfil descargado > Instalar.\n3. Ajustes > General > Informaci\u00f3n > Ajustes de confianza de certificados > activa \u00abZerkiWatch Local CA\u00bb.\n4. Comprueba la huella SHA-256 en los detalles del certificado del iPhone:\n{1}\n\nDespu\u00e9s vuelve a abrir la direcci\u00f3n del mando.
cert.qr=Escanea este c\u00f3digo con la c\u00e1mara del iPhone. En Safari, toca Mostrar detalles, luego Visitar este sitio web, y Permite la descarga del certificado.
err.bind=no se pudo asociar el certificado al puerto ({0})
err.cert=Problema con el certificado HTTPS, mando no iniciado: {0}
err.fatal=Error: {0}
err.fw_disabled=El Firewall de Windows est\u00e1 desactivado ({0}). Act\u00edvalo e int\u00e9ntalo de nuevo.
err.fw_stopped=El Firewall de Windows est\u00e1 detenido: no se puede bloquear Internet.
err.noca=No se encontr\u00f3 ning\u00fan certificado de ZerkiWatch. Reinicia ZerkiWatch como administrador.
err.oldversion=Una versi\u00f3n anterior de Mode reseau sigue en ejecuci\u00f3n.\nHaz clic derecho en su icono junto al reloj, elige Salir y vuelve a iniciar el programa.
err.ranges=No se pudieron calcular los rangos de direcciones.
err.rule_not_created=regla de firewall no creada
err.rules_inactive=Las reglas de bloqueo no est\u00e1n activas.
err.rules_left=Todav\u00eda quedan algunas reglas de bloqueo.
err.unavailable=Funci\u00f3n no disponible en este PC
foot.noip=Control remoto iPhone activo en el puerto {0}\nContrase\u00f1a: {1} (direcci\u00f3n IP del PC no encontrada)
foot.off=Control remoto iPhone no disponible: {0}
foot.remote=iPhone (mismo Wi-Fi): {0}\nContrase\u00f1a: {1}
hist.bymonth=POR MES
hist.d30=30 d\u00edas
hist.d7=7 d\u00edas
hist.h1=1 h
hist.h24=24 h
hist.last7=\u00daLTIMOS 7 D\u00cdAS
hist.legend_app=Aplicaci\u00f3n
hist.legend_svc=Servicio
hist.nodata=A\u00fan sin datos
hist.nodata_period=A\u00fan sin datos para este per\u00edodo
hist.perf=RENDIMIENTO (%)
hist.received=Recibido
hist.recv=Descarga
hist.sendw=Subida
hist.sent=Enviado
hist.speed=VELOCIDAD (Mbps)
hist.title=HISTORIAL
hist.title_win=ZerkiWatch - Historial
hist.today=Hoy
hist.today_caps=HOY
hist.top=MAYORES CONSUMOS
hist.total=Total: {0}
items.cpu=CPU
items.dl=Descarga
items.dsk=Disco
items.full=Completa
items.gpu=GPU
items.mini=Mini (solo velocidad)
items.mode=Modo de red
items.ram=RAM
items.ul=Subida
lang.name=Espa\u00f1ol
menu.auto=Iniciar con Windows
menu.bar=Barra flotante
menu.bar_full=Barra flotante (CPU, RAM, velocidad)
menu.big=Grande
menu.cumul=Totales continuos por app
menu.cut=Cortar Internet
menu.cut_15=15 minutos
menu.cut_30=30 minutos
menu.cut_60=1 hora
menu.cut_cancel=Cancelar el regreso autom\u00e1tico
menu.cut_timed=Cortar Internet durante...
menu.cut_tomorrow=Hasta ma\u00f1ana a las 7:00
menu.cut_until=Internet vuelve a las {0}
menu.disk=Disco
menu.disks=Discos mostrados
menu.dock=Integrar en la barra de tareas
menu.history=Historial...
menu.hotkey=Atajo de teclado
menu.hotkey_cur=Atajo de teclado: {0}
menu.hotkey_enable=Activar el atajo
menu.hotkey_off=Atajo de teclado: desactivado
menu.iphone=Control remoto iPhone...
menu.items=Contenido de la barra
menu.lang_auto=Autom\u00e1tico
menu.language=Idioma
menu.log=Abrir el registro
menu.nodisks=Ning\u00fan disco detectado
menu.normal=Normal
menu.open=Abrir ZerkiWatch
menu.quit=Salir
menu.removable=Extra\u00edble
menu.reset=Restablecer posici\u00f3n de la barra
menu.restore=Restablecer Internet
menu.settings=Ajustes...
menu.size=Tama\u00f1o de la barra
menu.small=Peque\u00f1a
menu.top=Mantener la barra al frente
menu.widget=Widget en el escritorio (movible)
menu.wizard=Asistente de configuraci\u00f3n...
p.apps=APLICACIONES
p.badpw=Contrase\u00f1a incorrecta.
p.busy=El PC est\u00e1 ocupado, int\u00e9ntalo de nuevo.
p.bymonth=POR MES
p.cancel=Cancelar
p.changepw=Introduce la contrase\u00f1a
p.connecting=Conectando...
p.cut_15=15 min
p.cut_30=30 min
p.cut_60=1 h
p.cut_back=Internet vuelve en {0}
p.cut_cancel=Cancelar
p.cut_title=CORTAR INTERNET DURANTE
p.cut_tomorrow=Hasta ma\u00f1ana 7:00
p.d30=30 d\u00edas
p.d7=7 d\u00edas
p.days=Dom,Lun,Mar,Mi\u00e9,Jue,Vie,S\u00e1b
p.dec=,
p.disks=DISCOS
p.err=Error: {0}
p.h1=1 h
p.h24=24 h
p.history=HISTORIAL
p.l_cancel=Cancelado.
p.l_lock=PC bloqueado.
p.l_restart=Reinicio programado en 30 s.
p.l_screen=Pantalla apagada (mueve el rat\u00f3n para activarla).
p.l_shutdown=Apagado programado en 30 s.
p.l_sleep=Suspendiendo\u2026
p.last7=\u00daLTIMOS 7 D\u00cdAS
p.legend_app=Aplicaci\u00f3n
p.legend_svc=Servicio
p.live=VELOCIDAD EN VIVO
p.lock=Bloquear
p.net_off=SOLO LOCAL
p.net_off_sub=Internet est\u00e1 cortado en el PC. La red local funciona.
p.net_on=INTERNET ACTIVO
p.net_on_sub=Toca el interruptor para cortar Internet en el PC.
p.noact=Sin actividad notable
p.nodata=A\u00fan sin datos
p.nodata_top=A\u00fan sin datos
p.nodisk=Ning\u00fan disco seleccionado
p.noetw=Medici\u00f3n por app no disponible
p.noresp=Sin respuesta del PC.
p.perf=RENDIMIENTO
p.perf_pct=RENDIMIENTO (%)
p.power=ENERG\u00cdA
p.pwprompt=Contrase\u00f1a:
p.q_restart=\u00bfReiniciar el PC en 30 segundos?
p.q_shutdown=\u00bfApagar el PC en 30 segundos?
p.q_sleep=\u00bfSuspender el PC? Ya no se podr\u00e1 acceder a \u00e9l desde el iPhone.
p.recv=Descarga
p.restart=Reiniciar
p.restart_in=Reiniciando en {0} s
p.screen=Apagar pantalla
p.send=Subida
p.services=SERVICIOS DE WINDOWS
p.shutdown=Apagar PC
p.shutdown_in=Apagando en {0} s
p.sleep=Suspender
p.speed_mbps=VELOCIDAD (Mbps)
p.today=Hoy
p.today_rx=Hoy, descargado
p.today_tx=Hoy, subido
p.toomany=Demasiados intentos: espera 1 minuto.
p.top=MAYORES CONSUMOS
p.unit_g=GB
p.unit_k=KB
p.unit_m=MB
p.unit_t=TB
p.unreach=PC inaccesible.
p.unreach2=PC inaccesible: \u00bfmismo Wi-Fi? \u00bfEl programa est\u00e1 en ejecuci\u00f3n?
p.usage=USO
p.wait=Espera...
pin.addr=Direcci\u00f3n (mismo Wi-Fi): {0}
pin.cancel=Cancelar
pin.cert=Certificado iPhone
pin.invalid=Contrase\u00f1a demasiado corta (m\u00ednimo 4 caracteres).
pin.label=Contrase\u00f1a (m\u00ednimo 4 caracteres):
pin.noaddr=Direcci\u00f3n IP del PC no encontrada
pin.off=El control remoto no est\u00e1 activo.
pin.save=Guardar
pin.title=Control remoto iPhone
power.reason=ZerkiWatch: solicitud desde el iPhone
set.alert_cut=Avisar si Internet sigue cortado
set.alert_speed=Avisar si el tr\u00e1fico supera
set.alerts=Alertas
set.close=Cerrar
set.display=Pantalla
set.general=General
set.min=min
set.pw=Contrase\u00f1a / direcci\u00f3n...
set.remote=Mando del iPhone
set.theme=Tema
set.theme_auto=Autom\u00e1tico (Windows)
set.theme_blue=Azul noche
set.theme_dark=Oscuro
set.theme_gray=Gris
set.theme_green=Verde
set.theme_light=Claro (beta)
set.theme_violet=Violeta
set.title=Ajustes de ZerkiWatch
short.all={0} - Baj. {1} - Sub. {2} Mbps - CPU {3} % - RAM {4} %
short.cpu=CPU {0} %
short.local=Modo local (Internet desactivado)
short.on=Internet activo
short.ram=RAM {0} %
short.speed=Baj. {0} / Sub. {1} Mbps
tip.click=Clic en el icono: cortar / restablecer Internet
tip.cpu=CPU: {0} %
tip.disk=Disco {0}: {1} / {2} ({3} %), actividad {4} %
tip.disk_none=Disco: ninguno
tip.gpu=GPU: {0} %
tip.gpu_none=GPU: --
tip.link=Enlace: {0}
tip.net=Red: {0}
tip.net_default=red
tip.net_none=ninguna
tip.ram=RAM: {0} / {1} ({2} %)
tip.rate=Bajada: {0} Mbps    Subida: {1} Mbps
tip.total=Total (sesi\u00f3n): {0} descargados, {1} subidos
tip.unknown=desconocido
tip.vram=VRAM: {0} / {1}
ui.accessible=Accesible
ui.accessible_bang=\u00a1Accesible!
ui.all_ok=Todo est\u00e1 bien.
ui.apps=APLICACIONES
ui.blocked=Bloqueado (como se esperaba)
ui.blocked_nobox=Internet est\u00e1 bloqueado. Tu router no responde al ping (normal en algunos routers): prueba con un dispositivo de tu red local.
ui.box_noping=Sin respuesta al ping
ui.box_ok=Router accesible
ui.cores={0} n\u00facleos l\u00f3gicos
ui.cpu=PROCESADOR
ui.cpu_load=Carga global
ui.cut_for=Cortar durante
ui.disks=DISCOS
ui.error=Error: {0}
ui.gpu_default=Tarjeta gr\u00e1fica
ui.gpu_load=Carga gr\u00e1fica
ui.gpu_nocounter=Contador no disponible
ui.history=Historial
ui.iphone=iPhone
ui.local=SOLO LOCAL
ui.local_net=Red local
ui.local_sub=Internet est\u00e1 cortado para este PC. La red local (router, NAS, impresora, otros dispositivos) funciona.
ui.mbps_in=Mbps recibidos
ui.network=RED
ui.no_internet=Sin Internet: revisa el router, el Wi-Fi o una VPN.
ui.noact=Sin actividad notable
ui.nodisk=Ning\u00fan disco seleccionado
ui.noetw=Medici\u00f3n por app no disponible
ui.on=INTERNET ACTIVO
ui.on_sub=Conexi\u00f3n a Internet normal. Haz clic en el interruptor para cortar Internet.
ui.ram=MEMORIA
ui.ram_used=Memoria en uso
ui.recv=DESCARGA
ui.retest=Repetir
ui.send=SUBIDA
ui.services=SERVICIOS DE WINDOWS
ui.settings=Ajustes
ui.tab_home=Inicio
ui.tab_perf=Rendimiento
ui.testing=Probando...
ui.unreachable=Inaccesible
ui.vram=VRAM {0} / {1}
ui.wait=Espera...
ui.warn_still=Atenci\u00f3n: Internet sigue respondiendo. Una VPN, un proxy o la conexi\u00f3n compartida eluden el bloqueo.
unit.g=GB
unit.k=KB
unit.m=MB
unit.t=TB
wiz.cert_hint=Para usar el mando del iPhone sin aviso del navegador, instala una vez el certificado de ZerkiWatch en tu iPhone (pasos y c\u00f3digo QR en la ventana de arriba).
wiz.finish=Terminar
wiz.intro=Unas elecciones r\u00e1pidas para empezar. Podr\u00e1s cambiarlo todo despu\u00e9s y reabrir esta ventana desde el men\u00fa del icono.
wiz.lang=Idioma
wiz.pin=Contrase\u00f1a del mando del iPhone (puedes conservar la generada):
wiz.skip=Omitir
wiz.title=Bienvenido a ZerkiWatch
[fr]
about.btn=Mises \u00e0 jour / \u00e0 propos...
about.newer=La version {0} est disponible.
about.offline=GitHub injoignable (hors ligne ?).
about.open=Ouvrir la page de t\u00e9l\u00e9chargement ?
about.startup=V\u00e9rifier les mises \u00e0 jour au d\u00e9marrage (d\u00e9sactiv\u00e9 par d\u00e9faut)
about.uptodate=Vous \u00eates \u00e0 jour.
app.others=Autres (processus termin\u00e9s)
app.system=Syst\u00e8me Windows (partages, noyau)
bal.alert_cut=Internet est coup\u00e9 depuis {0} min.
bal.alert_speed=Trafic \u00e9lev\u00e9 : {0} Mbps.
bal.alert_speed_app=Trafic \u00e9lev\u00e9 : {0} Mbps (principal : {1}).
bal.autostart_fail=Lancement avec Windows impossible : {0}
bal.bar_hidden=La barre flottante est masqu\u00e9e. Clic droit sur l'ic\u00f4ne, puis Barre flottante pour la r\u00e9afficher.
bal.busy=Changement d\u00e9j\u00e0 en cours, patientez.
bal.cut=Mode local : Internet coup\u00e9
bal.cut_end=D\u00e9lai termin\u00e9 : Internet remis.
bal.cut_timed=Internet coup\u00e9 jusqu'\u00e0 {0}, puis remis automatiquement.
bal.dock_na=Int\u00e9gration indisponible sur ce PC.
bal.dock_notaskbar=Barre des t\u00e2ches introuvable ou verticale : l'int\u00e9gration n'est possible qu'avec une barre des t\u00e2ches horizontale (en bas ou en haut).
bal.hk_used=Le raccourci {0} est d\u00e9j\u00e0 utilis\u00e9 par un autre programme. Choisissez-en un autre dans le menu, Raccourci clavier.
bal.lang_restart=Red\u00e9marrage pour appliquer la langue...
bal.minimized=Le programme continue pr\u00e8s de l'horloge. Clic droit sur l'ic\u00f4ne pour quitter.
bal.power=Arr\u00eat ou red\u00e9marrage demand\u00e9 depuis l'iPhone : 30 secondes pour annuler.
bal.restored=Internet r\u00e9activ\u00e9
bal.theme_restart=Red\u00e9marrage pour appliquer le th\u00e8me...
bar.internet=INTERNET
bar.local=LOCAL
bar.title=Moniteur syst\u00e8me
cert.fail=\u00c9chec de l'export du certificat : {0}
cert.help=Fichier enregistr\u00e9 : {0}\n\nSur l'iPhone (m\u00eame Wi-Fi) :\n1. Envoyez ce fichier \u00e0 l'iPhone (AirDrop, mail, iCloud Drive) ou ouvrez {2} dans Safari et appuyez sur Autoriser pour t\u00e9l\u00e9charger le profil.\n2. R\u00e9glages > Profil t\u00e9l\u00e9charg\u00e9 > Installer.\n3. R\u00e9glages > G\u00e9n\u00e9ral > Informations > R\u00e9glages des certificats de confiance > activez \u00ab ZerkiWatch Local CA \u00bb.\n4. V\u00e9rifiez l'empreinte SHA-256 dans les d\u00e9tails du certificat sur l'iPhone :\n{1}\n\nRouvrez ensuite l'adresse de la t\u00e9l\u00e9commande.
cert.qr=Scannez ce code avec l'appareil photo de l'iPhone. Dans Safari, touchez Afficher les d\u00e9tails, puis Visiter ce site web, et Autorisez le t\u00e9l\u00e9chargement du certificat.
err.bind=impossible de lier le certificat au port ({0})
err.cert=Probl\u00e8me de certificat HTTPS, t\u00e9l\u00e9commande non d\u00e9marr\u00e9e : {0}
err.fatal=Erreur : {0}
err.fw_disabled=Le pare-feu Windows est d\u00e9sactiv\u00e9 ({0}). Activez-le puis recommencez.
err.fw_stopped=Le pare-feu Windows est arr\u00eat\u00e9 : impossible de bloquer Internet.
err.noca=Aucun certificat ZerkiWatch trouv\u00e9. Relancez ZerkiWatch en administrateur.
err.oldversion=Une ancienne version de Mode r\u00e9seau tourne encore.\nFaites un clic droit sur son ic\u00f4ne pr\u00e8s de l'horloge, puis Quitter, et relancez le programme.
err.ranges=Calcul des plages impossible.
err.rule_not_created=r\u00e8gle pare-feu non cr\u00e9\u00e9e
err.rules_inactive=Les r\u00e8gles de blocage ne sont pas actives.
err.rules_left=Des r\u00e8gles de blocage sont encore pr\u00e9sentes.
err.unavailable=Fonction indisponible sur ce PC
foot.noip=T\u00e9l\u00e9commande iPhone active sur le port {0}\nMot de passe : {1} (adresse IP du PC introuvable)
foot.off=T\u00e9l\u00e9commande iPhone indisponible : {0}
foot.remote=iPhone (m\u00eame Wi-Fi) : {0}\nMot de passe : {1}
hist.bymonth=PAR MOIS
hist.d30=30 jours
hist.d7=7 jours
hist.h1=1 h
hist.h24=24 h
hist.last7=7 DERNIERS JOURS
hist.legend_app=Application
hist.legend_svc=Service
hist.nodata=Aucune donn\u00e9e pour le moment
hist.nodata_period=Pas encore de donn\u00e9es sur cette p\u00e9riode
hist.perf=PERFORMANCES (%)
hist.received=Re\u00e7u
hist.recv=R\u00e9ception
hist.sendw=Envoi
hist.sent=Envoy\u00e9
hist.speed=D\u00c9BIT (Mbps)
hist.title=HISTORIQUE
hist.title_win=ZerkiWatch - Historique
hist.today=Aujourd'hui
hist.today_caps=AUJOURD'HUI
hist.top=GROS CONSOMMATEURS
hist.total=Total : {0}
items.cpu=CPU
items.dl=R\u00e9ception
items.dsk=Disque
items.full=Complet
items.gpu=GPU
items.mini=Mini (d\u00e9bit seul)
items.mode=Mode r\u00e9seau
items.ram=RAM
items.ul=Envoi
lang.name=Fran\u00e7ais
menu.auto=Lancer avec Windows
menu.bar=Barre flottante
menu.bar_full=Barre flottante (CPU, RAM, d\u00e9bit)
menu.big=Grand
menu.cumul=Cumul par application en continu
menu.cut=Couper Internet
menu.cut_15=15 minutes
menu.cut_30=30 minutes
menu.cut_60=1 heure
menu.cut_cancel=Annuler le retour automatique
menu.cut_timed=Couper Internet pendant...
menu.cut_tomorrow=Jusqu'\u00e0 demain 7 h
menu.cut_until=Internet revient \u00e0 {0}
menu.disk=Disque
menu.disks=Disques affich\u00e9s
menu.dock=Int\u00e9grer \u00e0 la barre des t\u00e2ches
menu.history=Historique...
menu.hotkey=Raccourci clavier
menu.hotkey_cur=Raccourci clavier : {0}
menu.hotkey_enable=Activer le raccourci
menu.hotkey_off=Raccourci clavier : d\u00e9sactiv\u00e9
menu.iphone=T\u00e9l\u00e9commande iPhone...
menu.items=Contenu de la barre
menu.lang_auto=Automatique
menu.language=Langue
menu.log=Ouvrir le journal
menu.nodisks=Aucun disque d\u00e9tect\u00e9
menu.normal=Normal
menu.open=Ouvrir ZerkiWatch
menu.quit=Quitter
menu.removable=Amovible
menu.reset=Remettre la barre en place
menu.restore=R\u00e9activer Internet
menu.settings=R\u00e9glages...
menu.size=Taille de la barre
menu.small=Petit
menu.top=Barre toujours au premier plan
menu.widget=Widget sur le bureau (d\u00e9pla\u00e7able)
menu.wizard=Assistant de configuration...
p.apps=APPLICATIONS
p.badpw=Mot de passe incorrect.
p.busy=Le PC est occup\u00e9, r\u00e9essayez.
p.bymonth=PAR MOIS
p.cancel=Annuler
p.changepw=Saisir le mot de passe
p.connecting=Connexion...
p.cut_15=15 min
p.cut_30=30 min
p.cut_60=1 h
p.cut_back=Internet revient dans {0}
p.cut_cancel=Annuler
p.cut_title=COUPER INTERNET PENDANT
p.cut_tomorrow=Jusqu'\u00e0 demain 7 h
p.d30=30 jours
p.d7=7 jours
p.days=dim.,lun.,mar.,mer.,jeu.,ven.,sam.
p.dec=,
p.disks=DISQUES
p.err=Erreur : {0}
p.h1=1 h
p.h24=24 h
p.history=HISTORIQUE
p.l_cancel=Annul\u00e9.
p.l_lock=PC verrouill\u00e9.
p.l_restart=Red\u00e9marrage programm\u00e9 dans 30 s.
p.l_screen=\u00c9cran \u00e9teint (bougez la souris pour le rallumer).
p.l_shutdown=Arr\u00eat programm\u00e9 dans 30 s.
p.l_sleep=Mise en veille en cours\u2026
p.last7=7 DERNIERS JOURS
p.legend_app=Application
p.legend_svc=Service
p.live=D\u00c9BIT EN DIRECT
p.lock=Verrouiller
p.net_off=LOCAL UNIQUEMENT
p.net_off_sub=Internet est coup\u00e9 sur le PC. Le r\u00e9seau local fonctionne.
p.net_on=INTERNET ACTIF
p.net_on_sub=Touchez le bouton pour couper Internet sur le PC.
p.noact=Aucune activit\u00e9 notable
p.nodata=Pas encore de donn\u00e9es
p.nodata_top=Aucune donn\u00e9e pour le moment
p.nodisk=Aucun disque choisi
p.noetw=Mesure par application indisponible
p.noresp=Pas de r\u00e9ponse du PC.
p.perf=PERFORMANCES
p.perf_pct=PERFORMANCES (%)
p.power=ALIMENTATION
p.pwprompt=Mot de passe :
p.q_restart=Red\u00e9marrer le PC dans 30 secondes ?
p.q_shutdown=\u00c9teindre le PC dans 30 secondes ?
p.q_sleep=Mettre le PC en veille ? Il ne sera plus joignable depuis l\u2019iPhone.
p.recv=R\u00e9ception
p.restart=Red\u00e9marrer
p.restart_in=Red\u00e9marrage dans {0} s
p.screen=\u00c9teindre l'\u00e9cran
p.send=Envoi
p.services=SERVICES WINDOWS
p.shutdown=\u00c9teindre le PC
p.shutdown_in=Arr\u00eat dans {0} s
p.sleep=Mettre en veille
p.speed_mbps=D\u00c9BIT (Mbps)
p.today=Aujourd'hui
p.today_rx=Aujourd'hui, re\u00e7u
p.today_tx=Aujourd'hui, envoy\u00e9
p.toomany=Trop d\u2019essais : patientez 1 minute.
p.top=GROS CONSOMMATEURS
p.unit_g=Go
p.unit_k=Ko
p.unit_m=Mo
p.unit_t=To
p.unreach=PC injoignable.
p.unreach2=PC injoignable : m\u00eame Wi-Fi ? Le programme est-il ouvert ?
p.usage=CONSOMMATION
p.wait=Patientez...
pin.addr=Adresse (m\u00eame Wi-Fi) : {0}
pin.cancel=Annuler
pin.cert=Certificat iPhone
pin.invalid=Mot de passe trop court (4 caract\u00e8res minimum).
pin.label=Mot de passe (4 caract\u00e8res minimum) :
pin.noaddr=Adresse IP du PC introuvable
pin.off=La t\u00e9l\u00e9commande n'est pas active.
pin.save=Enregistrer
pin.title=T\u00e9l\u00e9commande iPhone
power.reason=ZerkiWatch : demande depuis l'iPhone
set.alert_cut=Alerter si Internet reste coup\u00e9
set.alert_speed=Alerter si le trafic d\u00e9passe
set.alerts=Alertes
set.close=Fermer
set.display=Affichage
set.general=G\u00e9n\u00e9ral
set.min=min
set.pw=Mot de passe / adresse...
set.remote=T\u00e9l\u00e9commande iPhone
set.theme=Th\u00e8me
set.theme_auto=Automatique (Windows)
set.theme_blue=Bleu nuit
set.theme_dark=Sombre
set.theme_gray=Gris
set.theme_green=Vert
set.theme_light=Clair (b\u00eata)
set.theme_violet=Violet
set.title=R\u00e9glages ZerkiWatch
short.all={0} - Re\u00e7u {1} - Envoi {2} Mbps - CPU {3} % - RAM {4} %
short.cpu=CPU {0} %
short.local=Mode local (Internet coup\u00e9)
short.on=Internet actif
short.ram=RAM {0} %
short.speed=Re\u00e7u {0} / Envoi {1} Mbps
tip.click=Clic sur l'ic\u00f4ne : couper / r\u00e9activer Internet
tip.cpu=CPU : {0} %
tip.disk=Disque {0} : {1} / {2} ({3} %), activit\u00e9 {4} %
tip.disk_none=Disque : aucun
tip.gpu=GPU : {0} %
tip.gpu_none=GPU : --
tip.link=Liaison : {0}
tip.net=R\u00e9seau : {0}
tip.net_default=r\u00e9seau
tip.net_none=aucun
tip.ram=RAM : {0} / {1} ({2} %)
tip.rate=Re\u00e7u : {0} Mbps    Envoy\u00e9 : {1} Mbps
tip.total=Total (session) : {0} re\u00e7us, {1} envoy\u00e9s
tip.unknown=inconnue
tip.vram=VRAM : {0} / {1}
ui.accessible=Accessible
ui.accessible_bang=Accessible !
ui.all_ok=Tout est en ordre.
ui.apps=APPLICATIONS
ui.blocked=Bloqu\u00e9 (voulu)
ui.blocked_nobox=Internet est bloqu\u00e9. Votre box ne r\u00e9pond pas au ping (normal sur certaines box) : testez un appareil de votre r\u00e9seau local.
ui.box_noping=Pas de r\u00e9ponse au ping
ui.box_ok=Box joignable
ui.cores={0} c\u0153urs logiques
ui.cpu=PROCESSEUR
ui.cpu_load=Charge globale
ui.cut_for=Couper pendant
ui.disks=DISQUES
ui.error=Erreur : {0}
ui.gpu_default=Carte graphique
ui.gpu_load=Charge graphique
ui.gpu_nocounter=Compteur indisponible
ui.history=Historique
ui.iphone=iPhone
ui.local=LOCAL UNIQUEMENT
ui.local_net=R\u00e9seau local
ui.local_sub=Internet est coup\u00e9 pour ce PC. Le r\u00e9seau local (box, NAS, imprimante, autres appareils) fonctionne.
ui.mbps_in=Mbps en r\u00e9ception
ui.network=R\u00c9SEAU
ui.no_internet=Pas d'Internet : v\u00e9rifiez la box, le Wi-Fi ou un VPN.
ui.noact=Aucune activit\u00e9 notable
ui.nodisk=Aucun disque choisi
ui.noetw=Mesure par application indisponible
ui.on=INTERNET ACTIF
ui.on_sub=Connexion Internet normale. Cliquez sur le bouton pour couper Internet.
ui.ram=M\u00c9MOIRE
ui.ram_used=M\u00e9moire utilis\u00e9e
ui.recv=R\u00c9CEPTION
ui.retest=Retester
ui.send=ENVOI
ui.services=SERVICES WINDOWS
ui.settings=R\u00e9glages
ui.tab_home=Accueil
ui.tab_perf=Performances
ui.testing=Test en cours...
ui.unreachable=Injoignable
ui.vram=VRAM {0} / {1}
ui.wait=Patientez...
ui.warn_still=Attention : Internet r\u00e9pond encore. Un VPN, un proxy ou un partage de connexion contourne le blocage.
unit.g=Go
unit.k=Ko
unit.m=Mo
unit.t=To
wiz.cert_hint=Pour utiliser la t\u00e9l\u00e9commande iPhone sans avertissement du navigateur, installez une fois le certificat ZerkiWatch sur votre iPhone (\u00e9tapes et QR code dans la fen\u00eatre ci-dessus).
wiz.finish=Terminer
wiz.intro=Quelques choix rapides pour d\u00e9marrer. Vous pourrez tout modifier plus tard et rouvrir cette fen\u00eatre depuis le menu de l'ic\u00f4ne.
wiz.lang=Langue
wiz.pin=Mot de passe de la t\u00e9l\u00e9commande iPhone (vous pouvez garder celui g\u00e9n\u00e9r\u00e9) :
wiz.skip=Passer
wiz.title=Bienvenue dans ZerkiWatch
[it]
about.btn=Aggiornamenti / informazioni...
about.newer=\u00c8 disponibile la versione {0}.
about.offline=GitHub non raggiungibile (offline?).
about.open=Aprire la pagina di download?
about.startup=Cerca aggiornamenti all'avvio (disattivato di default)
about.uptodate=Sei aggiornato.
app.others=Altri (processi terminati)
app.system=Sistema Windows (condivisi, kernel)
bal.alert_cut=Internet \u00e8 interrotto da {0} min.
bal.alert_speed=Traffico elevato: {0} Mbps.
bal.alert_speed_app=Traffico elevato: {0} Mbps (principale: {1}).
bal.autostart_fail=Impossibile avviare con Windows: {0}
bal.bar_hidden=La barra mobile \u00e8 nascosta. Clic destro sull'icona nell'area di notifica, poi Barra mobile per mostrarla di nuovo.
bal.busy=Un cambio \u00e8 gi\u00e0 in corso, attendi.
bal.cut=Modalit\u00e0 locale: Internet disattivato
bal.cut_end=Tempo scaduto: Internet ripristinato.
bal.cut_timed=Internet interrotto fino alle {0}, poi ripristinato automaticamente.
bal.dock_na=L'integrazione nella barra delle applicazioni non \u00e8 disponibile su questo PC.
bal.dock_notaskbar=Barra delle applicazioni non trovata o verticale: l'integrazione funziona solo con una barra orizzontale (in basso o in alto).
bal.hk_used=La scorciatoia {0} \u00e8 gi\u00e0 usata da un altro programma. Scegline un'altra nel menu, Scorciatoia da tastiera.
bal.lang_restart=Riavvio per applicare la lingua...
bal.minimized=Il programma resta attivo vicino all'orologio. Clic destro sull'icona per uscire.
bal.power=Arresto o riavvio richiesto dall'iPhone: 30 secondi per annullare.
bal.restored=Internet ripristinato
bal.theme_restart=Riavvio per applicare il tema...
bar.internet=INTERNET
bar.local=LOCALE
bar.title=Monitor di sistema
cert.fail=Esportazione del certificato non riuscita: {0}
cert.help=File salvato: {0}\n\nSu iPhone (stessa Wi-Fi):\n1. Invia questo file all'iPhone (AirDrop, mail, iCloud Drive) oppure apri {2} in Safari e tocca Consenti per scaricare il profilo.\n2. Impostazioni > Profilo scaricato > Installa.\n3. Impostazioni > Generali > Info > Impostazioni certificati attendibili > attiva \u00abZerkiWatch Local CA\u00bb.\n4. Verifica l'impronta SHA-256 nei dettagli del certificato su iPhone:\n{1}\n\nPoi riapri l'indirizzo del telecomando.
cert.qr=Inquadra questo codice con la fotocamera dell'iPhone. In Safari tocca Mostra dettagli, poi Visita questo sito web, e consenti il download del certificato.
err.bind=impossibile associare il certificato alla porta ({0})
err.cert=Problema con il certificato HTTPS, telecomando non avviato: {0}
err.fatal=Errore: {0}
err.fw_disabled=Windows Firewall \u00e8 disattivato ({0}). Attivalo e riprova.
err.fw_stopped=Windows Firewall \u00e8 arrestato: impossibile bloccare Internet.
err.noca=Nessun certificato ZerkiWatch trovato. Riavvia ZerkiWatch come amministratore.
err.oldversion=Una versione precedente di Mode reseau \u00e8 ancora in esecuzione.\nClic destro sulla sua icona vicino all'orologio, scegli Esci, poi riavvia il programma.
err.ranges=Impossibile calcolare gli intervalli di indirizzi.
err.rule_not_created=regola del firewall non creata
err.rules_inactive=Le regole di blocco non sono attive.
err.rules_left=Alcune regole di blocco sono ancora presenti.
err.unavailable=Funzione non disponibile su questo PC
foot.noip=Remoto iPhone attivo sulla porta {0}\nPassword: {1} (indirizzo IP del PC non trovato)
foot.off=Remoto iPhone non disponibile: {0}
foot.remote=iPhone (stesso Wi-Fi): {0}\nPassword: {1}
hist.bymonth=PER MESE
hist.d30=30 gg
hist.d7=7 gg
hist.h1=1 h
hist.h24=24 h
hist.last7=ULTIMI 7 GIORNI
hist.legend_app=Applicazione
hist.legend_svc=Servizio
hist.nodata=Ancora nessun dato
hist.nodata_period=Ancora nessun dato per questo periodo
hist.perf=PRESTAZIONI (%)
hist.received=Ricevuti
hist.recv=Download
hist.sendw=Upload
hist.sent=Inviati
hist.speed=VELOCIT\u00c0 (Mbps)
hist.title=CRONOLOGIA
hist.title_win=ZerkiWatch - Cronologia
hist.today=Oggi
hist.today_caps=OGGI
hist.top=MAGGIORI CONSUMI
hist.total=Totale: {0}
items.cpu=CPU
items.dl=Ricezione
items.dsk=Disco
items.full=Completa
items.gpu=GPU
items.mini=Mini (solo velocit\u00e0)
items.mode=Modalit\u00e0 di rete
items.ram=RAM
items.ul=Invio
lang.name=Italiano
menu.auto=Avvia con Windows
menu.bar=Barra mobile
menu.bar_full=Barra mobile (CPU, RAM, velocit\u00e0)
menu.big=Grande
menu.cumul=Totali per app continui
menu.cut=Disattiva Internet
menu.cut_15=15 minuti
menu.cut_30=30 minuti
menu.cut_60=1 ora
menu.cut_cancel=Annulla il ripristino automatico
menu.cut_timed=Interrompi Internet per...
menu.cut_tomorrow=Fino a domani alle 7:00
menu.cut_until=Internet torna alle {0}
menu.disk=Disco
menu.disks=Dischi mostrati
menu.dock=Integra nella barra delle applicazioni
menu.history=Cronologia...
menu.hotkey=Scorciatoia da tastiera
menu.hotkey_cur=Scorciatoia da tastiera: {0}
menu.hotkey_enable=Abilita la scorciatoia
menu.hotkey_off=Scorciatoia da tastiera: no
menu.iphone=Remoto iPhone...
menu.items=Contenuto della barra
menu.lang_auto=Automatica
menu.language=Lingua
menu.log=Apri il registro
menu.nodisks=Nessun disco rilevato
menu.normal=Normale
menu.open=Apri ZerkiWatch
menu.quit=Esci
menu.removable=Rimovibile
menu.reset=Reimposta posizione barra
menu.restore=Ripristina Internet
menu.settings=Impostazioni...
menu.size=Dimensione barra
menu.small=Piccola
menu.top=Barra sempre in primo piano
menu.widget=Widget sul desktop (spostabile)
menu.wizard=Configurazione guidata...
p.apps=APPLICAZIONI
p.badpw=Password errata.
p.busy=Il PC \u00e8 occupato, riprova.
p.bymonth=PER MESE
p.cancel=Annulla
p.changepw=Inserisci la password
p.connecting=Connessione...
p.cut_15=15 min
p.cut_30=30 min
p.cut_60=1 h
p.cut_back=Internet torna tra {0}
p.cut_cancel=Annulla
p.cut_title=INTERROMPI INTERNET PER
p.cut_tomorrow=Fino a domani 7:00
p.d30=30 gg
p.d7=7 gg
p.days=Dom,Lun,Mar,Mer,Gio,Ven,Sab
p.dec=,
p.disks=DISCHI
p.err=Errore: {0}
p.h1=1 h
p.h24=24 h
p.history=CRONOLOGIA
p.l_cancel=Annullato.
p.l_lock=PC bloccato.
p.l_restart=Riavvio programmato tra 30 s.
p.l_screen=Schermo spento (muovi il mouse per riattivarlo).
p.l_shutdown=Arresto programmato tra 30 s.
p.l_sleep=Sospensione in corso\u2026
p.last7=ULTIMI 7 GIORNI
p.legend_app=Applicazione
p.legend_svc=Servizio
p.live=VELOCIT\u00c0 LIVE
p.lock=Blocca
p.net_off=SOLO LOCALE
p.net_off_sub=Internet \u00e8 disattivato sul PC. La rete locale funziona.
p.net_on=INTERNET ATTIVO
p.net_on_sub=Tocca l'interruttore per disattivare Internet sul PC.
p.noact=Nessuna attivit\u00e0 rilevante
p.nodata=Ancora nessun dato
p.nodata_top=Ancora nessun dato
p.nodisk=Nessun disco selezionato
p.noetw=Misurazione per app non disponibile
p.noresp=Nessuna risposta dal PC.
p.perf=PRESTAZIONI
p.perf_pct=PRESTAZIONI (%)
p.power=ALIMENTAZIONE
p.pwprompt=Password:
p.q_restart=Riavviare il PC tra 30 secondi?
p.q_shutdown=Arrestare il PC tra 30 secondi?
p.q_sleep=Mettere il PC in sospensione? Non sar\u00e0 pi\u00f9 raggiungibile dall'iPhone.
p.recv=Download
p.restart=Riavvia
p.restart_in=Riavvio tra {0} s
p.screen=Spegni schermo
p.send=Upload
p.services=SERVIZI WINDOWS
p.shutdown=Arresta PC
p.shutdown_in=Arresto tra {0} s
p.sleep=Sospendi
p.speed_mbps=VELOCIT\u00c0 (Mbps)
p.today=Oggi
p.today_rx=Oggi, scaricati
p.today_tx=Oggi, inviati
p.toomany=Troppi tentativi: attendi 1 minuto.
p.top=MAGGIORI CONSUMI
p.unit_g=GB
p.unit_k=KB
p.unit_m=MB
p.unit_t=TB
p.unreach=PC non raggiungibile.
p.unreach2=PC non raggiungibile: stesso Wi-Fi? Il programma \u00e8 in esecuzione?
p.usage=UTILIZZO
p.wait=Attendi...
pin.addr=Indirizzo (stesso Wi-Fi): {0}
pin.cancel=Annulla
pin.cert=Certificato iPhone
pin.invalid=Password troppo corta (minimo 4 caratteri).
pin.label=Password (minimo 4 caratteri):
pin.noaddr=Indirizzo IP del PC non trovato
pin.off=Il remoto non \u00e8 attivo.
pin.save=Salva
pin.title=Remoto iPhone
power.reason=ZerkiWatch: richiesta dall'iPhone
set.alert_cut=Avvisa se Internet resta interrotto per
set.alert_speed=Avvisa se il traffico supera
set.alerts=Avvisi
set.close=Chiudi
set.display=Schermo
set.general=Generale
set.min=min
set.pw=Password / indirizzo...
set.remote=Telecomando iPhone
set.theme=Tema
set.theme_auto=Automatico (Windows)
set.theme_blue=Blu notte
set.theme_dark=Scuro
set.theme_gray=Grigio
set.theme_green=Verde
set.theme_light=Chiaro (beta)
set.theme_violet=Viola
set.title=Impostazioni ZerkiWatch
short.all={0} - Down {1} - Up {2} Mbps - CPU {3} % - RAM {4} %
short.cpu=CPU {0} %
short.local=Modalit\u00e0 locale (Internet off)
short.on=Internet attivo
short.ram=RAM {0} %
short.speed=Down {0} / Up {1} Mbps
tip.click=Clic sull'icona: disattiva / ripristina Internet
tip.cpu=CPU: {0} %
tip.disk=Disco {0}: {1} / {2} ({3} %), attivit\u00e0 {4} %
tip.disk_none=Disco: nessuno
tip.gpu=GPU: {0} %
tip.gpu_none=GPU: --
tip.link=Collegamento: {0}
tip.net=Rete: {0}
tip.net_default=rete
tip.net_none=nessuna
tip.ram=RAM: {0} / {1} ({2} %)
tip.rate=Down: {0} Mbps    Up: {1} Mbps
tip.total=Totale (sessione): {0} scaricati, {1} inviati
tip.unknown=sconosciuto
tip.vram=VRAM: {0} / {1}
ui.accessible=Raggiungibile
ui.accessible_bang=Raggiungibile!
ui.all_ok=Tutto a posto.
ui.apps=APPLICAZIONI
ui.blocked=Bloccato (come previsto)
ui.blocked_nobox=Internet \u00e8 bloccato. Il router non risponde al ping (normale su alcuni router): prova un dispositivo della rete locale.
ui.box_noping=Nessuna risposta al ping
ui.box_ok=Router raggiungibile
ui.cores={0} core logici
ui.cpu=PROCESSORE
ui.cpu_load=Carico complessivo
ui.cut_for=Interrompi per
ui.disks=DISCHI
ui.error=Errore: {0}
ui.gpu_default=Scheda video
ui.gpu_load=Carico grafico
ui.gpu_nocounter=Contatore non disponibile
ui.history=Cronologia
ui.iphone=iPhone
ui.local=SOLO LOCALE
ui.local_net=Rete locale
ui.local_sub=Internet \u00e8 disattivato per questo PC. La rete locale (router, NAS, stampante, altri dispositivi) funziona.
ui.mbps_in=Mbps in ricezione
ui.network=RETE
ui.no_internet=Nessun Internet: controlla il router, il Wi-Fi o una VPN.
ui.noact=Nessuna attivit\u00e0 rilevante
ui.nodisk=Nessun disco selezionato
ui.noetw=Misurazione per app non disponibile
ui.on=INTERNET ATTIVO
ui.on_sub=Connessione Internet normale. Clicca l'interruttore per disattivare Internet.
ui.ram=MEMORIA
ui.ram_used=Memoria in uso
ui.recv=DOWNLOAD
ui.retest=Riprova
ui.send=UPLOAD
ui.services=SERVIZI WINDOWS
ui.settings=Impostazioni
ui.tab_home=Home
ui.tab_perf=Prestazioni
ui.testing=Test in corso...
ui.unreachable=Non raggiungibile
ui.vram=VRAM {0} / {1}
ui.wait=Attendi...
ui.warn_still=Attenzione: Internet risponde ancora. Una VPN, un proxy o la condivisione della connessione aggirano il blocco.
unit.g=GB
unit.k=KB
unit.m=MB
unit.t=TB
wiz.cert_hint=Per usare il telecomando iPhone senza avviso del browser, installa una volta il certificato ZerkiWatch sul tuo iPhone (passaggi e codice QR nella finestra sopra).
wiz.finish=Fine
wiz.intro=Poche scelte rapide per iniziare. Potrai cambiare tutto in seguito e riaprire questa finestra dal menu dell'icona.
wiz.lang=Lingua
wiz.pin=Password del telecomando iPhone (puoi tenere quella generata):
wiz.skip=Salta
wiz.title=Benvenuto in ZerkiWatch
[pt]
about.btn=Atualiza\u00e7\u00f5es / acerca...
about.newer=A vers\u00e3o {0} est\u00e1 dispon\u00edvel.
about.offline=GitHub inacess\u00edvel (offline?).
about.open=Abrir a p\u00e1gina de download?
about.startup=Procurar atualiza\u00e7\u00f5es ao iniciar (desativado por defeito)
about.uptodate=Est\u00e1 atualizado.
app.others=Outros (processos encerrados)
app.system=Sistema Windows (compartilhado, kernel)
bal.alert_cut=A Internet est\u00e1 cortada h\u00e1 {0} min.
bal.alert_speed=Tr\u00e1fego elevado: {0} Mbps.
bal.alert_speed_app=Tr\u00e1fego elevado: {0} Mbps (principal: {1}).
bal.autostart_fail=N\u00e3o foi poss\u00edvel iniciar com o Windows: {0}
bal.bar_hidden=A barra flutuante est\u00e1 oculta. Clique com o bot\u00e3o direito no \u00edcone da bandeja e depois em Barra flutuante para exibi-la novamente.
bal.busy=Uma altern\u00e2ncia j\u00e1 est\u00e1 em andamento, aguarde.
bal.cut=Modo local: Internet desligada
bal.cut_end=Tempo esgotado: Internet reposta.
bal.cut_timed=Internet cortada at\u00e9 \u00e0s {0}; depois \u00e9 reposta automaticamente.
bal.dock_na=A integra\u00e7\u00e3o \u00e0 barra de tarefas n\u00e3o est\u00e1 dispon\u00edvel neste PC.
bal.dock_notaskbar=Barra de tarefas n\u00e3o encontrada ou vertical: a integra\u00e7\u00e3o s\u00f3 funciona com uma barra de tarefas horizontal (embaixo ou no topo).
bal.hk_used=O atalho {0} j\u00e1 est\u00e1 sendo usado por outro programa. Escolha outro no menu, Atalho de teclado.
bal.lang_restart=Reiniciando para aplicar o idioma...
bal.minimized=O programa continua em execu\u00e7\u00e3o perto do rel\u00f3gio. Clique com o bot\u00e3o direito no \u00edcone para sair.
bal.power=Desligamento ou reinicializa\u00e7\u00e3o solicitado pelo iPhone: 30 segundos para cancelar.
bal.restored=Internet restaurada
bal.theme_restart=A reiniciar para aplicar o tema...
bar.internet=INTERNET
bar.local=LOCAL
bar.title=Monitor do sistema
cert.fail=Falha ao exportar o certificado: {0}
cert.help=Ficheiro guardado: {0}\n\nNo iPhone (mesmo Wi-Fi):\n1. Envie este ficheiro para o iPhone (AirDrop, e-mail, iCloud Drive) ou abra {2} no Safari e toque em Permitir para transferir o perfil.\n2. Defini\u00e7\u00f5es > Perfil transferido > Instalar.\n3. Defini\u00e7\u00f5es > Geral > Informa\u00e7\u00e3o > Defini\u00e7\u00f5es de confian\u00e7a de certificados > ative \u00abZerkiWatch Local CA\u00bb.\n4. Verifique a impress\u00e3o digital SHA-256 nos detalhes do certificado no iPhone:\n{1}\n\nDepois abra novamente o endere\u00e7o do controlo remoto.
cert.qr=Leia este c\u00f3digo com a c\u00e2mara do iPhone. No Safari, toque em Mostrar detalhes, depois Visitar este site, e permita a transfer\u00eancia do certificado.
err.bind=n\u00e3o foi poss\u00edvel associar o certificado \u00e0 porta ({0})
err.cert=Problema com o certificado HTTPS, controlo remoto n\u00e3o iniciado: {0}
err.fatal=Erro: {0}
err.fw_disabled=O Firewall do Windows est\u00e1 desativado ({0}). Ative-o e tente novamente.
err.fw_stopped=O Firewall do Windows est\u00e1 parado: n\u00e3o \u00e9 poss\u00edvel bloquear a Internet.
err.noca=Nenhum certificado ZerkiWatch encontrado. Reinicie o ZerkiWatch como administrador.
err.oldversion=Uma vers\u00e3o antiga do Mode reseau ainda est\u00e1 em execu\u00e7\u00e3o.\nClique com o bot\u00e3o direito no \u00edcone dela perto do rel\u00f3gio, escolha Sair e inicie o programa novamente.
err.ranges=N\u00e3o foi poss\u00edvel calcular as faixas de endere\u00e7os.
err.rule_not_created=regra de firewall n\u00e3o criada
err.rules_inactive=As regras de bloqueio n\u00e3o est\u00e3o ativas.
err.rules_left=Ainda existem regras de bloqueio.
err.unavailable=Recurso indispon\u00edvel neste PC
foot.noip=Controle remoto do iPhone ativo na porta {0}\nSenha: {1} (endere\u00e7o IP do PC n\u00e3o encontrado)
foot.off=Controle remoto do iPhone indispon\u00edvel: {0}
foot.remote=iPhone (mesmo Wi-Fi): {0}\nSenha: {1}
hist.bymonth=POR M\u00caS
hist.d30=30 dias
hist.d7=7 dias
hist.h1=1 h
hist.h24=24 h
hist.last7=\u00daLTIMOS 7 DIAS
hist.legend_app=Aplicativo
hist.legend_svc=Servi\u00e7o
hist.nodata=Ainda sem dados
hist.nodata_period=Ainda sem dados neste per\u00edodo
hist.perf=DESEMPENHO (%)
hist.received=Recebido
hist.recv=Download
hist.sendw=Upload
hist.sent=Enviado
hist.speed=VELOCIDADE (Mbps)
hist.title=HIST\u00d3RICO
hist.title_win=ZerkiWatch - Hist\u00f3rico
hist.today=Hoje
hist.today_caps=HOJE
hist.top=MAIORES CONSUMIDORES
hist.total=Total: {0}
items.cpu=CPU
items.dl=Rece\u00e7\u00e3o
items.dsk=Disco
items.full=Completa
items.gpu=GPU
items.mini=Mini (s\u00f3 velocidade)
items.mode=Modo de rede
items.ram=RAM
items.ul=Envio
lang.name=Portugu\u00eas
menu.auto=Iniciar com o Windows
menu.bar=Barra flutuante
menu.bar_full=Barra flutuante (CPU, RAM, velocidade)
menu.big=Grande
menu.cumul=Total cont\u00ednuo por aplicativo
menu.cut=Cortar a Internet
menu.cut_15=15 minutos
menu.cut_30=30 minutos
menu.cut_60=1 hora
menu.cut_cancel=Cancelar o regresso autom\u00e1tico
menu.cut_timed=Cortar a Internet durante...
menu.cut_tomorrow=At\u00e9 amanh\u00e3 \u00e0s 7:00
menu.cut_until=A Internet volta \u00e0s {0}
menu.disk=Disco
menu.disks=Discos exibidos
menu.dock=Integrar \u00e0 barra de tarefas
menu.history=Hist\u00f3rico...
menu.hotkey=Atalho de teclado
menu.hotkey_cur=Atalho de teclado: {0}
menu.hotkey_enable=Ativar o atalho
menu.hotkey_off=Atalho de teclado: desativado
menu.iphone=Controle remoto do iPhone...
menu.items=Conte\u00fado da barra
menu.lang_auto=Autom\u00e1tico
menu.language=Idioma
menu.log=Abrir o registro
menu.nodisks=Nenhum disco detectado
menu.normal=Normal
menu.open=Abrir o ZerkiWatch
menu.quit=Sair
menu.removable=Remov\u00edvel
menu.reset=Redefinir posi\u00e7\u00e3o da barra
menu.restore=Restaurar a Internet
menu.settings=Defini\u00e7\u00f5es...
menu.size=Tamanho da barra
menu.small=Pequeno
menu.top=Manter a barra no topo
menu.widget=Widget no ambiente de trabalho (mov\u00edvel)
menu.wizard=Assistente de configura\u00e7\u00e3o...
p.apps=APLICATIVOS
p.badpw=Senha incorreta.
p.busy=O PC est\u00e1 ocupado, tente novamente.
p.bymonth=POR M\u00caS
p.cancel=Cancelar
p.changepw=Digite a senha
p.connecting=Conectando...
p.cut_15=15 min
p.cut_30=30 min
p.cut_60=1 h
p.cut_back=A Internet volta em {0}
p.cut_cancel=Cancelar
p.cut_title=CORTAR A INTERNET DURANTE
p.cut_tomorrow=At\u00e9 amanh\u00e3 7:00
p.d30=30 dias
p.d7=7 dias
p.days=dom,seg,ter,qua,qui,sex,s\u00e1b
p.dec=,
p.disks=DISCOS
p.err=Erro: {0}
p.h1=1 h
p.h24=24 h
p.history=HIST\u00d3RICO
p.l_cancel=Cancelado.
p.l_lock=PC bloqueado.
p.l_restart=Reinicializa\u00e7\u00e3o agendada em 30 s.
p.l_screen=Tela desligada (mova o mouse para ativ\u00e1-la).
p.l_shutdown=Desligamento agendado em 30 s.
p.l_sleep=Entrando em suspens\u00e3o\u2026
p.last7=\u00daLTIMOS 7 DIAS
p.legend_app=Aplicativo
p.legend_svc=Servi\u00e7o
p.live=VELOCIDADE AO VIVO
p.lock=Bloquear
p.net_off=S\u00d3 LOCAL
p.net_off_sub=A Internet est\u00e1 cortada no PC. A rede local funciona.
p.net_on=INTERNET ON
p.net_on_sub=Toque no bot\u00e3o para cortar a Internet no PC.
p.noact=Sem atividade not\u00e1vel
p.nodata=Ainda sem dados
p.nodata_top=Ainda sem dados
p.nodisk=Nenhum disco selecionado
p.noetw=Medi\u00e7\u00e3o por aplicativo indispon\u00edvel
p.noresp=Sem resposta do PC.
p.perf=DESEMPENHO
p.perf_pct=DESEMPENHO (%)
p.power=ENERGIA
p.pwprompt=Senha:
p.q_restart=Reiniciar o PC em 30 segundos?
p.q_shutdown=Desligar o PC em 30 segundos?
p.q_sleep=Colocar o PC em suspens\u00e3o? Ele n\u00e3o ficar\u00e1 mais acess\u00edvel pelo iPhone.
p.recv=Download
p.restart=Reiniciar
p.restart_in=Reiniciando em {0} s
p.screen=Desligar tela
p.send=Upload
p.services=SERVI\u00c7OS DO WINDOWS
p.shutdown=Desligar PC
p.shutdown_in=Desligando em {0} s
p.sleep=Suspender
p.speed_mbps=VELOCIDADE (Mbps)
p.today=Hoje
p.today_rx=Hoje, baixado
p.today_tx=Hoje, enviado
p.toomany=Muitas tentativas: aguarde 1 minuto.
p.top=MAIORES CONSUMIDORES
p.unit_g=GB
p.unit_k=KB
p.unit_m=MB
p.unit_t=TB
p.unreach=PC inacess\u00edvel.
p.unreach2=PC inacess\u00edvel: mesmo Wi-Fi? O programa est\u00e1 aberto?
p.usage=USO
p.wait=Aguarde...
pin.addr=Endere\u00e7o (mesmo Wi-Fi): {0}
pin.cancel=Cancelar
pin.cert=Certificado iPhone
pin.invalid=Senha muito curta (m\u00ednimo de 4 caracteres).
pin.label=Senha (m\u00ednimo de 4 caracteres):
pin.noaddr=Endere\u00e7o IP do PC n\u00e3o encontrado
pin.off=O controle remoto n\u00e3o est\u00e1 ativo.
pin.save=Salvar
pin.title=Controle remoto do iPhone
power.reason=ZerkiWatch: solicita\u00e7\u00e3o do iPhone
set.alert_cut=Avisar se a Internet ficar cortada
set.alert_speed=Avisar se o tr\u00e1fego exceder
set.alerts=Alertas
set.close=Fechar
set.display=Ecr\u00e3
set.general=Geral
set.min=min
set.pw=Palavra-passe / endere\u00e7o...
set.remote=Controlo remoto do iPhone
set.theme=Tema
set.theme_auto=Autom\u00e1tico (Windows)
set.theme_blue=Azul noite
set.theme_dark=Escuro
set.theme_gray=Cinzento
set.theme_green=Verde
set.theme_light=Claro (beta)
set.theme_violet=Violeta
set.title=Defini\u00e7\u00f5es do ZerkiWatch
short.all={0} - Down {1} - Up {2} Mbps - CPU {3} % - RAM {4} %
short.cpu=CPU {0} %
short.local=Modo local (Internet desligada)
short.on=Internet ligada
short.ram=RAM {0} %
short.speed=Down {0} / Up {1} Mbps
tip.click=Clique no \u00edcone: cortar / restaurar a Internet
tip.cpu=CPU: {0} %
tip.disk=Disco {0}: {1} / {2} ({3} %), atividade {4} %
tip.disk_none=Disco: nenhum
tip.gpu=GPU: {0} %
tip.gpu_none=GPU: --
tip.link=Link: {0}
tip.net=Rede: {0}
tip.net_default=rede
tip.net_none=nenhuma
tip.ram=RAM: {0} / {1} ({2} %)
tip.rate=Down: {0} Mbps    Up: {1} Mbps
tip.total=Total (sess\u00e3o): {0} baixados, {1} enviados
tip.unknown=desconhecido
tip.vram=VRAM: {0} / {1}
ui.accessible=Acess\u00edvel
ui.accessible_bang=Acess\u00edvel!
ui.all_ok=Est\u00e1 tudo certo.
ui.apps=APLICATIVOS
ui.blocked=Bloqueado (como esperado)
ui.blocked_nobox=A Internet est\u00e1 bloqueada. Seu roteador n\u00e3o responde ao ping (normal em alguns roteadores): teste um dispositivo da sua rede local.
ui.box_noping=Sem resposta ao ping
ui.box_ok=Roteador acess\u00edvel
ui.cores={0} n\u00facleos l\u00f3gicos
ui.cpu=PROCESSADOR
ui.cpu_load=Carga geral
ui.cut_for=Cortar durante
ui.disks=DISCOS
ui.error=Erro: {0}
ui.gpu_default=Placa de v\u00eddeo
ui.gpu_load=Carga gr\u00e1fica
ui.gpu_nocounter=Contador indispon\u00edvel
ui.history=Hist\u00f3rico
ui.iphone=iPhone
ui.local=S\u00d3 LOCAL
ui.local_net=Rede local
ui.local_sub=A Internet est\u00e1 cortada para este PC. A rede local (roteador, NAS, impressora, outros dispositivos) funciona.
ui.mbps_in=Mbps recebidos
ui.network=REDE
ui.no_internet=Sem Internet: verifique o roteador, o Wi-Fi ou uma VPN.
ui.noact=Sem atividade not\u00e1vel
ui.nodisk=Nenhum disco selecionado
ui.noetw=Medi\u00e7\u00e3o por aplicativo indispon\u00edvel
ui.on=INTERNET ON
ui.on_sub=Conex\u00e3o normal com a Internet. Clique no bot\u00e3o para cortar a Internet.
ui.ram=MEM\u00d3RIA
ui.ram_used=Mem\u00f3ria em uso
ui.recv=DOWNLOAD
ui.retest=Testar de novo
ui.send=UPLOAD
ui.services=SERVI\u00c7OS DO WINDOWS
ui.settings=Defini\u00e7\u00f5es
ui.tab_home=In\u00edcio
ui.tab_perf=Desempenho
ui.testing=Testando...
ui.unreachable=Inacess\u00edvel
ui.vram=VRAM {0} / {1}
ui.wait=Aguarde...
ui.warn_still=Aten\u00e7\u00e3o: a Internet ainda responde. Uma VPN, um proxy ou o compartilhamento de conex\u00e3o contorna o bloqueio.
unit.g=GB
unit.k=KB
unit.m=MB
unit.t=TB
wiz.cert_hint=Para usar o controlo remoto do iPhone sem aviso do navegador, instale uma vez o certificado do ZerkiWatch no iPhone (passos e c\u00f3digo QR na janela acima).
wiz.finish=Concluir
wiz.intro=Algumas escolhas r\u00e1pidas para come\u00e7ar. Pode alterar tudo depois e reabrir esta janela a partir do menu do \u00edcone.
wiz.lang=Idioma
wiz.pin=Palavra-passe do controlo remoto do iPhone (pode manter a gerada):
wiz.skip=Saltar
wiz.title=Bem-vindo ao ZerkiWatch
'@
# LANGDATA END
Add-LangLines ($langData -split "`n") ''
try {
    $selfPath0 = $env:SELF
    if (-not $selfPath0) { $selfPath0 = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName }
    foreach ($ld in @((Join-Path (Split-Path -Parent $selfPath0) 'lang'), (Join-Path $logDir 'lang'))) {
        if (Test-Path -LiteralPath $ld) {
            foreach ($lf in @(Get-ChildItem -LiteralPath $ld -Filter '*.txt' -ErrorAction SilentlyContinue)) {
                try { Add-LangLines ([System.IO.File]::ReadAllLines($lf.FullName, [System.Text.Encoding]::UTF8)) ($lf.BaseName.ToLower()) } catch { }
            }
        }
    }
} catch { }
$LangCode = ''
$ThemePref = 'dark'
try {
    $cfgPath0 = Join-Path $logDir 'config.txt'
    if (Test-Path -LiteralPath $cfgPath0) {
        foreach ($ln0 in [System.IO.File]::ReadAllLines($cfgPath0)) {
            if ($ln0.StartsWith('Lang=')) { $LangCode = $ln0.Substring(5).Trim().ToLower() }
            if ($ln0.StartsWith('Theme=')) { $ThemePref = $ln0.Substring(6).Trim().ToLower() }
        }
    }
} catch { }
$LangPref = $LangCode
# Theme: dark (default) | light | auto (follows Windows). Applied at start; changing it restarts the app.
if (@('dark', 'light', 'auto', 'blue', 'violet', 'green', 'gray') -notcontains $ThemePref) { $ThemePref = 'dark' }
$ThemeLight = ($ThemePref -eq 'light')
if ($ThemePref -eq 'auto') {
    try { $ThemeLight = ((Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -ErrorAction Stop).AppsUseLightTheme -eq 1) } catch { $ThemeLight = $false }
}
$ThemeVariants = @{
    blue   = @{ '17,18,22' = @(11,17,28); '25,27,33' = @(17,26,43); '44,47,56' = @(33,48,76); '140,146,158' = @(128,146,176); '30,32,39' = @(22,34,58); '52,56,66' = @(44,62,98); '238,240,244' = @(235,242,255); '74,222,129' = @(56,189,248) }
    violet = @{ '17,18,22' = @(16,13,26); '25,27,33' = @(25,20,41); '44,47,56' = @(48,39,78); '140,146,158' = @(150,138,180); '30,32,39' = @(33,26,56); '52,56,66' = @(62,50,100); '238,240,244' = @(243,238,255); '74,222,129' = @(167,139,250) }
    green  = @{ '17,18,22' = @(10,19,16); '25,27,33' = @(16,29,24); '44,47,56' = @(31,54,45); '140,146,158' = @(125,160,145); '30,32,39' = @(20,38,31); '52,56,66' = @(40,70,58); '238,240,244' = @(236,250,243); '74,222,129' = @(74,222,128) }
    gray   = @{ '17,18,22' = @(24,24,24); '25,27,33' = @(33,33,33); '44,47,56' = @(58,58,58); '140,146,158' = @(150,150,150); '30,32,39' = @(40,40,40); '52,56,66' = @(70,70,70); '238,240,244' = @(240,240,240); '74,222,129' = @(200,200,200) }
}
function Pc([int[]]$d, [int[]]$l) {
    $v = $d
    if ($ThemeLight) { $v = $l }
    elseif ($ThemeVariants.ContainsKey($ThemePref)) {
        $kk = ([string]$d[0] + ',' + [string]$d[1] + ',' + [string]$d[2])
        if ($ThemeVariants[$ThemePref].ContainsKey($kk)) { $v = $ThemeVariants[$ThemePref][$kk] }
    }
    return [System.Drawing.Color]::FromArgb($v[0], $v[1], $v[2])
}
# Overlay line colour: white on the dark theme, black on the light one
function Get-Ov([int]$a) {
    if ($ThemeLight) { return [System.Drawing.Color]::FromArgb($a, 0, 0, 0) }
    return [System.Drawing.Color]::FromArgb($a, 255, 255, 255)
}
if (($LangCode -eq '') -or (-not $LangDb.ContainsKey($LangCode))) {
    $LangCode = 'en'
    try {
        $cc = [System.Globalization.CultureInfo]::CurrentUICulture
        foreach ($cand in @($cc.Name.ToLower(), $cc.TwoLetterISOLanguageName.ToLower())) { if ($LangDb.ContainsKey($cand)) { $LangCode = $cand; break } }
    } catch { }
}
if (-not $LangDb.ContainsKey($LangCode)) { $LangCode = 'fr' }
$LangCulture = [System.Globalization.CultureInfo]::InvariantCulture
try { $LangCulture = New-Object System.Globalization.CultureInfo($LangCode) } catch { }
function T([string]$k) {
    foreach ($c in @($LangCode, 'en', 'fr')) {
        if ($LangDb.ContainsKey($c) -and $LangDb[$c].ContainsKey($k)) { return [string]$LangDb[$c][$k] }
    }
    return $k
}
function Tf([string]$k, [object[]]$a) {
    try { return [string]::Format((T $k), $a) } catch { return (T $k) }
}

# ---------- Single instance ----------
$myId = [System.Diagnostics.Process]::GetCurrentProcess().Id
$createdNew = $false
$mutex = New-Object System.Threading.Mutex($true, 'Local\ZerkiWatchApp', [ref]$createdNew)
$showEvt = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\ZerkiWatchShow')
if (-not $createdNew) { [void]$showEvt.Set(); exit }
function Test-OldRun {
    foreach ($nm in @('Local\ModeReseauApp', 'Local\ModeReseauApp51', 'Local\ModeReseauApp54')) {
        try { $om = [System.Threading.Mutex]::OpenExisting($nm); $om.Dispose(); return $true } catch { }
    }
    return $false
}
$oldRun = Test-OldRun
if ($oldRun) {
    Write-Log 'Previous Mode reseau version detected, stopping it'
    try {
        foreach ($op in @(Get-Process -Name 'Mode-Reseau' -ErrorAction SilentlyContinue)) {
            if ($op.Id -ne $myId) { Write-Log ('Old version stopped (pid ' + $op.Id + ')'); $op.Kill(); [void]$op.WaitForExit(3000) }
        }
    } catch { }
    try {
        foreach ($cp in @(Get-CimInstance -ClassName Win32_Process -Filter "Name='powershell.exe'" -ErrorAction Stop)) {
            if (([int]$cp.ProcessId -ne $myId) -and ([string]$cp.CommandLine).Contains('IndexOf(''#PS''')) {
                Write-Log ('Old version stopped (powershell pid ' + $cp.ProcessId + ')')
                try { Stop-Process -Id ([int]$cp.ProcessId) -Force -ErrorAction Stop } catch { }
            }
        }
    } catch { }
    Start-Sleep -Milliseconds 1000
    $oldRun = Test-OldRun
    if ($oldRun) {
        [System.Windows.Forms.MessageBox]::Show((T 'err.oldversion'), 'ZerkiWatch') | Out-Null
        exit
    }
}
$startHidden = $false
if (($env:ARG -eq 'tray') -or ($args -contains 'tray')) { $startHidden = $true }
$dotOn  = [string][char]0x25CF
$dotOff = [string][char]0x25CB

$nativeCode = @'
using System;
using System.Text;
using System.Diagnostics;
using System.Runtime.InteropServices;
public static class MN {
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern IntPtr MonitorFromWindow(IntPtr h, uint f);
    [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr m, ref MONITORINFO mi);
    [DllImport("user32.dll", CharSet = CharSet.Auto)] static extern int GetClassName(IntPtr h, StringBuilder sb, int n);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    static readonly uint myPid = (uint)Process.GetCurrentProcess().Id;
    [StructLayout(LayoutKind.Sequential)]
    struct MEMORYSTATUSEX {
        public uint dwLength; public uint dwMemoryLoad;
        public ulong ullTotalPhys; public ulong ullAvailPhys;
        public ulong ullTotalPageFile; public ulong ullAvailPageFile;
        public ulong ullTotalVirtual; public ulong ullAvailVirtual; public ulong ullAvailExtendedVirtual;
    }
    [DllImport("kernel32.dll")] static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX b);
    [DllImport("kernel32.dll")] static extern bool GetSystemTimes(out long idle, out long kernel, out long user);
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] static extern bool SetProcessDPIAware();
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] static extern int GetWL(IntPtr h, int i);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongW")] static extern int SetWL(IntPtr h, int i, int v);
    [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr h, int attr, ref int v, int size);
    [DllImport("shell32.dll")] static extern int SHQueryUserNotificationState(out int s);

    static long pi, pk, pu;
    static bool first = true;

    public static double Cpu() {
        long i, k, u;
        if (!GetSystemTimes(out i, out k, out u)) return 0;
        if (first) { pi = i; pk = k; pu = u; first = false; return 0; }
        long di = i - pi, dk = k - pk, du = u - pu;
        pi = i; pk = k; pu = u;
        long tot = dk + du;
        if (tot <= 0) return 0;
        double c = 100.0 * (tot - di) / tot;
        if (c < 0) c = 0;
        if (c > 100) c = 100;
        return c;
    }
    public static double[] Mem() {
        MEMORYSTATUSEX m = new MEMORYSTATUSEX();
        m.dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
        if (!GlobalMemoryStatusEx(ref m)) return new double[] { 0, 0, 0 };
        return new double[] { m.dwMemoryLoad, (double)m.ullTotalPhys, (double)m.ullAvailPhys };
    }
    public static void DpiAware() { try { SetProcessDPIAware(); } catch { } }
    public static void Drag(IntPtr h) { ReleaseCapture(); SendMessage(h, 0xA1, (IntPtr)2, IntPtr.Zero); }
    public static void NoActivate(IntPtr h) { int s = GetWL(h, -20); SetWL(h, -20, s | 0x80 | 0x08000000); }
    public static void KeepTop(IntPtr h) { SetWindowPos(h, (IntPtr)(-1), 0, 0, 0, 0, 0x13); }
    public static int Round(IntPtr h) { int v = 2; return DwmSetWindowAttribute(h, 33, ref v, 4); }
    public static int Border(IntPtr h, int colorref) { return DwmSetWindowAttribute(h, 34, ref colorref, 4); }
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("kernel32.dll")] static extern bool SetProcessWorkingSetSize(IntPtr h, IntPtr min, IntPtr max);
    public static void TrimMem() {
        GC.Collect();
        GC.WaitForPendingFinalizers();
        GC.Collect();
        SetProcessWorkingSetSize(Process.GetCurrentProcess().Handle, (IntPtr)(-1), (IntPtr)(-1));
    }
    public static void ScreenOff() { PostMessage((IntPtr)0xFFFF, 0x0112, (IntPtr)0xF170, (IntPtr)2); }
    public static int[] TaskbarInfo() {
        IntPtr tb = FindWindow("Shell_TrayWnd", null);
        if (tb == IntPtr.Zero) return null;
        RECT r = new RECT();
        if (!GetWindowRect(tb, out r)) return null;
        int nl = -1;
        IntPtr tn = FindWindowEx(tb, IntPtr.Zero, "TrayNotifyWnd", null);
        if (tn != IntPtr.Zero)
        {
            RECT n = new RECT();
            if (GetWindowRect(tn, out n) && n.R > n.L && n.L > r.L) nl = n.L;
        }
        return new int[] { r.L, r.T, r.R, r.B, nl };
    }
    public static bool FullScreen() {
        int s;
        if (SHQueryUserNotificationState(out s) == 0 && (s == 3 || s == 4)) return true;
        IntPtr h = GetForegroundWindow();
        if (h == IntPtr.Zero) return false;
        uint pid;
        GetWindowThreadProcessId(h, out pid);
        if (pid == myPid) return false;
        StringBuilder sb = new StringBuilder(64);
        GetClassName(h, sb, 64);
        string c = sb.ToString();
        if (c == "Progman" || c == "WorkerW" || c == "Shell_TrayWnd" || c == "Shell_SecondaryTrayWnd") return false;
        RECT r;
        if (!GetWindowRect(h, out r)) return false;
        IntPtr m = MonitorFromWindow(h, 2);
        MONITORINFO mi = new MONITORINFO();
        mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
        if (!GetMonitorInfo(m, ref mi)) return false;
        return r.L <= mi.rcMonitor.L && r.T <= mi.rcMonitor.T && r.R >= mi.rcMonitor.R && r.B >= mi.rcMonitor.B;
    }
}
'@
$native = $false
try { Add-Type -TypeDefinition $nativeCode; $native = $true } catch { $native = $false }
$themeCode = @'
using System.Drawing;
using System.Windows.Forms;
public class DarkColors : ProfessionalColorTable {
    static Color C(int r, int g, int b) { return Color.FromArgb(r, g, b); }
    public override Color ToolStripDropDownBackground { get { return C(19, 26, 48); } }
    public override Color MenuBorder { get { return C(44, 58, 98); } }
    public override Color MenuItemBorder { get { return C(70, 88, 140); } }
    public override Color MenuItemSelected { get { return C(34, 46, 84); } }
    public override Color MenuItemSelectedGradientBegin { get { return C(34, 46, 84); } }
    public override Color MenuItemSelectedGradientEnd { get { return C(34, 46, 84); } }
    public override Color MenuItemPressedGradientBegin { get { return C(34, 46, 84); } }
    public override Color MenuItemPressedGradientMiddle { get { return C(34, 46, 84); } }
    public override Color MenuItemPressedGradientEnd { get { return C(34, 46, 84); } }
    public override Color ImageMarginGradientBegin { get { return C(19, 26, 48); } }
    public override Color ImageMarginGradientMiddle { get { return C(19, 26, 48); } }
    public override Color ImageMarginGradientEnd { get { return C(19, 26, 48); } }
    public override Color SeparatorDark { get { return C(44, 58, 98); } }
    public override Color SeparatorLight { get { return C(44, 58, 98); } }
}
'@
$hkCode = @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class HotKeyWin : NativeWindow, IDisposable
{
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public Action OnHotKey;
    public HotKeyWin() { CreateHandle(new CreateParams()); }
    public bool Register(uint mod, uint vk)
    {
        UnregisterHotKey(Handle, 1);
        return RegisterHotKey(Handle, 1, mod | 0x4000, vk);
    }
    public void Unregister() { UnregisterHotKey(Handle, 1); }
    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x0312 && OnHotKey != null) { try { OnHotKey(); } catch { } }
        base.WndProc(ref m);
    }
    public void Dispose() { try { Unregister(); } catch { } DestroyHandle(); }
}
'@
$hkOkTmp = $false
try { Add-Type -TypeDefinition $hkCode -ReferencedAssemblies 'System.Windows.Forms'; $hkOkTmp = $true } catch { $hkOkTmp = $false }
$themed = $false
try { Add-Type -TypeDefinition $themeCode -ReferencedAssemblies 'System.Windows.Forms', 'System.Drawing'; $themed = $true } catch { $themed = $false }


$Group = 'ZerkiWatch-LocalOnly'
$LegacyGroups = @('ModeReseau-LocalUniquement')
# Plages supplementaires a considerer comme "locales" (seulement si besoin).
# Exemples : '100.64.0.0/10' pour Tailscale
$ExtraIPv4 = @()
$ExtraIPv6 = @()

# ---------- Calcul des plages (tout sauf le reseau local) ----------
function ConvertTo-Big([string]$Ip) {
    $b = [System.Net.IPAddress]::Parse($Ip).GetAddressBytes()
    [Array]::Reverse($b)
    $b = [byte[]]($b + [byte]0)
    return (New-Object System.Numerics.BigInteger -ArgumentList (, $b))
}
function ConvertFrom-Big($N, [int]$Len) {
    $src = $N.ToByteArray()
    $dst = New-Object byte[] $Len
    for ($i = 0; ($i -lt $Len) -and ($i -lt $src.Length); $i++) { $dst[$Len - 1 - $i] = $src[$i] }
    $addr = New-Object System.Net.IPAddress -ArgumentList (, $dst)
    return $addr.ToString()
}
function Get-Interval([string]$Cidr, [int]$Bits) {
    $parts  = $Cidr.Split('/')
    $ip     = ConvertTo-Big $parts[0]
    $prefix = $Bits
    if ($parts.Count -gt 1) { $prefix = [int]$parts[1] }
    $two   = [System.Numerics.BigInteger]2
    $size  = [System.Numerics.BigInteger]::Pow($two, ($Bits - $prefix))
    $start = [System.Numerics.BigInteger]::Multiply([System.Numerics.BigInteger]::Divide($ip, $size), $size)
    $end   = [System.Numerics.BigInteger]::Add($start, [System.Numerics.BigInteger]::Subtract($size, [System.Numerics.BigInteger]::One))
    return [pscustomobject]@{ Start = $start; End = $end }
}
function Get-Complement($Intervals, [int]$Bits) {
    $one    = [System.Numerics.BigInteger]::One
    $two    = [System.Numerics.BigInteger]2
    $max    = [System.Numerics.BigInteger]::Subtract([System.Numerics.BigInteger]::Pow($two, $Bits), $one)
    $cursor = [System.Numerics.BigInteger]::Zero
    $out    = @()
    foreach ($iv in ($Intervals | Sort-Object -Property Start)) {
        if ($iv.Start -gt $cursor) {
            $out += [pscustomobject]@{ Start = $cursor; End = [System.Numerics.BigInteger]::Subtract($iv.Start, $one) }
        }
        $next = [System.Numerics.BigInteger]::Add($iv.End, $one)
        if ($next -gt $cursor) { $cursor = $next }
    }
    if ($cursor -le $max) { $out += [pscustomobject]@{ Start = $cursor; End = $max } }
    return $out
}
function ConvertTo-RangeStrings($Gaps, [int]$Len) {
    $res = @()
    foreach ($g in $Gaps) {
        $a = ConvertFrom-Big $g.Start $Len
        $b = ConvertFrom-Big $g.End $Len
        if ($a -eq $b) { $res += $a } else { $res += ($a + '-' + $b) }
    }
    return $res
}

# ---------- Actions ----------
function Remove-Rules {
    foreach ($g in (@($Group) + $LegacyGroups)) {
        Get-NetFirewallRule -Group $g -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    }
}

function Get-Mode {
    foreach ($g in (@($Group) + $LegacyGroups)) {
        $r = @(Get-NetFirewallRule -Group $g -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' })
        if ($r.Count -ge 2) { return 'LOCAL' }
    }
    return 'INTERNET'
}

function Set-ModeInternet {
    Remove-Rules
    $left = @()
    foreach ($g in (@($Group) + $LegacyGroups)) { $left += @(Get-NetFirewallRule -Group $g -ErrorAction SilentlyContinue) }
    if ($left.Count -gt 0) { throw (T 'err.rules_left') }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

function Set-ModeLocal {
    $svc = Get-Service -Name 'mpssvc'
    if ($svc.Status -ne 'Running') { throw (T 'err.fw_stopped') }
    $off = @(Get-NetFirewallProfile | Where-Object { $_.Enabled -eq 'False' })
    if ($off.Count -gt 0) {
        throw (Tf 'err.fw_disabled' @((($off | ForEach-Object { $_.Name }) -join ', ')))
    }
    try {
        Remove-Rules
        $v4Allowed = @('0.0.0.0/8', '10.0.0.0/8', '127.0.0.0/8', '169.254.0.0/16', '172.16.0.0/12', '192.168.0.0/16', '224.0.0.0/3') + $ExtraIPv4
        $v6Allowed = @('::/128', '::1/128', 'fc00::/7', 'fe80::/10', 'ff00::/8') + $ExtraIPv6
        $v6Dyn = @(Get-NetIPAddress -AddressFamily IPv6 -ErrorAction SilentlyContinue |
            Where-Object { ($_.IPAddress -match '^[23]') -and ($_.PrefixLength -ge 64) } |
            ForEach-Object { '{0}/{1}' -f $_.IPAddress, $_.PrefixLength } | Select-Object -Unique)
        $v6Allowed = $v6Allowed + $v6Dyn

        $v4Iv = @(); foreach ($c in $v4Allowed) { $v4Iv += Get-Interval $c 32 }
        $v6Iv = @(); foreach ($c in $v6Allowed) { $v6Iv += Get-Interval $c 128 }
        $v4Block = ConvertTo-RangeStrings (Get-Complement $v4Iv 32) 4
        $v6Block = ConvertTo-RangeStrings (Get-Complement $v6Iv 128) 16
        $remote  = @($v4Block) + @($v6Block)
        if ($remote.Count -eq 0) { throw (T 'err.ranges') }

        $desc = 'Created by ZerkiWatch. Blocks everything except the local network.'
        New-NetFirewallRule -DisplayName 'ZerkiWatch - Block Internet (outbound)' -Group $Group -Description $desc `
            -Direction Outbound -Action Block -Profile Any -Protocol Any -RemoteAddress $remote -Enabled True | Out-Null
        New-NetFirewallRule -DisplayName 'ZerkiWatch - Block Internet (inbound)' -Group $Group -Description $desc `
            -Direction Inbound -Action Block -Profile Any -Protocol Any -RemoteAddress $remote -Enabled True | Out-Null

        $n = @(Get-NetFirewallRule -Group $Group -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq 'True' }).Count
        if ($n -ne 2) { throw (T 'err.rules_inactive') }
    } catch {
        Remove-Rules
        throw
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
}

# ---------- Tests ----------
function Test-Tcp([string]$Ip, [int]$Port, [int]$TimeoutMs) {
    $c = $null
    try {
        $addr = [System.Net.IPAddress]::Parse($Ip)
        $c = New-Object System.Net.Sockets.TcpClient -ArgumentList $addr.AddressFamily
        $iar = $c.BeginConnect($addr, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs)) {
            try { $c.EndConnect($iar); return $true } catch { return $false }
        }
        return $false
    } catch { return $false }
    finally { if ($c -ne $null) { $c.Close() } }
}
function Test-Ping([string]$Ip) {
    try {
        $p = New-Object System.Net.NetworkInformation.Ping
        return ($p.Send($Ip, 2000).Status -eq 'Success')
    } catch { return $false }
}
function Test-Internet {
    return ((Test-Tcp '1.1.1.1' 443 2000) -or (Test-Tcp '8.8.8.8' 443 2000) -or (Test-Tcp '2606:4700:4700::1111' 443 2000))
}
function Test-Box {
    $gw = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue | Sort-Object -Property RouteMetric | Select-Object -First 1
    if ($gw -and $gw.NextHop -and ($gw.NextHop -ne '0.0.0.0')) { return (Test-Ping $gw.NextHop) }
    return $false
}

# ---------- Interface graphique ----------
$cBg = (Pc @(17, 18, 22) @(242, 241, 238))
$cCard = (Pc @(25, 27, 33) @(255, 255, 255))
$cCardTop = (Pc @(25, 27, 33) @(255, 255, 255))
$cBorder = (Pc @(44, 47, 56) @(223, 220, 214))
$cText = (Pc @(238, 240, 244) @(24, 24, 27))
$cMuted = (Pc @(140, 146, 158) @(106, 108, 118))
$cAccent = (Pc @(74, 222, 129) @(22, 163, 74))
$cGreen = (Pc @(74, 222, 128) @(22, 163, 74))
$cRed = (Pc @(255, 99, 88) @(220, 38, 38))
$cAmber = (Pc @(251, 191, 36) @(180, 83, 9))
$aCpu = (Pc @(74, 222, 128) @(22, 163, 74))
$aRam = (Pc @(45, 212, 191) @(13, 148, 136))
$aGpu = (Pc @(244, 114, 182) @(219, 39, 119))
$aDsk = (Pc @(148, 163, 184) @(71, 85, 105))
# Etat de l'interface : Local = mode local actif ; Busy = clics ignores ; Switching = bascule en cours ; Pos = position du bouton (0 = gauche/coupe, 1 = droite/actif)
$S = @{ Local = $false; Busy = $false; Switching = $false; Pos = 1.0 }
$S.HkOk = $hkOkTmp
$S.HkWin = $null

# ---------- Telecommande iPhone (reseau local uniquement) ----------
$RemotePort = 8765
$RuleGroup  = 'ZerkiWatch-Remote'
$LegacyRuleGroup = 'ModeReseau-Telecommande'
$cfgDir     = $logDir
$S.Listener = $null
$S.Task = $null
$S.RemoteError = ''
$S.Pin = ''
$S.Fails = 0
$S.LockUntil = [DateTime]::MinValue
$S.PendingTest = $false

$S.Icon180 = [Convert]::FromBase64String('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')
$S.Icon512 = [Convert]::FromBase64String('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QtIeEfV26wW1+4EjIiIiIo4FaGfRhaqoyMf3Ed1LBBCCCL1+qCBqJEZEREQcGygAEVEVne3Hu2cHMPs5KhBVVVKiVhNIJfqAiIiIiGNg+lujrOpvn/7fWQSAdr4A7SLWWAeOiIiIOB7cP5jlkKWh2y7W3tIB7DYSiajITnDBGnWBIiIiIo7c+qsSKVFQAcLHMvX36AD2LN1WVfG0O2AWrX9ERETEkYNmbF1nmyBvF/Z2f35YDwwVrwRRxNUAEREREcfE+pNq0IC7owDgDsd6CeE1PLCzYy/WgSMiIiKO1geQttZfsP8OQHf/rRABIbQCUdi+HX1ARERExOFDdxc1ir/D/P+dRwCAegnFAI2iQBERERFHj9D/A4XInap02jv7dgUg6r0aUjCB98iCxjggIiIi4lADAGIQURj/ape330l19i5YfHgZgeytBMQNARERERFH4wcUwSYL0QGmgGiPD/Ct3lDbDhSngiMiIiIO3/areqfiRERniwAONAIIRWZREQBEsRIQERERcRRop38F4hV3s7f9jsz3brpfBZA9E2EaNwREREREHBLvhwqFRsyw/mWv+b0TP3CX/L0tN7QbAih2BEVEREQcOggKUfVylxl4e9evrCrivRIYTIAqARLjgIiIiIgDt/toN/2qevECvcs2nLtn7mHxWFsJ4BgBRERERBwCwu7HkP334gVy902YfJcvj7B1eLZ6JkyjaaT/EREREQdp/VXCThbFTP3hHjow78IB7Fh5mlUC/OwdRAcQERERcaCgNgKQ0Isp92J77zl1o+q9iLggFwqiOBAQERERcWDWnwEihUBkx/7frdW9VwegkABAECsBEREREQfpAIgJIBU3E/68J8J91yZ7pxJASgpVj7AjgGIAEBEREbH/UCUCMYPgVVX8Hu3Pw44AdmUhoCoq4RegLU9HREREROx7BACQiKr3okqk91h5tfvzrsJUmDqwDepwqh5xaXBERETEfpD/Hd1/8V7FexW0/P+eGnD2h623QqTiSSWqA0VERETstwNox61ERL3fr16b/YkAiKDwAsMqpAwASjOfFGsCEREREXdpXAGFhtovq3pVr9i79/GeskD7ydYFIupFHABw3BMQERERcc9mFe3aFVVR9WH6a+YbcI9p9n1xAK0vUoWIeIhCiQ0oeKkYAURERETcjWlV1bCAHUSizovIbuvPPpjW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')
$S.Manifest = '{"name":"ZerkiWatch","short_name":"ZerkiWatch","start_url":"/","scope":"/","display":"standalone","orientation":"portrait","background_color":"#111216","theme_color":"#111216","icons":[{"src":"/icon-180.png","sizes":"180x180","type":"image/png"},{"src":"/icon-512.png","sizes":"512x512","type":"image/png","purpose":"any"}]}'

$PageHtml = @'
<!doctype html>
<html lang="{{p.lang}}"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="ZerkiWatch">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="theme-color" content="#111216">
<meta name="mobile-web-app-capable" content="yes">
<link rel="manifest" href="/manifest.webmanifest">
<link rel="apple-touch-icon" href="/icon-180.png">
<link rel="icon" type="image/png" href="/icon-180.png">
<title>ZerkiWatch</title>
<style>
*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}
html,body{margin:0;background:#111216;color:#eef0f4;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
.wrap{max-width:460px;margin:0 auto;padding:max(26px,env(safe-area-inset-top)) 16px 44px;text-align:center}
.t{letter-spacing:.22em;font-size:13px;color:#8c929e;font-weight:600;margin:6px 0 28px}
.sw{position:relative;margin:0 auto;width:250px;height:124px;border-radius:62px;background:#5f6980;transition:background .25s;cursor:pointer;box-shadow:0 14px 34px rgba(0,0,0,.45)}
.sw.on{background:linear-gradient(135deg,#4ade80,#4ade80)}
.sw.off{background:linear-gradient(135deg,#ff6358,#ff6358)}
.knob{position:absolute;top:10px;left:10px;width:104px;height:104px;border-radius:50%;background:#fff;transition:transform .25s;box-shadow:0 4px 14px rgba(0,0,0,.35)}
.sw.right .knob{transform:translateX(126px)}
.sw span{position:absolute;top:0;bottom:0;display:flex;align-items:center;font-weight:700;font-size:24px;color:rgba(255,255,255,.92);transition:opacity .2s}
.sw .lon{left:30px;opacity:0}
.sw .loff{right:26px;opacity:0}
.sw.on .lon{opacity:1}
.sw.off .loff{opacity:1}
.st{margin-top:30px;font-size:26px;font-weight:700;min-height:34px}
.st.g{color:#4ade80}
.st.r{color:#ff6358}
.sub{margin:10px auto 0;font-size:15px;color:#8c929e;max-width:320px;line-height:1.4;min-height:42px}
.msg{margin-top:10px;font-size:14px;color:#ffaa3c;min-height:20px}
.card{background:#191b21;border:1px solid #2c2f38;border-radius:20px;padding:16px;margin-top:18px;text-align:left}
.ct{letter-spacing:.16em;font-size:11px;color:#8c929e;font-weight:700;margin-bottom:12px}
.sp{display:flex;justify-content:space-between;gap:10px}
.sp b{font-size:30px;font-weight:700;font-variant-numeric:tabular-nums}
.sp i{font-style:normal;font-size:13px;color:#8c929e;margin-left:4px}
.sp small{display:block;font-size:12px;color:#8c929e;margin-bottom:2px}
.d{color:#38bdf8}
.u{color:#f4c45a}
canvas{width:100%;height:70px;display:block;margin-top:12px}
.row{margin-bottom:12px;overflow:hidden}
.rn{float:left;max-width:66%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:15px}
.rv{float:right;font-size:14px;color:#c9d1e6;font-variant-numeric:tabular-nums}
.bar{clear:both;height:4px;border-radius:2px;background:rgba(255,255,255,.08);padding-top:0;position:relative;top:4px}
.bar i{display:block;height:100%;border-radius:2px}
.bar.a i{background:#fb923c}
.bar.s i{background:#4ade80}
.bar.k i{background:#fbbf24}
.empty{font-size:14px;color:#6b7690}
.g2{display:flex;gap:12px}
.g4{display:grid;grid-template-columns:repeat(3,1fr);gap:20px 8px}
.gb{text-align:center}
.rw{position:relative;width:92px;height:92px;margin:0 auto}
.ring{width:92px;height:92px;transform:rotate(-90deg)}
.trk{fill:none;stroke:#2c344e;stroke-width:9}
.val{fill:none;stroke:#4ade80;stroke-width:9;stroke-linecap:round;stroke-dasharray:251.3;stroke-dashoffset:251.3;transition:stroke-dashoffset .6s,stroke .3s}
.gt{position:absolute;left:0;right:0;top:24px}
.gt b{display:block;font-size:20px;font-variant-numeric:tabular-nums}
.gt small{font-size:12px;color:#8c929e;letter-spacing:.12em}
.gd{margin-top:8px;font-size:12px;color:#8c929e;min-height:16px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.pills{display:flex;gap:8px;margin-bottom:12px}
.pills button{flex:1;padding:9px 0;border-radius:14px;border:1px solid #2c2f38;background:#191b21;color:#8a96b8;font-size:14px;font-weight:600;font-family:inherit}
.pills button.on{background:#38bdf8;border-color:#38bdf8;color:#111216}
.pw,.cutg{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.pw button,.cutg button{padding:14px 0;border-radius:14px;border:1px solid #2c2f38;background:#191b21;color:#e6ebf8;font-size:15px;font-weight:600;font-family:inherit}
.pw button.dg{color:#ff6358;border-color:#4a2230}
.pw button.wd{grid-column:1/3}
.pwb{display:none;margin-top:12px;padding:12px;border-radius:14px;background:rgba(248,113,113,.12);color:#fca5a5;font-size:14px}
.pwb button{margin-left:10px;padding:6px 14px;border-radius:10px;border:1px solid #ff6358;background:transparent;color:#fca5a5;font-size:14px;font-family:inherit}
.tpills{display:flex;gap:8px;margin-bottom:12px}
.tpills button{flex:1;padding:9px 0;border-radius:14px;border:1px solid #2c2f38;background:#191b21;color:#8a96b8;font-size:14px;font-weight:600;font-family:inherit}
.tpills button.on{background:#38bdf8;border-color:#38bdf8;color:#111216}
.ct2{letter-spacing:.14em;font-size:11px;color:#8a96b8;font-weight:700;margin:14px 0 4px}
.lg{display:flex;gap:14px;font-size:12px;color:#8a96b8;margin:4px 0 2px}
#hc1,#hc2{height:150px;margin-top:4px}
.bar.t{display:flex}
.lnk{margin-top:30px;font-size:13px;color:#5d6a85;text-decoration:underline;cursor:pointer}
.t:before{content:"\1F512  ";letter-spacing:0}
.pills button,.tpills button,.pw button,.cutg button,.pwb button{min-height:44px}
@media (prefers-color-scheme:light){
html,body{background:#f4f6fb;color:#0f172a}
.t,.ct,.sub,.sp i,.sp small,.gt small,.gd,.ct2,.lg{color:#5b6785}
.card{background:#fff;border-color:#dfe4ef}
.rv{color:#334155}
.bar{background:rgba(15,23,42,.08)}
.trk{stroke:#e2e8f0}
.pills button,.tpills button,.pw button,.cutg button{background:#fff;border-color:#dfe4ef;color:#334155}
.pills button.on,.tpills button.on{background:#0284c7;border-color:#0284c7;color:#fff}
.sw{box-shadow:0 10px 24px rgba(15,23,42,.18)}
.empty,.lnk{color:#64748b}
.d{color:#0284c7}.u{color:#7c3aed}.st.g{color:#059669}.st.r{color:#dc2626}
}
@media (prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
</style></head><body>
<div class="wrap">
<div class="t">ZERKIWATCH</div>
<div id="sw" class="sw" onclick="tap()"><div class="knob"></div><span class="lon">ON</span><span class="loff">OFF</span></div>
<div id="st" class="st">{{p.connecting}}</div>
<div id="sub" class="sub"></div>
<div id="msg" class="msg"></div>
<div class="card"><div class="ct">{{p.cut_title}}</div>
<div class="cutg"><button data-c="15">{{p.cut_15}}</button><button data-c="30">{{p.cut_30}}</button><button data-c="60">{{p.cut_60}}</button><button data-c="tomorrow">{{p.cut_tomorrow}}</button></div>
<div id="cutb" class="pwb"><span id="cutt"></span><button id="cutc">{{p.cut_cancel}}</button></div></div>
<div class="card"><div class="ct">{{p.live}}</div>
<div class="sp"><div><small>{{p.recv}}</small><b class="d" id="dl">0.00</b><i>Mbps</i></div><div><small>{{p.send}}</small><b class="u" id="ul">0.00</b><i>Mbps</i></div></div>
<canvas id="cv"></canvas></div>
<div class="card"><div class="ct">{{p.perf}}</div>
<div class="g4">
<div class="gb"><div class="rw"><svg viewBox="0 0 100 100" class="ring"><circle class="trk" cx="50" cy="50" r="40"/><circle id="cpur" class="val" cx="50" cy="50" r="40"/></svg><div class="gt"><b id="cpuv">0%</b><small>CPU</small></div></div><div class="gd" id="cpud"></div></div>
<div class="gb"><div class="rw"><svg viewBox="0 0 100 100" class="ring"><circle class="trk" cx="50" cy="50" r="40"/><circle id="ramr" class="val" cx="50" cy="50" r="40"/></svg><div class="gt"><b id="ramv">0%</b><small>RAM</small></div></div><div class="gd" id="ramd"></div></div>
<div class="gb"><div class="rw"><svg viewBox="0 0 100 100" class="ring"><circle class="trk" cx="50" cy="50" r="40"/><circle id="gpur" class="val" cx="50" cy="50" r="40"/></svg><div class="gt"><b id="gpuv">0%</b><small>GPU</small></div></div><div class="gd" id="gpud"></div></div>
</div></div>
<div class="card"><div class="ct">{{p.disks}}</div><div id="dsk"></div></div>
<div class="card"><div class="ct">{{p.apps}}</div><div id="apps"></div></div>
<div class="card"><div class="ct">{{p.services}}</div><div id="svc"></div></div>
<div class="card"><div class="ct">{{p.history}}</div>
<div class="pills"><button data-r="1h">{{p.h1}}</button><button data-r="24h" class="on">{{p.h24}}</button><button data-r="7d">{{p.d7}}</button></div>
<div class="ct2">{{p.speed_mbps}}</div><canvas id="hc1"></canvas>
<div class="lg"><span style="color:#38bdf8">&#9679; {{p.recv}}</span><span style="color:#f4c45a">&#9679; {{p.send}}</span></div>
<div class="ct2">{{p.perf_pct}}</div><canvas id="hc2"></canvas>
<div class="lg"><span style="color:#4ade80">&#9679; CPU</span><span style="color:#4ade80">&#9679; RAM</span><span style="color:#f472b6">&#9679; GPU</span></div></div>
<div class="card"><div class="ct">{{p.usage}}</div>
<div class="sp"><div><small>{{p.today_rx}}</small><b class="d" id="trx">-</b></div><div><small>{{p.today_tx}}</small><b class="u" id="ttx">-</b></div></div>
<div class="ct2">{{p.last7}}</div><div id="tdays"></div>
<div class="ct2">{{p.bymonth}}</div><div id="tmon"></div></div>
<div class="card"><div class="ct">{{p.top}}</div>
<div class="tpills"><button data-t="d1" class="on">{{p.today}}</button><button data-t="d7">{{p.d7}}</button><button data-t="d30">{{p.d30}}</button></div>
<div id="top"></div>
<div class="lg"><span style="color:#fb923c">&#9679; {{p.legend_app}}</span><span style="color:#4ade80">&#9679; {{p.legend_svc}}</span></div></div>
<div class="card"><div class="ct">{{p.power}}</div>
<div class="pw"><button data-p="lock">{{p.lock}}</button><button data-p="screen">{{p.screen}}</button><button data-p="sleep">{{p.sleep}}</button><button data-p="restart" class="dg">{{p.restart}}</button><button data-p="shutdown" class="dg wd">{{p.shutdown}}</button></div>
<div id="pwb" class="pwb"><span id="pwt"></span><button id="pwc">{{p.cancel}}</button></div></div>
<div class="lnk" onclick="askPin()">{{p.changepw}}</div>
</div>
<script>
var LG = /*LANGJSON*/{};
function tf(k, a) { var s = LG[k] || k; for (var i = 0; i < a.length; i++) s = s.split('{' + i + '}').join(a[i]); return s; }
var pin = '';
try { pin = localStorage.getItem('pin') || ''; } catch (e) {}
var mode = '', busy = false, hd = [], hu = [];
var sw = document.getElementById('sw'), st = document.getElementById('st'), sub = document.getElementById('sub'), msg = document.getElementById('msg');
function say(t) { msg.textContent = t || ''; }
function fmt(v) { v = Number(v) || 0; return v >= 100 ? v.toFixed(0) : (v >= 10 ? v.toFixed(1) : v.toFixed(2)); }
function render() {
  var cls = 'sw';
  if (!busy && mode === 'INTERNET') cls += ' on';
  if (!busy && mode === 'LOCAL') cls += ' off';
  if (mode === 'INTERNET') cls += ' right';
  sw.className = cls;
  if (busy) { st.className = 'st'; st.textContent = LG['p.wait']; sub.textContent = ''; return; }
  if (mode === 'INTERNET') {
    st.className = 'st g'; st.textContent = LG['p.net_on'];
    sub.textContent = LG['p.net_on_sub'];
  } else if (mode === 'LOCAL') {
    st.className = 'st r'; st.textContent = LG['p.net_off'];
    sub.textContent = LG['p.net_off_sub'];
  } else {
    st.className = 'st'; st.textContent = '...'; sub.textContent = '';
  }
}
function disks(list) {
  var el = document.getElementById('dsk');
  el.textContent = '';
  if (!list || !list.length) { var d = document.createElement('div'); d.className = 'empty'; d.textContent = LG['p.nodisk']; el.appendChild(d); return; }
  list.forEach(function (x) {
    var r = document.createElement('div'); r.className = 'row';
    var a = document.createElement('div'); a.className = 'rn'; a.textContent = x.l + (x.name ? ' ' + x.name : '');
    var b = document.createElement('div'); b.className = 'rv'; b.textContent = x.used + ' / ' + x.tot + ' ' + LG['p.unit_g'];
    var bar = document.createElement('div'); bar.className = 'bar k';
    var f = document.createElement('i'); f.style.width = Math.max(2, x.pct) + '%';
    bar.appendChild(f);
    r.appendChild(a); r.appendChild(b); r.appendChild(bar);
    el.appendChild(r);
  });
}
function rows(id, list, cls, empty) {
  var el = document.getElementById(id);
  el.textContent = '';
  if (!list || !list.length) { var d = document.createElement('div'); d.className = 'empty'; d.textContent = empty; el.appendChild(d); return; }
  var mx = 0.05;
  list.forEach(function (x) { if (x.m > mx) mx = x.m; });
  list.forEach(function (x) {
    var r = document.createElement('div'); r.className = 'row';
    var a = document.createElement('div'); a.className = 'rn'; a.textContent = x.n;
    var b = document.createElement('div'); b.className = 'rv'; b.textContent = fmt(x.m) + ' Mbps';
    var bar = document.createElement('div'); bar.className = 'bar ' + cls;
    var f = document.createElement('i'); f.style.width = Math.max(2, 100 * x.m / mx) + '%';
    bar.appendChild(f);
    r.appendChild(a); r.appendChild(b); r.appendChild(bar);
    el.appendChild(r);
  });
}
function line(ctx, arr, w, h, mx, color, fill) {
  if (arr.length < 2) return;
  var step = w / 39, i, x, y;
  ctx.beginPath();
  for (i = 0; i < arr.length; i++) {
    x = w - (arr.length - 1 - i) * step; y = h - 3 - (arr[i] / mx) * (h - 6);
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.lineJoin = 'round'; ctx.stroke();
  if (fill) {
    ctx.lineTo(w, h); ctx.lineTo(w - (arr.length - 1) * step, h); ctx.closePath();
    ctx.fillStyle = 'rgba(56,189,248,0.18)'; ctx.fill();
  }
}
function spark() {
  var cv = document.getElementById('cv'), r = window.devicePixelRatio || 1;
  var w = cv.clientWidth, h = cv.clientHeight;
  cv.width = w * r; cv.height = h * r;
  var ctx = cv.getContext('2d'); ctx.scale(r, r); ctx.clearRect(0, 0, w, h);
  var mx = 1, i;
  for (i = 0; i < hd.length; i++) if (hd[i] > mx) mx = hd[i];
  for (i = 0; i < hu.length; i++) if (hu[i] > mx) mx = hu[i];
  line(ctx, hd, w, h, mx, '#38bdf8', true);
  line(ctx, hu, w, h, mx, '#c084fc', false);
}
function ring(id, pct, color) {
  pct = Math.max(0, Math.min(100, Number(pct) || 0));
  var el = document.getElementById(id);
  el.style.strokeDashoffset = 251.3 * (1 - pct / 100);
  el.style.stroke = pct >= 90 ? '#ff6358' : color;
}
var hr = '24h', hbusy = false, hlast = 0;
var dnames = (LG['p.days'] || 'Sun,Mon,Tue,Wed,Thu,Fri,Sat').split(',');
function pad(n) { return n < 10 ? '0' + n : '' + n; }
function nice(v) {
  if (v <= 0) return 1;
  var e = Math.pow(10, Math.floor(Math.log(v) / Math.LN10)), f = v / e;
  return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * e;
}
function fb(b) {
  b = Number(b) || 0;
  var dc = LG['p.dec'] || '.';
  if (b >= 1099511627776) return (b / 1099511627776).toFixed(2).replace('.', dc) + ' ' + LG['p.unit_t'];
  if (b >= 1073741824) return (b / 1073741824).toFixed(2).replace('.', dc) + ' ' + LG['p.unit_g'];
  if (b >= 1048576) return (b / 1048576).toFixed(1).replace('.', dc) + ' ' + LG['p.unit_m'];
  return Math.round(b / 1024) + ' ' + LG['p.unit_k'];
}
function chart(id, series, mx, unit, d) {
  var cv = document.getElementById(id), r = window.devicePixelRatio || 1;
  var w = cv.clientWidth, h = cv.clientHeight;
  cv.width = w * r; cv.height = h * r;
  var c = cv.getContext('2d'); c.scale(r, r); c.clearRect(0, 0, w, h);
  var L = 34, B = 18, T = 6, pw = w - L - 4, ph = h - B - T, n = d.n, i, k, v, y;
  c.font = '10px -apple-system, sans-serif'; c.lineWidth = 1;
  for (k = 0; k <= 3; k++) {
    y = T + ph - ph * k / 3; v = mx * k / 3;
    c.strokeStyle = 'rgba(255,255,255,.08)'; c.beginPath(); c.moveTo(L, y); c.lineTo(w, y); c.stroke();
    c.fillStyle = '#8a96b8'; c.textAlign = 'right';
    c.fillText(unit === '%' ? Math.round(v) + '%' : (v >= 10 ? '' + Math.round(v) : v.toFixed(1)), L - 4, y + 3);
  }
  c.textAlign = 'center';
  for (k = 0; k <= 2; k++) {
    var t = new Date((d.start + d.step * (n - 1) * k / 2) * 1000);
    var lab = (d.range === '7d') ? (dnames[t.getDay()] + ' ' + pad(t.getHours()) + 'h') : (pad(t.getHours()) + ':' + pad(t.getMinutes()));
    c.fillText(lab, Math.min(w - 20, Math.max(L + 16, L + pw * k / 2)), h - 4);
  }
  var any = false;
  series.forEach(function (sr) {
    var run = [], j;
    function flush() {
      if (run.length >= 2) {
        if (sr.f) {
          c.beginPath(); c.moveTo(run[0][0], T + ph);
          for (j = 0; j < run.length; j++) c.lineTo(run[j][0], run[j][1]);
          c.lineTo(run[run.length - 1][0], T + ph); c.closePath();
          c.fillStyle = 'rgba(56,189,248,0.18)'; c.fill();
        }
        c.beginPath(); c.moveTo(run[0][0], run[0][1]);
        for (j = 1; j < run.length; j++) c.lineTo(run[j][0], run[j][1]);
        c.strokeStyle = sr.c; c.lineWidth = 1.8; c.lineJoin = 'round'; c.stroke();
      } else if (run.length === 1) {
        c.beginPath(); c.arc(run[0][0], run[0][1], 2, 0, 6.3); c.fillStyle = sr.c; c.fill();
      }
      run = [];
    }
    for (i = 0; i < n; i++) {
      v = sr.v[i];
      if (v >= 0) { any = true; run.push([L + pw * i / Math.max(1, n - 1), T + ph - Math.min(1, v / mx) * ph]); }
      else flush();
    }
    flush();
  });
  if (!any) { c.fillStyle = '#6b7690'; c.font = '12px -apple-system, sans-serif'; c.fillText(LG['p.nodata'], w / 2, h / 2); }
}
function stack(id, list, key) {
  var el = document.getElementById(id), mx = 1;
  el.textContent = '';
  list.forEach(function (x) { var t = x.rx + x.tx; if (t > mx) mx = t; });
  list.forEach(function (x) {
    var r = document.createElement('div'); r.className = 'row';
    var a = document.createElement('div'); a.className = 'rn'; a.textContent = x[key];
    var b = document.createElement('div'); b.className = 'rv'; b.textContent = fb(x.rx + x.tx);
    var bar = document.createElement('div'); bar.className = 'bar t';
    var f1 = document.createElement('i'); f1.style.width = (100 * x.rx / mx) + '%'; f1.style.background = '#38bdf8';
    var f2 = document.createElement('i'); f2.style.width = (100 * x.tx / mx) + '%'; f2.style.background = '#f4c45a';
    bar.appendChild(f1); bar.appendChild(f2);
    r.appendChild(a); r.appendChild(b); r.appendChild(bar);
    el.appendChild(r);
  });
}
var tr = 'd1', topData = null;
function topRender() {
  var el = document.getElementById('top');
  if (!el) return;
  el.textContent = '';
  var list = (topData && topData[tr]) || [], mx = 1;
  list.forEach(function (x) { var t = x.rx + x.tx; if (t > mx) mx = t; });
  if (!list.length) {
    var e = document.createElement('div'); e.className = 'rn'; e.style.color = '#6b7690'; e.textContent = LG['p.nodata_top'];
    el.appendChild(e);
    return;
  }
  list.forEach(function (x, i) {
    var r = document.createElement('div'); r.className = 'row';
    var a = document.createElement('div'); a.className = 'rn'; a.textContent = (i + 1) + '. ' + x.n;
    var b = document.createElement('div'); b.className = 'rv'; b.textContent = fb(x.rx + x.tx);
    var bar = document.createElement('div'); bar.className = 'bar ' + (x.k === 'S' ? 's' : 'a');
    var f = document.createElement('i'); f.style.width = (100 * (x.rx + x.tx) / mx) + '%';
    bar.appendChild(f);
    r.appendChild(a); r.appendChild(b); r.appendChild(bar);
    el.appendChild(r);
  });
}
function initTop() {
  var bs = document.querySelectorAll('.tpills button'), i;
  for (i = 0; i < bs.length; i++) {
    bs[i].onclick = function () {
      var all = document.querySelectorAll('.tpills button'), q;
      for (q = 0; q < all.length; q++) all[q].className = '';
      this.className = 'on';
      tr = this.getAttribute('data-t'); topRender();
    };
  }
}
function loadHist() {
  if (!pin || hbusy) return;
  hbusy = true;
  api('/api/history?range=' + hr).then(function (j) {
    hbusy = false;
    if (j.http !== 200 || !j.dl) return;
    hlast = Date.now();
    var m = 0, i;
    for (i = 0; i < j.dl.length; i++) { if (j.dl[i] > m) m = j.dl[i]; if (j.ul[i] > m) m = j.ul[i]; }
    chart('hc1', [{ v: j.dl, c: '#38bdf8', f: true }, { v: j.ul, c: '#f4c45a', f: false }], nice(m * 1.05), '', j);
    chart('hc2', [{ v: j.cpu, c: '#4ade80' }, { v: j.ram, c: '#4ade80' }, { v: j.gpu, c: '#f472b6' }], 100, '%', j);
    var t = j.totals || {};
    document.getElementById('trx').textContent = fb(t.todayRx);
    document.getElementById('ttx').textContent = fb(t.todayTx);
    stack('tdays', t.days || [], 'd');
    stack('tmon', t.months || [], 'm');
    topData = j.top || null; topRender();
  }).catch(function () { hbusy = false; });
}
function initPills() {
  var bs = document.querySelectorAll('.pills button'), i;
  for (i = 0; i < bs.length; i++) {
    bs[i].onclick = function () {
      var all = document.querySelectorAll('.pills button'), q;
      for (q = 0; q < all.length; q++) all[q].className = '';
      this.className = 'on';
      hr = this.getAttribute('data-r'); hlast = 0; loadHist();
    };
  }
}
function api(path, method) {
  return fetch(path, { method: method || 'GET', headers: { 'X-Pin': pin }, cache: 'no-store' })
    .then(function (r) { return r.json().then(function (j) { j.http = r.status; return j; }); });
}
var pwEnd = 0, pwAct = '';
function pwShow() {
  var bx = document.getElementById('pwb');
  if (!bx) return;
  var s = Math.max(0, Math.round((pwEnd - Date.now()) / 1000));
  if (pwAct && s > 0) {
    bx.style.display = 'block';
    document.getElementById('pwt').textContent = tf(pwAct === 'restart' ? 'p.restart_in' : 'p.shutdown_in', [s]);
  } else { bx.style.display = 'none'; pwAct = ''; }
}
function pwSet(p) {
  if (p && p.act && p.secs > 0) { pwAct = p.act; pwEnd = Date.now() + p.secs * 1000; } else { pwAct = ''; pwEnd = 0; }
  pwShow();
}
function power(a) {
  var q = { sleep: LG['p.q_sleep'], restart: LG['p.q_restart'], shutdown: LG['p.q_shutdown'] };
  var l = { lock: LG['p.l_lock'], screen: LG['p.l_screen'], sleep: LG['p.l_sleep'], restart: LG['p.l_restart'], shutdown: LG['p.l_shutdown'], cancel: LG['p.l_cancel'] };
  if (q[a] && !confirm(q[a])) return;
  api('/api/power?action=' + a, 'POST').then(function (j) {
    if (j.http === 401) { say(LG['p.badpw']); return; }
    if (j.http === 429) { say(LG['p.toomany']); return; }
    if (j.error) { say(tf('p.err', [j.error])); if (j.power) pwSet(j.power); return; }
    pwSet(j.power);
    say(l[a] || '');
  }).catch(function () { say(LG['p.unreach']); });
}
function initPower() {
  var bs = document.querySelectorAll('.pw button'), i;
  for (i = 0; i < bs.length; i++) {
    bs[i].onclick = function () { power(this.getAttribute('data-p')); };
  }
  document.getElementById('pwc').onclick = function () { power('cancel'); };
  setInterval(pwShow, 1000);
}
function askPin() {
  var p = prompt(LG['p.pwprompt']);
  if (p) {
    pin = p.trim();
    try { localStorage.setItem('pin', pin); } catch (e) {}
    say(''); refresh();
  }
}
function refresh() {
  if (busy) return;
  if (!pin) { render(); askPin(); return; }
  api('/api/status').then(function (j) {
    if (j.http === 401) { mode = ''; render(); say(LG['p.badpw']); return; }
    if (j.http === 429) { say(LG['p.toomany']); return; }
    if (j.mode) { mode = j.mode; say(''); }
    document.getElementById('dl').textContent = fmt(j.dl);
    document.getElementById('ul').textContent = fmt(j.ul);
    ring('cpur', j.cpu, '#4ade80'); ring('ramr', j.ram, '#4ade80');
    ring('gpur', j.gpu < 0 ? 0 : j.gpu, '#f472b6');
    document.getElementById('cpuv').textContent = Math.round(j.cpu || 0) + '%';
    document.getElementById('ramv').textContent = Math.round(j.ram || 0) + '%';
    document.getElementById('gpuv').textContent = (j.gpu >= 0) ? Math.round(j.gpu) + '%' : '--';
    document.getElementById('cpud').textContent = j.link ? 'Wi-Fi : ' + j.link + ' Mbps' : '';
    document.getElementById('ramd').textContent = (j.ramUsed || 0) + ' / ' + (j.ramTot || 0) + ' ' + LG['p.unit_g'];
    document.getElementById('gpud').textContent = (j.vramTot > 0) ? ((j.vramUsed || 0) + ' / ' + j.vramTot + ' ' + LG['p.unit_g']) : (j.gpuName || '');
    disks(j.disks);
    pwSet(j.power);
    cutSet(j.cutUntil);
    hd.push(Number(j.dl) || 0); hu.push(Number(j.ul) || 0);
    if (hd.length > 40) hd.shift();
    if (hu.length > 40) hu.shift();
    spark();
    var none = j.etw ? LG['p.noact'] : LG['p.noetw'];
    rows('apps', j.apps, 'a', none);
    rows('svc', j.svc, 's', none);
    if (Date.now() - hlast > 30000) loadHist();
    render();
  }).catch(function () { mode = ''; render(); say(LG['p.unreach2']); });
}
var cutEnd = 0;
function cutShow() {
  var bx = document.getElementById('cutb');
  if (!bx) return;
  var left = Math.max(0, Math.round((cutEnd - Date.now()) / 60000));
  if (cutEnd && left >= 0) {
    var h = Math.floor(left / 60), m = left % 60;
    bx.style.display = 'block';
    document.getElementById('cutt').textContent = tf('p.cut_back', [h > 0 ? h + ' h ' + m + ' min' : m + ' min']);
  } else { bx.style.display = 'none'; }
}
function cutSet(iso) { cutEnd = iso ? Date.parse(iso) : 0; cutShow(); }
function cut(c) {
  if (busy) return;
  if (!pin) { askPin(); return; }
  busy = true; say('');
  api('/api/cut?m=' + c, 'POST').then(function (j) {
    busy = false;
    if (j.http === 401) { mode = ''; render(); say(LG['p.badpw']); return; }
    if (j.http === 429) { say(LG['p.toomany']); return; }
    if (j.error) { say(j.http === 409 ? LG['p.busy'] : tf('p.err', [j.error])); return; }
    if (j.mode) mode = j.mode;
    cutSet(j.cutUntil); render();
  }).catch(function () { busy = false; say(LG['p.noresp']); });
}
function initCut() {
  var bs = document.querySelectorAll('.cutg button'), i;
  for (i = 0; i < bs.length; i++) { bs[i].onclick = function () { cut(this.getAttribute('data-c')); }; }
  document.getElementById('cutc').onclick = function () { cut('cancel'); };
  setInterval(cutShow, 1000);
}
function tap() {
  if (busy) return;
  if (!pin) { askPin(); return; }
  if (mode !== 'LOCAL' && mode !== 'INTERNET') { refresh(); return; }
  busy = true; render(); say('');
  var want = (mode === 'LOCAL') ? 'internet' : 'local';
  api('/api/set?mode=' + want, 'POST').then(function (j) {
    busy = false;
    if (j.http === 401) { mode = ''; render(); say(LG['p.badpw']); return; }
    if (j.error) { say(j.http === 409 ? LG['p.busy'] : tf('p.err', [j.error])); }
    if (j.mode) mode = j.mode;
    render();
  }).catch(function () { busy = false; render(); say(LG['p.noresp']); });
}
render(); refresh(); initPills(); initTop(); initPower(); initCut();
setInterval(refresh, 2000);
</script></body></html>
'@

function Get-LangMap([string]$prefix) {
    $m = @{}
    foreach ($c in @('fr', 'en', $LangCode)) {
        if ($LangDb.ContainsKey($c)) {
            foreach ($k in @($LangDb[$c].Keys)) { if ($k.StartsWith($prefix)) { $m[$k] = [string]$LangDb[$c][$k] } }
        }
    }
    return $m
}
function Build-Page {
    $map = Get-LangMap 'p.'
    $map['p.lang'] = $LangCode
    $h = $PageHtml
    $h = [regex]::Replace($h, '\{\{(p\.[A-Za-z0-9_.]+)\}\}', ([System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        $k = $m.Groups[1].Value
        if ($map.ContainsKey($k)) { return [System.Net.WebUtility]::HtmlEncode([string]$map[$k]) }
        return $k
    }))
    $json = (ConvertTo-Json -InputObject $map -Compress).Replace('</', '<\/')
    return $h.Replace('/*LANGJSON*/{}', $json)
}
function New-Pin {
    $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
    $by = New-Object byte[] 4
    $rng.GetBytes($by)
    $n = [BitConverter]::ToUInt32($by, 0)
    return ([string](100000 + ($n % 900000)))
}
function Get-Pin {
    $f = Join-Path $cfgDir 'password.txt'
    try {
        if (Test-Path -LiteralPath $f) {
            $v = (Get-Content -LiteralPath $f -TotalCount 1).Trim()
            if ($v.Length -gt 0) { return $v }
        }
        if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        $np = New-Pin
        Set-Content -LiteralPath $f -Value $np -Encoding ASCII
        return $np
    } catch { }
    return (New-Pin)
}
function Set-Pin([string]$v) {
    $v = $v.Trim()
    if ($v.Length -lt 4) { return $false }
    try {
        Set-Content -LiteralPath (Join-Path $cfgDir 'password.txt') -Value $v -Encoding ASCII
        $S.Pin = $v
        $S.Fails = 0
        return $true
    } catch { return $false }
}

function Get-LanIp {
    foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($ni.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
        $nt = $ni.NetworkInterfaceType.ToString()
        if ($nt -eq 'Loopback' -or $nt -eq 'Tunnel') { continue }
        if ($ni.Description -match 'Virtual|VPN|TAP-Windows|Wintun|Hyper-V|VMware|VirtualBox|Bluetooth|WireGuard|Tailscale|Npcap|Pseudo|vEthernet') { continue }
        $hasGw = $false
        try {
            foreach ($gw in $ni.GetIPProperties().GatewayAddresses) {
                $ga = $gw.Address.ToString()
                if ($ga -ne '0.0.0.0' -and $ga -ne '::') { $hasGw = $true }
            }
        } catch { }
        if (-not $hasGw) { continue }
        foreach ($ua in $ni.GetIPProperties().UnicastAddresses) {
            if ($ua.Address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) { return $ua.Address.ToString() }
        }
    }
    return $null
}

function Send-Reply($ctx, [int]$code, [string]$type, [string]$body) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $ctx.Response.StatusCode = $code
    $ctx.Response.ContentType = $type
    $ctx.Response.AddHeader('Cache-Control', 'no-store')
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}
function Send-Bytes($ctx, [string]$type, [byte[]]$bytes) {
    $ctx.Response.StatusCode = 200
    $ctx.Response.ContentType = $type
    $ctx.Response.AddHeader('Cache-Control', 'public, max-age=3600')
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.OutputStream.Close()
}
function Get-ShortText([string]$f) {
    $stateTxt = (T 'short.on')
    if ($S.Local) { $stateTxt = (T 'short.local') }
    $dlv = ([double]$S.Dl).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
    $ulv = ([double]$S.Ul).ToString('0.0', [System.Globalization.CultureInfo]::InvariantCulture)
    $cpuv = ([double]$S.Cpu).ToString('0', [System.Globalization.CultureInfo]::InvariantCulture)
    $ramv = ([double]$S.Ram).ToString('0', [System.Globalization.CultureInfo]::InvariantCulture)
    if (($f -eq 'state') -or ($f -eq 'etat')) { return $stateTxt }
    if (($f -eq 'speed') -or ($f -eq 'debit')) { return (Tf 'short.speed' @($dlv, $ulv)) }
    if ($f -eq 'cpu') { return (Tf 'short.cpu' @($cpuv)) }
    if ($f -eq 'ram') { return (Tf 'short.ram' @($ramv)) }
    return (Tf 'short.all' @($stateTxt, $dlv, $ulv, $cpuv, $ramv))
}
function Send-Json($ctx, [int]$code, $obj) {
    Send-Reply $ctx $code 'application/json; charset=utf-8' (ConvertTo-Json -InputObject $obj -Compress -Depth 6)
}

$S.PowerAct = ''
$S.PowerUntil = [DateTime]::MinValue
function Get-PowerObj {
    $secs = 0
    if ($S.PowerAct -ne '') {
        $secs = [int][math]::Ceiling(($S.PowerUntil - [DateTime]::UtcNow).TotalSeconds)
        if ($secs -le 0) { $S.PowerAct = ''; $secs = 0 }
    }
    return @{ act = [string]$S.PowerAct; secs = $secs }
}
function Invoke-Power([string]$act) {
    $sd = Join-Path $env:SystemRoot 'System32\shutdown.exe'
    try {
        if ($act -eq 'lock') {
            $null = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\rundll32.exe') -ArgumentList 'user32.dll,LockWorkStation' -WindowStyle Hidden
            return ''
        }
        if ($act -eq 'sleep') { return '' }
        if ($act -eq 'screen') {
            if ($S.Native) { [MN]::ScreenOff() } else { return (T 'err.unavailable') }
            return ''
        }
        if ($act -eq 'cancel') {
            $pc = Start-Process -FilePath $sd -ArgumentList '/a' -WindowStyle Hidden -Wait -PassThru
            $S.PowerAct = ''
            if (($pc.ExitCode -ne 0) -and ($pc.ExitCode -ne 1116)) { return ('shutdown /a code ' + $pc.ExitCode) }
            return ''
        }
        $flag = '/s'
        if ($act -eq 'restart') { $flag = '/r' }
        $pr = Start-Process -FilePath $sd -ArgumentList ($flag + ' /t 30 /c "' + (T 'power.reason') + '"') -WindowStyle Hidden -Wait -PassThru
        if ($pr.ExitCode -ne 0) { return ('shutdown code ' + $pr.ExitCode) }
        $S.PowerAct = $act
        $S.PowerUntil = [DateTime]::UtcNow.AddSeconds(30)
        try { $tray.ShowBalloonTip(5000, 'ZerkiWatch', (T 'bal.power'), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { }
        return ''
    } catch { return $_.Exception.Message }
}

# ---------- Coupure temporisee : Internet est remis automatiquement a l'heure choisie ----------
$S.CutUntil = $null
function Get-CutFile { return (Join-Path $cfgDir 'cut-until.txt') }
function Save-CutState {
    try {
        $f = Get-CutFile
        if ($S.CutUntil -eq $null) { if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force } }
        else { Set-Content -LiteralPath $f -Value ([DateTime]$S.CutUntil).ToString('o') -Encoding ASCII }
    } catch { }
}
function Load-CutState {
    try {
        $f = Get-CutFile
        if (Test-Path -LiteralPath $f) {
            $v = (Get-Content -LiteralPath $f -TotalCount 1).Trim()
            $S.CutUntil = [DateTime]::Parse($v, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind)
        }
    } catch { $S.CutUntil = $null }
}
# Passe en mode local (si besoin) et memorise l'heure de retour. $what = 15 | 30 | 60 | tomorrow | cancel. Retourne '' ou un code d'erreur.
function Start-TimedCut([string]$what) {
    if ($what -eq 'cancel') { $S.CutUntil = $null; Save-CutState; return '' }
    if ($S.Busy -or $S.Switching) { return 'busy' }
    if ($what -eq 'tomorrow') {
        $until = ([DateTime]::Today.AddDays(1).AddHours(7)).ToUniversalTime()
    } else {
        $mins = 0
        if (-not [int]::TryParse($what, [ref]$mins)) { return 'arg' }
        if (@(15, 30, 60) -notcontains $mins) { return 'arg' }
        $until = [DateTime]::UtcNow.AddMinutes($mins)
    }
    if (-not $S.Local) {
        $errTxt = ''
        $S.Busy = $true
        $S.Switching = $true
        $lblStatus.Text = (T 'ui.wait')
        $lblStatus.ForeColor = $cMuted
        $toggle.Invalidate()
        try { Set-ModeLocal } catch { $errTxt = $_.Exception.Message }
        $S.Switching = $false
        $S.Busy = $false
        Update-Ui
        $S.PendingTest = $true
        if ($errTxt -ne '') { return $errTxt }
    }
    $S.CutUntil = $until
    Save-CutState
    try { $tray.ShowBalloonTip(3500, 'ZerkiWatch', (Tf 'bal.cut_timed' @(($until.ToLocalTime()).ToString('t'))), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
    return ''
}
# Appelee chaque seconde : remet Internet quand l'heure est passee ; abandonne si l'utilisateur l'a deja remis.
function Check-TimedCut {
    if ($S.CutUntil -eq $null) { return }
    if ($S.Busy -or $S.Switching) { return }
    if (-not $S.Local) { $S.CutUntil = $null; Save-CutState; return }
    if ([DateTime]::UtcNow -ge ([DateTime]$S.CutUntil)) {
        $S.CutUntil = $null
        Save-CutState
        $S.Busy = $true
        $S.Switching = $true
        $lblStatus.Text = (T 'ui.wait')
        $lblStatus.ForeColor = $cMuted
        $toggle.Invalidate()
        try { Set-ModeInternet; Write-Log 'Timed cut ended: Internet restored' } catch { Write-Log ('Timed cut restore: ' + $_.Exception.Message) 'tc' }
        $S.Switching = $false
        $S.Busy = $false
        Update-Ui
        $S.PendingTest = $true
        try { $tray.ShowBalloonTip(3500, 'ZerkiWatch', (T 'bal.cut_end'), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
    }
}

# ---------- Alertes (desactivees par defaut) : trafic eleve, Internet coupe trop longtemps ----------
$S.AlHi = 0
$S.AlArm = $true
$S.LocalSince = $null
$S.AlCutSent = $false
function Check-Alerts {
    if ($S.AlertSpeed -gt 0) {
        $tot = [double]$S.Dl + [double]$S.Ul
        if ($tot -ge $S.AlertSpeed) { $S.AlHi = $S.AlHi + 1 }
        else { $S.AlHi = 0; if ($tot -lt ($S.AlertSpeed * 0.7)) { $S.AlArm = $true } }
        if (($S.AlHi -ge 10) -and $S.AlArm) {
            $S.AlArm = $false
            $who = ''
            try { $ap = @($S.Apps); if ($ap.Count -gt 0) { $who = [string]$ap[0].n } } catch { }
            if ($who -ne '') { $msg = (Tf 'bal.alert_speed_app' @($tot.ToString('0'), $who)) } else { $msg = (Tf 'bal.alert_speed' @($tot.ToString('0'))) }
            try { $tray.ShowBalloonTip(5000, 'ZerkiWatch', $msg, [System.Windows.Forms.ToolTipIcon]::Warning) } catch { }
        }
    }
    if ($S.AlertCut -gt 0) {
        if ($S.Local) {
            if ($S.LocalSince -eq $null) { $S.LocalSince = [DateTime]::UtcNow }
            if ((-not $S.AlCutSent) -and ($S.CutUntil -eq $null) -and (([DateTime]::UtcNow - [DateTime]$S.LocalSince).TotalMinutes -ge $S.AlertCut)) {
                $S.AlCutSent = $true
                try { $tray.ShowBalloonTip(5000, 'ZerkiWatch', (Tf 'bal.alert_cut' @([string]$S.AlertCut)), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { }
            }
        } else { $S.LocalSince = $null; $S.AlCutSent = $false }
    }
}

function Get-StatusObj {
    $dskL = New-Object System.Collections.ArrayList
    foreach ($dk in @($S.Disks)) {
        [void]$dskL.Add(@{ l = [string]$dk.L; name = [string]$dk.Name; type = [string]$dk.Type; used = [math]::Round([double]$dk.Used / 1GB, 0); tot = [math]::Round([double]$dk.Tot / 1GB, 0); pct = [math]::Round([double]$dk.Pct, 0); act = [math]::Round([double]$dk.Act, 0) })
    }
    $dskList = $dskL.ToArray()
    $m = 'INTERNET'
    if ($S.Local) { $m = 'LOCAL' }
    $cutIso = ''
    if ($S.CutUntil -ne $null) { $cutIso = ([DateTime]$S.CutUntil).ToString('o') }
    return @{
        mode = $m
        cutUntil = $cutIso
        dl = [math]::Round([double]$S.Dl, 2)
        ul = [math]::Round([double]$S.Ul, 2)
        apps = @($S.Apps)
        svc = @($S.Svcs)
        etw = [bool]$S.EtwOk
        cpu = [math]::Round([double]$S.Cpu, 0)
        ram = [math]::Round([double]$S.Ram, 0)
        ramUsed = [math]::Round([double]$S.RamUsed / 1GB, 1)
        ramTot = [math]::Round([double]$S.RamTot / 1GB, 1)
        link = [math]::Round([double]$S.LinkMbps, 0)
        gpu = [math]::Round([double]$S.Gpu, 0)
        gpuName = [string]$S.GpuName
        vramUsed = [math]::Round([double]$S.VramUsed / 1GB, 1)
        vramTot = [math]::Round([double]$S.VramTot / 1GB, 1)
        disks = @($dskList)
        power = (Get-PowerObj)
    }
}

function Handle-Remote($ctx) {
    try {
        $req = $ctx.Request
        $path = $req.Url.AbsolutePath
        if ($path -eq '/') { Send-Reply $ctx 200 'text/html; charset=utf-8' (Build-Page); return }
        if ($path -eq '/ca.cer') {
            if ($req.HttpMethod -ne 'GET') { Send-Json $ctx 405 @{ error = 'method' }; return }
            $caB = Get-CaBytes
            if ($caB -eq $null) { Send-Json $ctx 404 @{ error = 'ca' }; return }
            $ctx.Response.AddHeader('Content-Disposition', 'attachment; filename="ZerkiWatch-CA.cer"')
            Send-Bytes $ctx 'application/x-x509-ca-cert' $caB
            return
        }
        if (($path -eq '/manifest.webmanifest') -or ($path -eq '/icon-180.png') -or ($path -eq '/apple-touch-icon.png') -or ($path -eq '/icon-512.png')) {
            if ($req.HttpMethod -ne 'GET') { Send-Json $ctx 405 @{ error = 'method' }; return }
            if ($path -eq '/manifest.webmanifest') { Send-Reply $ctx 200 'application/manifest+json; charset=utf-8' $S.Manifest; return }
            if ($path -eq '/icon-512.png') { Send-Bytes $ctx 'image/png' $S.Icon512; return }
            Send-Bytes $ctx 'image/png' $S.Icon180
            return
        }
        if (($path -ne '/api/status') -and ($path -ne '/api/set') -and ($path -ne '/api/history') -and ($path -ne '/api/short') -and ($path -ne '/api/toggle') -and ($path -ne '/api/power') -and ($path -ne '/api/cut')) { Send-Json $ctx 404 @{ error = 'not found' }; return }
        $S.LastRemote = [DateTime]::UtcNow
        $nowUtc = [DateTime]::UtcNow
        if ($S.LockUntil -gt $nowUtc) { Send-Json $ctx 429 @{ error = 'locked' }; return }
        $given = $req.Headers['X-Pin']
        if ($given -ne $S.Pin) {
            $S.Fails = $S.Fails + 1
            if ($S.Fails -ge 5) { $S.LockUntil = $nowUtc.AddSeconds(60); $S.Fails = 0 }
            Send-Json $ctx 401 @{ error = 'pin' }
            return
        }
        $S.Fails = 0
        if ($path -eq '/api/history') {
            if ($req.HttpMethod -ne 'GET') { Send-Json $ctx 405 @{ error = 'method' }; return }
            Send-Json $ctx 200 (Get-HistPayload ([string]$req.QueryString['range']))
            return
        }
        if ($path -eq '/api/power') {
            if ($req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ error = 'method' }; return }
            $act = [string]$req.QueryString['action']
            if (@('lock', 'screen', 'sleep', 'restart', 'shutdown', 'cancel') -notcontains $act) { Send-Json $ctx 400 @{ error = 'action' }; return }
            $pw0 = Get-PowerObj
            if ((($act -eq 'restart') -or ($act -eq 'shutdown')) -and ($pw0.act -ne '')) { Send-Json $ctx 409 @{ error = 'already scheduled'; power = $pw0 }; return }
            Write-Log ('Power action requested from the iPhone: ' + $act)
            $perr = Invoke-Power $act
            if ($perr -ne '') { Send-Json $ctx 500 @{ error = $perr; power = (Get-PowerObj) }; return }
            Send-Json $ctx 200 @{ ok = $true; act = $act; power = (Get-PowerObj) }
            if ($act -eq 'sleep') {
                Start-Sleep -Milliseconds 700
                [void][System.Windows.Forms.Application]::SetSuspendState([System.Windows.Forms.PowerState]::Suspend, $false, $false)
            }
            return
        }
        if ($path -eq '/api/cut') {
            if ($req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ error = 'method' }; return }
            $cw = [string]$req.QueryString['m']
            if (@('15', '30', '60', 'tomorrow', 'cancel') -notcontains $cw) { Send-Json $ctx 400 @{ error = 'm' }; return }
            Write-Log ('Timed cut requested from the iPhone: ' + $cw)
            $cerr = Start-TimedCut $cw
            if ($cerr -eq 'busy') { Send-Json $ctx 409 @{ error = 'busy'; mode = (Get-Mode) }; return }
            if ($cerr -ne '') { Send-Json $ctx 500 @{ error = $cerr; mode = (Get-Mode) }; return }
            Send-Json $ctx 200 (Get-StatusObj)
            return
        }
        if ($path -eq '/api/short') {
            if ($req.HttpMethod -ne 'GET') { Send-Json $ctx 405 @{ error = 'method' }; return }
            Send-Reply $ctx 200 'text/plain; charset=utf-8' (Get-ShortText ([string]$req.QueryString['f']))
            return
        }
        if (($path -eq '/api/set') -or ($path -eq '/api/toggle')) {
            $isToggle = ($path -eq '/api/toggle')
            if ($isToggle) {
                if (($req.HttpMethod -ne 'GET') -and ($req.HttpMethod -ne 'POST')) { Send-Json $ctx 405 @{ error = 'method' }; return }
                if ($S.Local) { $want = 'internet' } else { $want = 'local' }
            } else {
                if ($req.HttpMethod -ne 'POST') { Send-Json $ctx 405 @{ error = 'method' }; return }
                $want = $req.QueryString['mode']
                if (($want -ne 'local') -and ($want -ne 'internet')) { Send-Json $ctx 400 @{ error = 'mode' }; return }
            }
            if ($S.Busy) {
                if ($isToggle) { Send-Reply $ctx 409 'text/plain; charset=utf-8' (T 'p.busy'); return }
                Send-Json $ctx 409 @{ error = 'busy'; mode = (Get-Mode) }
                return
            }
            $S.Busy = $true
            $S.Switching = $true
            $lblStatus.Text = (T 'ui.wait')
            $lblStatus.ForeColor = $cMuted
            $toggle.Invalidate()
            $errTxt = ''
            try { if ($want -eq 'local') { Set-ModeLocal } else { Set-ModeInternet } } catch { $errTxt = $_.Exception.Message }
            $S.Switching = $false
            $S.Busy = $false
            Update-Ui
            $S.PendingTest = $true
            if ($errTxt -ne '') {
                if ($isToggle) { Send-Reply $ctx 500 'text/plain; charset=utf-8' (Tf 'p.err' @($errTxt)); return }
                Send-Json $ctx 500 @{ error = $errTxt; mode = (Get-Mode) }
                return
            }
            if ($isToggle) { Send-Reply $ctx 200 'text/plain; charset=utf-8' (Get-ShortText 'etat'); return }
        }
        Send-Json $ctx 200 (Get-StatusObj)
    } catch {
        Write-Log ('iPhone request: ' + $_.Exception.Message) 'hr'
        try { Send-Json $ctx 500 @{ error = 'internal' } } catch { }
    }
}

# ---------- HTTPS : autorite locale + certificat serveur (aucune verification desactivee) ----------
$CaSubject   = 'CN=ZerkiWatch Local CA'
$LeafSubject = 'CN=ZerkiWatch iPhone remote'
$SslAppId    = '{6f1b7a3e-4c52-4d0e-9a7b-5a3e0c2d8f41}'

function Get-AllLanIps {
    $r = New-Object System.Collections.ArrayList
    foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($ni.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
        $nt = $ni.NetworkInterfaceType.ToString()
        if ($nt -eq 'Loopback' -or $nt -eq 'Tunnel') { continue }
        foreach ($ua in $ni.GetIPProperties().UnicastAddresses) {
            if ($ua.Address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { continue }
            $ip = $ua.Address.ToString()
            if ($ip.StartsWith('169.254.') -or $ip.StartsWith('127.')) { continue }
            [void]$r.Add($ip)
        }
    }
    return @($r | Sort-Object -Unique)
}

function Test-CertHasIp($cert, [string]$ip) {
    # Lit le SubjectAltName en binaire (le texte de Format() depend de la langue de Windows).
    $ext = $cert.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.17' } | Select-Object -First 1
    if ($ext -eq $null) { return $false }
    $raw = $ext.RawData
    $o = @($ip.Split('.') | ForEach-Object { [byte][int]$_ })
    for ($i = 0; $i -le ($raw.Length - 6); $i++) {
        if (($raw[$i] -eq 0x87) -and ($raw[$i + 1] -eq 4) -and ($raw[$i + 2] -eq $o[0]) -and ($raw[$i + 3] -eq $o[1]) -and ($raw[$i + 4] -eq $o[2]) -and ($raw[$i + 5] -eq $o[3])) { return $true }
    }
    return $false
}

function Get-CaCert {
    $now = Get-Date
    return (Get-ChildItem Cert:\LocalMachine\My | Where-Object { ($_.Subject -eq $CaSubject) -and $_.HasPrivateKey -and ($_.NotAfter -gt $now.AddDays(60)) } | Sort-Object NotAfter -Descending | Select-Object -First 1)
}

function Get-CaBytes {
    try {
        $ca = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq $CaSubject } | Sort-Object NotAfter -Descending | Select-Object -First 1
        if ($ca -eq $null) { return $null }
        return $ca.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    } catch { return $null }
}

function Get-CaFingerprint {
    try {
        $bytes = Get-CaBytes
        if ($bytes -eq $null) { return '' }
        $h = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
        return ((($h | ForEach-Object { $_.ToString('X2') }) -join ' '))
    } catch { return '' }
}

# Retourne le certificat serveur valide (le cree ou le renouvelle si besoin). Leve une exception en cas d'echec.
function Initialize-RemoteCert {
    $ips = @(Get-AllLanIps)
    $ca = Get-CaCert
    if ($ca -eq $null) {
        $ca = New-SelfSignedCertificate -Type Custom -Subject $CaSubject -KeyUsage CertSign, CRLSign, DigitalSignature `
            -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable `
            -NotAfter (Get-Date).AddYears(5) -CertStoreLocation Cert:\LocalMachine\My `
            -TextExtension @('2.5.29.19={critical}{text}CA=true')
        Write-Log 'HTTPS: local certificate authority created' 'ca'
    }
    $now = Get-Date
    $leaf = Get-ChildItem Cert:\LocalMachine\My | Where-Object { ($_.Subject -eq $LeafSubject) -and $_.HasPrivateKey -and ($_.Issuer -eq $CaSubject) -and ($_.NotAfter -gt $now.AddDays(30)) -and ($_.Thumbprint -ne $ca.Thumbprint) } | Sort-Object NotAfter -Descending | Select-Object -First 1
    if ($leaf -ne $null) {
        foreach ($ip in $ips) { if (-not (Test-CertHasIp $leaf $ip)) { $leaf = $null; break } }
    }
    if ($leaf -eq $null) {
        Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq $LeafSubject } | Remove-Item -ErrorAction SilentlyContinue
        $san = New-Object System.Collections.ArrayList
        foreach ($ip in $ips) { [void]$san.Add('IPAddress=' + $ip) }
        [void]$san.Add('DNS=' + $env:COMPUTERNAME)
        [void]$san.Add('DNS=localhost')
        $leaf = New-SelfSignedCertificate -Type Custom -Subject $LeafSubject -Signer $ca -KeyUsage DigitalSignature, KeyEncipherment `
            -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -NotAfter (Get-Date).AddDays(390) `
            -CertStoreLocation Cert:\LocalMachine\My `
            -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.1', ('2.5.29.17={text}' + ($san -join '&')))
        Write-Log 'HTTPS: server certificate issued' 'lf'
    }
    return $leaf
}

# Lie le certificat au port HTTPS ; verifie le resultat (sinon exception : le serveur ne demarre pas).
function Set-SslBinding($leaf) {
    $ipp = '0.0.0.0:' + $RemotePort
    # cmd /c : evite qu'une sortie stderr de netsh devienne une erreur terminante ($ErrorActionPreference = 'Stop').
    $null = & cmd.exe /c ('netsh.exe http delete sslcert ipport=' + $ipp + ' 2>&1')
    $out = & cmd.exe /c ('netsh.exe http add sslcert ipport=' + $ipp + ' certhash=' + $leaf.Thumbprint + ' appid=' + $SslAppId + ' certstorename=MY 2>&1')
    if ($LASTEXITCODE -ne 0) { throw (Tf 'err.bind' @((($out | Out-String).Trim()))) }
    $chk = (& cmd.exe /c ('netsh.exe http show sslcert ipport=' + $ipp + ' 2>&1') | Out-String)
    if ($chk.ToUpper().Replace(' ', '').IndexOf($leaf.Thumbprint.ToUpper()) -lt 0) { throw (Tf 'err.bind' @('binding not found')) }
}

function Remove-SslBinding {
    try { $null = & cmd.exe /c ('netsh.exe http delete sslcert ipport=0.0.0.0:' + $RemotePort + ' 2>&1') } catch { }
}

# Exporte la cle PUBLIQUE de l'autorite sur le Bureau (pour l'installer sur l'iPhone). Retourne le chemin.
function Export-CaFile {
    $bytes = Get-CaBytes
    if ($bytes -eq $null) { throw (T 'err.noca') }
    $dir = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrEmpty($dir) -or -not (Test-Path -LiteralPath $dir)) { $dir = $cfgDir }
    $p = Join-Path $dir 'ZerkiWatch-CA.cer'
    [System.IO.File]::WriteAllBytes($p, $bytes)
    return $p
}

function Start-Remote {
    $S.Pin = Get-Pin
    $ruleOk = $true
    try {
        Get-NetFirewallRule -Group $RuleGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        Get-NetFirewallRule -Group $LegacyRuleGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName 'ZerkiWatch - iPhone remote' -Group $RuleGroup -Direction Inbound -Action Allow `
            -Protocol TCP -LocalPort $RemotePort -RemoteAddress LocalSubnet -Profile Any -Enabled True | Out-Null
    } catch { $ruleOk = $false }
    try {
        $leafCert = Initialize-RemoteCert
        Set-SslBinding $leafCert
    } catch {
        $S.RemoteError = (Tf 'err.cert' @($_.Exception.Message))
        Write-Log ('HTTPS certificate: ' + $_.Exception.Message) 'cert'
        return $false
    }
    try {
        $l = New-Object System.Net.HttpListener
        $l.Prefixes.Add('https://+:' + $RemotePort + '/')
        $l.Start()
        $S.Listener = $l
        $S.Task = $l.GetContextAsync()
        if (-not $ruleOk) { $S.RemoteError = (T 'err.rule_not_created') }
        return $true
    } catch {
        $S.RemoteError = $_.Exception.Message
        return $false
    }
}

function Stop-Remote {
    try { if ($S.Listener -ne $null) { $S.Listener.Close() } } catch { }
    $S.Listener = $null
    $S.Task = $null
    Remove-SslBinding
    try { Get-NetFirewallRule -Group $RuleGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue; Get-NetFirewallRule -Group $LegacyRuleGroup -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue } catch { }
}

function Poll-Remote {
    if (($S.Task -ne $null) -and $S.Task.IsCompleted) {
        $done = $S.Task
        $S.Task = $null
        if ((-not $done.IsFaulted) -and (-not $done.IsCanceled)) { Handle-Remote $done.Result }
        if (($S.Listener -ne $null) -and $S.Listener.IsListening) { $S.Task = $S.Listener.GetContextAsync() }
    }
    if ($S.PendingTest -and (-not $S.Busy)) { $S.PendingTest = $false; Invoke-Tests }
}

# ---------- Mesures : debit, applications, services ----------
$netCode = @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Diagnostics.Eventing.Reader;
using System.IO;
using System.Threading;

public static class NetEtw
{
    const string SessionName = "ZerkiWatchNet";
    static Thread th;
    static volatile bool run;
    static readonly object lk = new object();
    static Dictionary<int, double[]> snap = new Dictionary<int, double[]>();
    static Dictionary<int, double[]> tot = new Dictionary<int, double[]>();
    public static volatile string Status = "starting";
    public static volatile bool Paused;

    static int RunTool(string exe, string args)
    {
        try
        {
            ProcessStartInfo psi = new ProcessStartInfo(exe, args);
            psi.CreateNoWindow = true;
            psi.UseShellExecute = false;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;
            using (Process p = Process.Start(psi))
            {
                p.StandardOutput.ReadToEnd();
                p.StandardError.ReadToEnd();
                p.WaitForExit(20000);
                return p.HasExited ? p.ExitCode : -1;
            }
        }
        catch { return -2; }
    }

    static void Wait(int ms)
    {
        int t = 0;
        while (run && t < ms) { Thread.Sleep(100); t += 100; }
    }

    static void Loop(string dir)
    {
        string etl = Path.Combine(dir, "net.etl");
        RunTool("logman.exe", "stop ModeReseauNet -ets");
        RunTool("logman.exe", "stop " + SessionName + " -ets");
        while (run)
        {
            if (Paused)
            {
                lock (lk) { snap = new Dictionary<int, double[]>(); }
                Status = "starting";
                Wait(500);
                continue;
            }
            try
            {
                try { if (File.Exists(etl)) File.Delete(etl); } catch { }
                int rc = RunTool("logman.exe", "start " + SessionName + " -p \"Microsoft-Windows-Kernel-Network\" 0x30 0xFF -o \"" + etl + "\" -ets -bs 128 -nb 16 64 -max 64");
                if (rc != 0)
                {
                    Status = "trace failed (code " + rc + ", administrator rights required)";
                    Wait(6000);
                    continue;
                }
                Stopwatch sw = Stopwatch.StartNew();
                Wait(3000);
                RunTool("logman.exe", "stop " + SessionName + " -ets");
                double secs = Math.Max(0.5, sw.Elapsed.TotalSeconds);
                if (!run) break;
                Parse(etl, secs);
            }
            catch (Exception ex)
            {
                Status = "error: " + ex.Message;
                Wait(4000);
            }
        }
        RunTool("logman.exe", "stop " + SessionName + " -ets");
    }

    static void Parse(string etl, double secs)
    {
        if (!File.Exists(etl)) { Status = "no trace file"; return; }
        Dictionary<int, double[]> acc = new Dictionary<int, double[]>();
        long n = 0;
        using (EventLogReader rd = new EventLogReader(new EventLogQuery(etl, PathType.FilePath)))
        {
            EventRecord e;
            while ((e = rd.ReadEvent()) != null)
            {
                using (e)
                {
                    int id = e.Id;
                    bool tx = (id == 10 || id == 26 || id == 42 || id == 58);
                    bool rx = (id == 11 || id == 27 || id == 43 || id == 59);
                    if (!tx && !rx) continue;
                    IList<EventProperty> p = e.Properties;
                    if (p == null || p.Count < 2) continue;
                    int procId;
                    long size;
                    try { procId = Convert.ToInt32(p[0].Value); size = Convert.ToInt64(p[1].Value); }
                    catch { continue; }
                    if (p.Count >= 4)
                    {
                        try
                        {
                            if (p[2].Value != null && p[3].Value != null && p[2].Value.ToString() == p[3].Value.ToString()) continue;
                        }
                        catch { }
                    }
                    double[] a;
                    if (!acc.TryGetValue(procId, out a)) { a = new double[2]; acc[procId] = a; }
                    if (rx) a[0] += size; else a[1] += size;
                    n++;
                }
            }
        }
        Dictionary<int, double[]> res = new Dictionary<int, double[]>();
        foreach (KeyValuePair<int, double[]> kv in acc)
        {
            res[kv.Key] = new double[] { kv.Value[0] / secs, kv.Value[1] / secs };
        }
        lock (lk)
        {
            snap = res;
            foreach (KeyValuePair<int, double[]> kv in acc)
            {
                double[] t;
                if (!tot.TryGetValue(kv.Key, out t)) { t = new double[2]; tot[kv.Key] = t; }
                t[0] += kv.Value[0];
                t[1] += kv.Value[1];
            }
        }
        Status = "ok (" + n + " events)";
    }

    public static void Start(string dir)
    {
        if (th != null) return;
        Directory.CreateDirectory(dir);
        run = true;
        th = new Thread(delegate () { Loop(dir); });
        th.IsBackground = true;
        th.Start();
    }

    public static void Stop()
    {
        run = false;
        if (th != null) { th.Join(8000); th = null; }
        RunTool("logman.exe", "stop " + SessionName + " -ets");
    }

    public static double[][] TakeTotals()
    {
        lock (lk)
        {
            double[][] r = new double[tot.Count][];
            int i = 0;
            foreach (KeyValuePair<int, double[]> kv in tot)
            {
                r[i++] = new double[] { kv.Key, kv.Value[0], kv.Value[1] };
            }
            tot = new Dictionary<int, double[]>();
            return r;
        }
    }

    public static double[][] Snapshot()
    {
        lock (lk)
        {
            double[][] r = new double[snap.Count][];
            int i = 0;
            foreach (KeyValuePair<int, double[]> kv in snap)
            {
                r[i++] = new double[] { kv.Key, kv.Value[0], kv.Value[1] };
            }
            return r;
        }
    }
}
'@
$S.EtwOk = $false
$S.EtwStatus = ''
try { Add-Type -TypeDefinition $netCode -ReferencedAssemblies 'System.Core'; $S.EtwOk = $true } catch { $S.EtwStatus = 'compilation failed' }

$S.Dl = 0.0
$S.Ul = 0.0
$S.HistDl = New-Object 'System.Collections.Generic.List[double]'
$S.HistUl = New-Object 'System.Collections.Generic.List[double]'
$S.Adapters = @()
$S.Sig = ''
$S.Prev = @{}
$S.Tick = 0
$S.LastTrim = [DateTime]::UtcNow
$S.LastT = 0.0
$S.Watch = [System.Diagnostics.Stopwatch]::StartNew()
$S.Apps = @()
$S.Svcs = @()
$S.SvcMap = @{}
$S.LastRemote = [DateTime]::MinValue
$S.NeedAt = [DateTime]::UtcNow
$S.Bg = $null
$S.BgH = $null
$S.BgKind = ''
$S.SvcAsk = [DateTime]::MinValue
$S.SvcStamp = [DateTime]::MinValue
$S.NameCache = @{}
$S.Native = $native
$S.TotRx = 0.0
$S.TotTx = 0.0
$S.Cpu = 0.0
$S.Gpu = -1.0
$S.GpuName = ''
$S.VramUsed = 0.0
$S.VramTot = 0.0
$S.Disks = @()
$S.AllDrives = @()
$S.DiskWant = New-Object System.Collections.ArrayList
$S.DiskCustom = $false
$S.WantPushed = '#'
$S.Hw = [hashtable]::Synchronized(@{ Gpu = 0.0; GpuOk = $false; GpuName = ''; VramUsed = 0.0; VramTot = 0.0; Disks = @(); AllDrives = @(); Want = @(); Stop = $false; Slow = $false })
$S.HwPs = $null
$hwScript = @'
$ctrs = @{}
$vctrs = @{}
$dctr = @{}
$dRetry = @{}
$lastEnum = [DateTime]::MinValue
$lastDrv = [DateTime]::MinValue
$driveRows = @{}
$adRam = 0.0
try { $vc = Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | Select-Object -First 1; $H.GpuName = [string]$vc.Name; $adRam = [double]$vc.AdapterRAM } catch { }
try {
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    $bestSize = 0.0
    $bestName = ''
    foreach ($k in @(Get-ChildItem -LiteralPath $base -ErrorAction Stop)) {
        if ($k.PSChildName -notmatch '^\d{4}$') { continue }
        try {
            $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop
            $q = $p.'HardwareInformation.qwMemorySize'
            if ($q -eq $null) { $q = $p.'HardwareInformation.MemorySize' }
            if ($q -eq $null) { continue }
            if ($q -is [byte[]]) {
                $bb = New-Object byte[] 8
                [Array]::Copy($q, $bb, [Math]::Min($q.Length, 8))
                $sz = [double][BitConverter]::ToUInt64($bb, 0)
            } else {
                $sz = [double]$q
                if ($sz -lt 0) { $sz = $sz + 4294967296.0 }
            }
            if ($sz -gt $bestSize) { $bestSize = $sz; $bestName = [string]$p.DriverDesc }
        } catch { }
    }
    if ($bestSize -gt 0) {
        $H.VramTot = $bestSize
        if ($bestName -ne '') { $H.GpuName = $bestName }
    }
} catch { }
if (($H.VramTot -le 0) -and ($adRam -gt 0)) { $H.VramTot = $adRam }
while (-not $H.Stop) {
    $now = [DateTime]::UtcNow
    try {
        if (($now - $lastEnum).TotalSeconds -gt 20) {
            $lastEnum = $now
            try {
                $cat = New-Object System.Diagnostics.PerformanceCounterCategory('GPU Engine')
                $names = $cat.GetInstanceNames()
                $have = @{}
                foreach ($n in $names) { $have[$n] = $true }
                foreach ($k in @($ctrs.Keys)) {
                    if (-not $have.ContainsKey($k)) { try { $ctrs[$k].C.Dispose() } catch { }; $ctrs.Remove($k) }
                }
                foreach ($n in $names) {
                    if ($ctrs.ContainsKey($n)) { continue }
                    $mt = [regex]::Match($n, 'engtype_(.+)$')
                    if (-not $mt.Success) { continue }
                    try {
                        $c = New-Object System.Diagnostics.PerformanceCounter('GPU Engine', 'Utilization Percentage', $n, $true)
                        $null = $c.NextValue()
                        $ctrs[$n] = @{ T = $mt.Groups[1].Value; C = $c }
                    } catch { }
                }
            } catch { }
            try {
                $cat2 = New-Object System.Diagnostics.PerformanceCounterCategory('GPU Adapter Memory')
                $names2 = $cat2.GetInstanceNames()
                $have2 = @{}
                foreach ($n in $names2) { $have2[$n] = $true }
                foreach ($k in @($vctrs.Keys)) {
                    if (-not $have2.ContainsKey($k)) { try { $vctrs[$k].Dispose() } catch { }; $vctrs.Remove($k) }
                }
                foreach ($n in $names2) {
                    if ($vctrs.ContainsKey($n)) { continue }
                    try { $vctrs[$n] = New-Object System.Diagnostics.PerformanceCounter('GPU Adapter Memory', 'Dedicated Usage', $n, $true) } catch { }
                }
            } catch { }
        }
        if ($ctrs.Count -gt 0) {
            $sum = @{}
            foreach ($k in @($ctrs.Keys)) {
                try {
                    $v = [double]$ctrs[$k].C.NextValue()
                    $tt = $ctrs[$k].T
                    if ($sum.ContainsKey($tt)) { $sum[$tt] = $sum[$tt] + $v } else { $sum[$tt] = $v }
                } catch { try { $ctrs[$k].C.Dispose() } catch { }; $ctrs.Remove($k) }
            }
            $top = 0.0
            foreach ($v2 in $sum.Values) { if ($v2 -gt $top) { $top = $v2 } }
            $H.Gpu = [math]::Min(100.0, $top)
            $H.GpuOk = $true
        } else { $H.GpuOk = $false }
        if ($vctrs.Count -gt 0) {
            $vmax = 0.0
            foreach ($k in @($vctrs.Keys)) {
                try { $vv = [double]$vctrs[$k].NextValue(); if ($vv -gt $vmax) { $vmax = $vv } } catch { try { $vctrs[$k].Dispose() } catch { }; $vctrs.Remove($k) }
            }
            $H.VramUsed = $vmax
        }
    } catch { }
    try {
        if (($now - $lastDrv).TotalSeconds -ge 3) {
            $lastDrv = $now
            $rows = @{}
            foreach ($d in [System.IO.DriveInfo]::GetDrives()) {
                try {
                    $dty = [string]$d.DriveType
                    if (($dty -ne 'Fixed') -and ($dty -ne 'Removable')) { continue }
                    if (-not $d.IsReady) { continue }
                    $l = $d.Name.Substring(0, 2)
                    $lab = ''
                    try { $lab = ([string]$d.VolumeLabel).Replace('|', ' ') } catch { }
                    $tot = [double]$d.TotalSize
                    $free = [double]$d.AvailableFreeSpace
                    $pc = 0.0
                    if ($tot -gt 0) { $pc = 100.0 * ($tot - $free) / $tot }
                    $rows[$l] = @{ L = $l; Name = $lab; Type = $dty; Tot = $tot; Used = ($tot - $free); Pct = $pc; Act = 0.0; R = 0.0; W = 0.0 }
                } catch { }
            }
            $driveRows = $rows
            $lst = New-Object System.Collections.ArrayList
            foreach ($k in @($rows.Keys | Sort-Object)) {
                $r = $rows[$k]
                [void]$lst.Add(($r.L + '|' + $r.Name + '|' + $r.Type + '|' + [string][long]$r.Tot))
            }
            $H.AllDrives = $lst.ToArray()
        }
        $want = @($H.Want)
        foreach ($L in @($dctr.Keys)) {
            if (($want -notcontains $L) -or (-not $driveRows.ContainsKey($L))) {
                try { $dctr[$L].T.Dispose(); $dctr[$L].R.Dispose(); $dctr[$L].W.Dispose() } catch { }
                $dctr.Remove($L)
            }
        }
        foreach ($L in $want) {
            if (-not $driveRows.ContainsKey($L)) { continue }
            if (-not $dctr.ContainsKey($L)) {
                if ((-not $dRetry.ContainsKey($L)) -or (($now - $dRetry[$L]).TotalSeconds -gt 20)) {
                    $dRetry[$L] = $now
                    try {
                        $ct = New-Object System.Diagnostics.PerformanceCounter('LogicalDisk', '% Disk Time', $L, $true)
                        $cr = New-Object System.Diagnostics.PerformanceCounter('LogicalDisk', 'Disk Read Bytes/sec', $L, $true)
                        $cw = New-Object System.Diagnostics.PerformanceCounter('LogicalDisk', 'Disk Write Bytes/sec', $L, $true)
                        $null = $ct.NextValue(); $null = $cr.NextValue(); $null = $cw.NextValue()
                        $dctr[$L] = @{ T = $ct; R = $cr; W = $cw }
                    } catch { }
                }
            }
            if ($dctr.ContainsKey($L)) {
                try {
                    $driveRows[$L].Act = [math]::Min(100.0, [double]$dctr[$L].T.NextValue())
                    $driveRows[$L].R = [double]$dctr[$L].R.NextValue()
                    $driveRows[$L].W = [double]$dctr[$L].W.NextValue()
                } catch { $dctr.Remove($L) }
            }
        }
        $outl = New-Object System.Collections.ArrayList
        foreach ($L in $want) { if ($driveRows.ContainsKey($L)) { [void]$outl.Add($driveRows[$L]) } }
        $H.Disks = $outl.ToArray()
    } catch { }
    $waited = 0
    while (-not $H.Stop) {
        Start-Sleep -Milliseconds 250
        $waited = $waited + 250
        if ($H.Slow) { if ($waited -ge 6000) { break } } else { if ($waited -ge 1500) { break } }
    }
}
'@
try {
    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('H', $S.Hw)
    $S.HwPs = [powershell]::Create()
    $S.HwPs.Runspace = $rs
    [void]$S.HwPs.AddScript($hwScript)
    $null = $S.HwPs.BeginInvoke()
} catch { $S.HwPs = $null }
$S.Ram = 0.0
$S.RamTot = 0.0
$S.RamUsed = 0.0
$S.CpuCounter = $null
$S.AdapterName = (T 'tip.net_default')
$S.LinkMbps = 0.0
$S.Tip = ''
$S.TipShown = ''
$S.Quitting = $false
$S.BalloonShown = $false
if (-not $native) {
    try { Add-Type -AssemblyName Microsoft.VisualBasic } catch { }
    try { $S.CpuCounter = New-Object System.Diagnostics.PerformanceCounter('Processor', '% Processor Time', '_Total'); $null = $S.CpuCounter.NextValue() } catch { $S.CpuCounter = $null }
}

function Format-Mbps([double]$v) {
    if ($v -ge 100) { return $v.ToString('0') }
    if ($v -ge 10) { return $v.ToString('0.0') }
    return $v.ToString('0.00')
}

function Update-Adapters {
    $all = @()
    $withGw = @()
    foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
        if ($ni.OperationalStatus -ne [System.Net.NetworkInformation.OperationalStatus]::Up) { continue }
        $nt = $ni.NetworkInterfaceType.ToString()
        if ($nt -eq 'Loopback' -or $nt -eq 'Tunnel') { continue }
        if ($ni.Description -match 'Virtual|VPN|TAP-Windows|Wintun|Hyper-V|VMware|VirtualBox|Bluetooth|WireGuard|Tailscale|Npcap|Pseudo|vEthernet') { continue }
        $all += $ni
        $hasGw = $false
        try {
            foreach ($gw in $ni.GetIPProperties().GatewayAddresses) {
                $ga = $gw.Address.ToString()
                if ($ga -ne '0.0.0.0' -and $ga -ne '::') { $hasGw = $true }
            }
        } catch { }
        if ($hasGw) { $withGw += $ni }
    }
    if ($withGw.Count -eq 0) { $withGw = $all }
    $S.Adapters = $withGw
    $sig = (($withGw | ForEach-Object { $_.Id }) -join ',')
    if ($sig -ne $S.Sig) { $S.Sig = $sig; $S.Prev = @{} }
    if ($withGw.Count -gt 0) {
        $S.AdapterName = (($withGw | ForEach-Object { $_.Name }) -join ', ')
        $sp = 0.0
        foreach ($ni in $withGw) { if ($ni.Speed -gt $sp -and $ni.Speed -lt 1e12) { $sp = [double]$ni.Speed } }
        $S.LinkMbps = $sp / 1e6
    } else {
        $S.AdapterName = (T 'tip.net_none')
        $S.LinkMbps = 0.0
    }
}

function Get-EtwRows { return [NetEtw]::Snapshot() }

function Get-ServiceMap {
    $map = @{}
    try {
        foreach ($sv in (Get-CimInstance -ClassName Win32_Service -Filter "State='Running'" -ErrorAction Stop)) {
            $spid = [int]$sv.ProcessId
            if ($spid -le 0) { continue }
            if (-not $map.ContainsKey($spid)) { $map[$spid] = New-Object 'System.Collections.Generic.List[string]' }
            $map[$spid].Add([string]$sv.DisplayName)
        }
    } catch { }
    return $map
}

function Get-AppLabel([int]$procId) {
    if ($S.NameCache.ContainsKey($procId)) { return $S.NameCache[$procId] }
    $label = ''
    try {
        $pr = Get-Process -Id $procId -ErrorAction Stop
        $label = $pr.ProcessName
        try {
            $desc = $pr.MainModule.FileVersionInfo.FileDescription
            if ($desc -and $desc.Trim().Length -gt 0) { $label = $desc.Trim() }
        } catch { }
    } catch { $label = 'Process ' + $procId }
    if ($S.NameCache.Count -gt 800) { $S.NameCache = @{} }
    $S.NameCache[$procId] = $label
    return $label
}

function Convert-Top($tbl) {
    $out = @()
    foreach ($k in ($tbl.Keys | Sort-Object { $tbl[$_] } -Descending | Select-Object -First 5)) {
        $out += @{ n = [string]$k; m = [math]::Round([double]$tbl[$k], 2) }
    }
    return $out
}

function Start-BgWork([string]$kind) {
    if ($S.BgH -ne $null) { return }
    try {
        if ($S.Bg -eq $null) { $S.Bg = [powershell]::Create() }
        $S.Bg.Commands.Clear()
        if ($kind -eq 'mode') {
            $src = '$r = @(Get-NetFirewallRule -Group ''__G__'' -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq ''True'' }); $r2 = @(Get-NetFirewallRule -Group ''__G2__'' -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq ''True'' }); if (($r.Count -ge 2) -or ($r2.Count -ge 2)) { ''LOCAL'' } else { ''INTERNET'' }'
            $src = $src.Replace('__G__', $Group).Replace('__G2__', $LegacyGroups[0])
        } else {
            $src = 'Get-CimInstance -ClassName Win32_Service -Filter "State=''Running''" -ErrorAction SilentlyContinue | ForEach-Object { ([string]$_.ProcessId) + ''|'' + $_.DisplayName }'
        }
        [void]$S.Bg.AddScript($src)
        $S.BgKind = $kind
        $S.BgH = $S.Bg.BeginInvoke()
    } catch { $S.BgH = $null }
}
function Poll-Bg {
    if ($S.BgH -eq $null) { return }
    if (-not $S.BgH.IsCompleted) { return }
    $res = @()
    try { $res = @($S.Bg.EndInvoke($S.BgH)) } catch { $res = @() }
    $S.BgH = $null
    try {
        if ($S.BgKind -eq 'mode') {
            if ($res.Count -gt 0) {
                $m = [string]$res[0]
                if ((-not $S.Busy) -and (-not $S.Switching) -and ((($m -eq 'LOCAL')) -ne $S.Local)) { Update-Ui $m }
            }
        } else {
            $map = @{}
            foreach ($ln in $res) {
                $p = ([string]$ln).Split('|', 2)
                if ($p.Count -lt 2) { continue }
                $spid = 0
                if (-not [int]::TryParse($p[0], [ref]$spid)) { continue }
                if ($spid -le 0) { continue }
                if (-not $map.ContainsKey($spid)) { $map[$spid] = New-Object 'System.Collections.Generic.List[string]' }
                $map[$spid].Add($p[1])
            }
            if ($map.Count -gt 0) { $S.SvcMap = $map }
            $S.SvcStamp = [DateTime]::UtcNow
        }
    } catch { }
}

function Update-Procs {
    if (-not $S.EtwOk) { return }
    $rows = Get-EtwRows
    if ((([DateTime]::UtcNow - $S.SvcStamp).TotalSeconds -gt 30) -and (([DateTime]::UtcNow - $S.SvcAsk).TotalSeconds -gt 30)) { $S.SvcAsk = [DateTime]::UtcNow; Start-BgWork 'svc' }
    $apps = @{}
    $svcs = @{}
    foreach ($row in $rows) {
        $procId = [int]$row[0]
        $mbps = ([double]$row[1] + [double]$row[2]) * 8.0 / 1000000.0
        if ($mbps -lt 0.005) { continue }
        if ($procId -eq 4) {
            $key = (T 'app.system')
            $tbl = $svcs
        } elseif ($S.SvcMap.ContainsKey($procId)) {
            $names = $S.SvcMap[$procId]
            $key = $names[0]
            if ($names.Count -gt 1) { $key = $key + ' (+' + ($names.Count - 1) + ')' }
            $tbl = $svcs
        } else {
            $key = Get-AppLabel $procId
            $tbl = $apps
        }
        if ($tbl.ContainsKey($key)) { $tbl[$key] = $tbl[$key] + $mbps } else { $tbl[$key] = $mbps }
    }
    $S.Apps = @(Convert-Top $apps)
    $S.Svcs = @(Convert-Top $svcs)
}

function Update-Mon {
    $S.Tick = $S.Tick + 1
    $now = $S.Watch.Elapsed.TotalSeconds
    $dt = $now - $S.LastT
    $S.LastT = $now
    if ($dt -lt 0.25) { $dt = 0.25 }
    if ((($S.Tick - 1) % 5) -eq 0) { try { Update-Adapters } catch { } }

    $drx = 0.0
    $dtx = 0.0
    foreach ($ni in $S.Adapters) {
        try {
            $stt = $ni.GetIPv4Statistics()
            $r = [double]$stt.BytesReceived
            $t = [double]$stt.BytesSent
            $key = $ni.Id
            if ($S.Prev.ContainsKey($key)) {
                $old = $S.Prev[$key]
                $da = $r - $old[0]; if ($da -lt 0) { $da += 4294967296.0 }
                $db = $t - $old[1]; if ($db -lt 0) { $db += 4294967296.0 }
                $drx += $da
                $dtx += $db
            }
            $S.Prev[$key] = @($r, $t)
        } catch { }
    }
    $S.TotRx = $S.TotRx + $drx
    $S.TotTx = $S.TotTx + $dtx
    $rxm = $drx * 8.0 / 1000000.0 / $dt
    $txm = $dtx * 8.0 / 1000000.0 / $dt
    if ($rxm -gt 20000) { $rxm = 0.0 }
    if ($txm -gt 20000) { $txm = 0.0 }
    $S.Dl = $rxm
    $S.Ul = $txm
    $S.HistDl.Add($rxm)
    $S.HistUl.Add($txm)
    while ($S.HistDl.Count -gt 40) { $S.HistDl.RemoveAt(0) }
    while ($S.HistUl.Count -gt 40) { $S.HistUl.RemoveAt(0) }

    if ($S.Native) {
        try {
            $S.Cpu = [MN]::Cpu()
            $mm = [MN]::Mem()
            $S.Ram = $mm[0]
            $S.RamTot = $mm[1]
            $S.RamUsed = $mm[1] - $mm[2]
        } catch { }
    } else {
        try { if ($S.CpuCounter -ne $null) { $S.Cpu = [math]::Min(100.0, [double]$S.CpuCounter.NextValue()) } } catch { }
        try {
            $ci = New-Object Microsoft.VisualBasic.Devices.ComputerInfo
            $tot = [double]$ci.TotalPhysicalMemory
            $av = [double]$ci.AvailablePhysicalMemory
            $S.RamTot = $tot
            $S.RamUsed = $tot - $av
            if ($tot -gt 0) { $S.Ram = 100.0 * ($tot - $av) / $tot }
        } catch { }
    }
    try {
        $hw = $S.Hw
        if ($hw.GpuOk) { $S.Gpu = [double]$hw.Gpu } else { $S.Gpu = -1.0 }
        $S.GpuName = [string]$hw.GpuName
        $S.VramUsed = [double]$hw.VramUsed
        $S.VramTot = [double]$hw.VramTot
        $S.Disks = @($hw.Disks)
        $S.AllDrives = @($hw.AllDrives)
        if ((-not $S.DiskCustom) -and ($S.AllDrives.Count -gt 0)) {
            $dflt = New-Object System.Collections.ArrayList
            foreach ($e in $S.AllDrives) {
                $pp = ([string]$e).Split('|')
                if (($pp.Count -ge 3) -and ($pp[2] -eq 'Fixed') -and ($dflt.Count -lt 4)) { [void]$dflt.Add($pp[0]) }
            }
            if (($dflt.Count -eq 0)) { $pp = ([string]$S.AllDrives[0]).Split('|'); [void]$dflt.Add($pp[0]) }
            if ((($dflt.ToArray()) -join ',') -ne (($S.DiskWant.ToArray()) -join ',')) { $S.DiskWant = $dflt }
        }
        $wj = (($S.DiskWant.ToArray()) -join ',')
        if ($wj -ne $S.WantPushed) { $hw.Want = [string[]]@($S.DiskWant.ToArray()); $S.WantPushed = $wj }
    } catch { }
    try { Update-Hist $drx $dtx $dt } catch { Write-Log ('Update-Hist: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'uh' }
    try { Poll-Bg } catch { }
    $nowU = [DateTime]::UtcNow
    $formOn = ($form.Visible -and ($form.WindowState -ne [System.Windows.Forms.FormWindowState]::Minimized))
    $remoteOn = (($nowU - $S.LastRemote).TotalSeconds -lt 15)
    $needProcs = ($formOn -or $remoteOn)
    if ($needProcs) { $S.NeedAt = $nowU }
    if ($needProcs -and (($S.Tick % 2) -eq 0)) { try { Update-Procs } catch { } }
    if ($S.EtwOk -and $S.CumulOn -and (($S.Tick % 2) -eq 0)) { try { Update-AppAcc } catch { Write-Log ('App totals: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'ua' } }
    if ($S.EtwOk) {
        $pz = ((($nowU - $S.NeedAt).TotalSeconds -gt 15) -and (-not $S.CumulOn))
        try { if ([NetEtw]::Paused -ne $pz) { [NetEtw]::Paused = $pz } } catch { }
    }
    $slow = ((-not $formOn) -and (-not $barForm.Visible) -and (-not $wForm.Visible) -and (-not $remoteOn))
    try { $S.Hw.Slow = $slow } catch { }
    $trimEvery = 0
    if ($slow) { $trimEvery = 120 } elseif (-not $formOn) { $trimEvery = 300 }
    if ($S.Native -and ($trimEvery -gt 0) -and ((($nowU - $S.LastTrim).TotalSeconds) -gt $trimEvery)) {
        $S.LastTrim = $nowU
        try { [MN]::TrimMem() } catch { }
    }
    $wantMs = 1000
    if ($slow) { $wantMs = 4000 }
    if ($monTimer.Interval -ne $wantMs) { $monTimer.Interval = $wantMs }
    if ($S.EtwOk) { try { $S.EtwStatus = [NetEtw]::Status } catch { } }

    if ((($S.Tick % 20) -eq 3) -and (-not $S.Busy) -and (-not $S.Switching)) { Start-BgWork 'mode' }
    try { Update-Bar } catch { Write-Log ('Update-Bar: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'ub' }
    try { Check-Alerts } catch { Write-Log ('Check-Alerts: ' + $_.Exception.Message) 'ca' }
    try { Check-TimedCut } catch { Write-Log ('Check-TimedCut: ' + $_.Exception.Message) 'ct' }
    try { Update-Widget } catch { Write-Log ('Update-Widget: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'uw' }
    if ($formOn) { try { $pnlRight.Invalidate() } catch { } }
}

function Update-BarTip {
    $nl = "`n"
    $linkTxt = (T 'tip.unknown')
    if ($S.LinkMbps -gt 0) { $linkTxt = $S.LinkMbps.ToString('0') + ' Mbps' }
    $gpuTxt = (T 'tip.gpu_none')
    if ($S.Gpu -ge 0) { $gpuTxt = (Tf 'tip.gpu' @($S.Gpu.ToString('0'))) }
    if (($S.VramTot -gt 0) -and ($S.Gpu -ge 0)) { $gpuTxt = $gpuTxt + $nl + (Tf 'tip.vram' @((Format-Bytes $S.VramUsed), (Format-Bytes $S.VramTot))) }
    $dskTxt = (T 'tip.disk_none')
    $dl = New-Object System.Collections.ArrayList
    foreach ($dk in @($S.Disks)) {
        [void]$dl.Add((Tf 'tip.disk' @($dk.L, (Format-Bytes $dk.Used), (Format-Bytes $dk.Tot), ([double]$dk.Pct).ToString('0'), ([double]$dk.Act).ToString('0'))))
    }
    if ($dl.Count -gt 0) { $dskTxt = ($dl.ToArray() -join $nl) }
    $S.Tip = ((Tf 'tip.net' @($S.AdapterName)) + $nl +
        (Tf 'tip.link' @($linkTxt)) + $nl +
        (Tf 'tip.rate' @((Format-Rate $S.Dl), (Format-Rate $S.Ul))) + $nl +
        (Tf 'tip.total' @((Format-Bytes $S.TotRx), (Format-Bytes $S.TotTx))) + $nl +
        (Tf 'tip.cpu' @($S.Cpu.ToString('0'))) + $nl +
        (T 'tip.click') + $nl +
        (Tf 'tip.ram' @((Format-Bytes $S.RamUsed), (Format-Bytes $S.RamTot), $S.Ram.ToString('0'))) + $nl + $gpuTxt + $nl + $dskTxt)
    if ((($S.Tick % 3) -eq 0) -and ($S.Tip -ne $S.TipShown)) {
        try { $barTip.SetToolTip($barForm, $S.Tip); $barTip.SetToolTip($wForm, $S.Tip); $S.TipShown = $S.Tip } catch { }
    }
}

function Update-Bar {
    if ($BAR.UserHidden) {
        if ($WID.On -and $wForm.Visible) { Update-BarTip }
        if ($BAR.Dirty) { $BAR.Dirty = $false; Save-BarConfig }
        return
    }
    if ($barForm.Visible) { Update-BarTip }
    if ($S.Native) {
        try {
            $fs = [MN]::FullScreen()
            if ($fs -and (-not $BAR.AutoHidden)) { $BAR.AutoHidden = $true; Write-Log 'Bar hidden: full screen detected'; if ($barForm.Visible) { $barForm.Hide() } }
            elseif ((-not $fs) -and $BAR.AutoHidden) { $BAR.AutoHidden = $false; Write-Log 'Bar shown again: full screen ended'; if (-not $BAR.UserHidden) { $barForm.Show() } }
            if ($BAR.Top -and $barForm.Visible) { [MN]::KeepTop($barForm.Handle) }
        } catch { }
    }
    if ($BAR.Dirty) { $BAR.Dirty = $false; Save-BarConfig }
    if ($barForm.Visible) { $barForm.Invalidate() }
}

$UiFont = 'Segoe UI'
try { if ((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains 'Segoe UI Variable Text') { $UiFont = 'Segoe UI Variable Text' } } catch { }
function New-Font([single]$Size, [bool]$Bold) {
    if ($Bold) { $style = [System.Drawing.FontStyle]::Bold } else { $style = [System.Drawing.FontStyle]::Regular }
    return (New-Object System.Drawing.Font($script:UiFont, $Size, $style))
}

function New-RoundPath([int]$X, [int]$Y, [int]$W, [int]$H, [int]$R) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $R * 2
    $p.AddArc($X, $Y, $d, $d, 180, 90)
    $p.AddArc(($X + $W - $d), $Y, $d, $d, 270, 90)
    $p.AddArc(($X + $W - $d), ($Y + $H - $d), $d, $d, 0, 90)
    $p.AddArc($X, ($Y + $H - $d), $d, $d, 90, 90)
    $p.CloseFigure()
    return $p
}

function Enable-DoubleBuffer($Ctl) {
    $prop = [System.Windows.Forms.Control].GetProperty('DoubleBuffered', [System.Reflection.BindingFlags]'NonPublic,Instance')
    $prop.SetValue($Ctl, $true, $null)
}

function New-Label([string]$Text, [int]$X, [int]$Y, [int]$W, [int]$H, $Font, $Color, [string]$Align) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Text
    $l.Location = New-Object System.Drawing.Point($X, $Y)
    $l.Size = New-Object System.Drawing.Size($W, $H)
    $l.Font = $Font
    $l.ForeColor = $Color
    $l.BackColor = [System.Drawing.Color]::Transparent
    $l.TextAlign = $Align
    return $l
}

$dotChar = [string][char]0x25CF

$form = New-Object System.Windows.Forms.Form
$form.Text = 'ZerkiWatch'
$form.ClientSize = New-Object System.Drawing.Size(1100, 700)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.BackColor = $cBg
$form.ForeColor = $cText
Enable-DoubleBuffer $form
$iconB64 = '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'
try {
    if ($env:SELF) {
        $icoPath = Join-Path (Split-Path -Parent $env:SELF) 'ZerkiWatch.ico'
        if (Test-Path -LiteralPath $icoPath) { $form.Icon = New-Object System.Drawing.Icon($icoPath) }
    } else {
        $form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    }
} catch { }

try {
    $icoBytes = [Convert]::FromBase64String($iconB64)
    $icoStream = New-Object System.IO.MemoryStream(,$icoBytes)
    $form.Icon = New-Object System.Drawing.Icon($icoStream)
} catch { }

$lblTitle = New-Label 'ZERKIWATCH' 24 22 150 30 (New-Font 14 $true) $cText 'MiddleLeft'
$form.Controls.Add($lblTitle)
$lblVer = New-Label ('v' + $APPVER) 168 26 80 24 (New-Font 9 $false) $cMuted 'MiddleLeft'
$form.Controls.Add($lblVer)

# --- Interrupteur ---
$toggle = New-Object System.Windows.Forms.Panel
$toggle.Location = New-Object System.Drawing.Point(104, 124)
$toggle.Size = New-Object System.Drawing.Size(220, 110)
$toggle.BackColor = $cCard
$toggle.Cursor = [System.Windows.Forms.Cursors]::Hand
Enable-DoubleBuffer $toggle
$form.Controls.Add($toggle)

$toggle.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $w = $sender.Width
    $h = $sender.Height
    $pos = [double]$S.Pos
    if ($S.Switching) {
        $col = [System.Drawing.Color]::FromArgb(95, 105, 128)
    } else {
        $r  = [int](255 + (74 - 255) * $pos)
        $gg = [int](99 + (222 - 99) * $pos)
        $b  = [int](88 + (128 - 88) * $pos)
        $col = [System.Drawing.Color]::FromArgb($r, $gg, $b)
    }
    $path  = New-RoundPath 2 2 ($w - 4) ($h - 4) (($h - 4) / 2)
    $brush = New-Object System.Drawing.SolidBrush($col)
    $g.FillPath($brush, $path)

    $knobD = $h - 20
    $knobX = 12 + ($w - 24 - $knobD) * $pos
    $shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70, 0, 0, 0))
    $g.FillEllipse($shadow, [single]$knobX, [single]13, [single]$knobD, [single]$knobD)
    $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillEllipse($white, [single]$knobX, [single]10, [single]$knobD, [single]$knobD)

    if (-not $S.Switching) {
        $sf = New-Object System.Drawing.StringFormat
        $sf.Alignment = [System.Drawing.StringAlignment]::Center
        $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
        $font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
        $tb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
        if ($pos -ge 0.5) {
            $rect = New-Object System.Drawing.RectangleF -ArgumentList ([single]14), ([single]0), ([single]80), ([single]$h)
            $g.DrawString('ON', $font, $tb, $rect, $sf)
        } else {
            $rect = New-Object System.Drawing.RectangleF -ArgumentList ([single]($w - 94)), ([single]0), ([single]80), ([single]$h)
            $g.DrawString('OFF', $font, $tb, $rect, $sf)
        }
        $tb.Dispose(); $font.Dispose(); $sf.Dispose()
    }
    $brush.Dispose(); $shadow.Dispose(); $white.Dispose(); $path.Dispose()
})

$lblStatus = New-Label '' 24 252 380 40 (New-Font 20 $true) $cGreen 'MiddleCenter'
$form.Controls.Add($lblStatus)

$lblSub = New-Label '' 44 296 340 44 (New-Font 10 $false) $cMuted 'TopCenter'
$form.Controls.Add($lblSub)

# --- Carte d'etat ---
$card = New-Object System.Windows.Forms.Panel
$card.Location = New-Object System.Drawing.Point(38, 356)
$card.Size = New-Object System.Drawing.Size(352, 140)
$card.BackColor = $cBg
$card.Region = New-Object System.Drawing.Region -ArgumentList (New-RoundPath 0 0 352 140 14)
$form.Controls.Add($card)

$dotNet = New-Label $dotChar 14 14 24 24 (New-Font 12 $false) $cMuted 'MiddleCenter'
$nameNet = New-Label 'Internet' 40 14 120 24 (New-Font 10 $true) $cText 'MiddleLeft'
$valNet = New-Label '' 160 14 178 24 (New-Font 10 $false) $cMuted 'MiddleRight'
$dotBox = New-Label $dotChar 14 50 24 24 (New-Font 12 $false) $cMuted 'MiddleCenter'
$nameBox = New-Label (T 'ui.local_net') 40 50 120 24 (New-Font 10 $true) $cText 'MiddleLeft'
$valBox = New-Label '' 160 50 178 24 (New-Font 10 $false) $cMuted 'MiddleRight'
$lblMsg = New-Label '' 14 88 324 44 (New-Font 9 $false) $cMuted 'TopLeft'
foreach ($c in @($dotNet, $nameNet, $valNet, $dotBox, $nameBox, $valBox, $lblMsg)) { $card.Controls.Add($c) }

$lblFoot = New-Label '' 0 664 1100 36 (New-Font 9 $false) $cMuted 'MiddleCenter'
$form.Controls.Add($lblFoot)
$btnRetest = New-Object System.Windows.Forms.Button
$btnRetest.Text = (T 'ui.retest')
$btnRetest.Location = New-Object System.Drawing.Point(790, 18)
$btnRetest.Size = New-Object System.Drawing.Size(110, 32)
$btnRetest.FlatStyle = 'Flat'
$btnRetest.FlatAppearance.BorderSize = 1
$btnRetest.FlatAppearance.BorderColor = $cBorder
$btnRetest.BackColor = $cCard
$btnRetest.ForeColor = $cText
$btnRetest.Font = New-Font 9 $false
$btnRetest.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnRetest)

$btnHist = New-Object System.Windows.Forms.Button
$btnHist.Text = (T 'ui.history')
$btnHist.Location = New-Object System.Drawing.Point(908, 18)
$btnHist.Size = New-Object System.Drawing.Size(110, 32)
$btnHist.FlatStyle = 'Flat'
$btnHist.FlatAppearance.BorderSize = 1
$btnHist.FlatAppearance.BorderColor = $cBorder
$btnHist.BackColor = $cCard
$btnHist.ForeColor = $cText
$btnHist.Font = New-Font 9 $false
$btnHist.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnHist)

$btnSet = New-Object System.Windows.Forms.Button
$btnSet.Text = (T 'ui.settings')
$btnSet.Location = New-Object System.Drawing.Point(1026, 18)
$btnSet.Size = New-Object System.Drawing.Size(110, 32)
$btnSet.FlatStyle = 'Flat'
$btnSet.FlatAppearance.BorderSize = 1
$btnSet.FlatAppearance.BorderColor = $cBorder
$btnSet.BackColor = $cCard
$btnSet.ForeColor = $cText
$btnSet.Font = New-Font 9 $false
$btnSet.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnSet)
foreach ($oc in @($lblTitle, $lblVer, $toggle, $lblStatus, $lblSub, $card, $btnRetest, $btnHist, $btnSet)) { $oc.Visible = $false }

# --- Colonne de droite : debit, applications, services ---
$cDl = (Pc @(56, 189, 248) @(2, 132, 199))
$cUl = (Pc @(244, 196, 90) @(180, 120, 10))
$cApp = (Pc @(255, 140, 90) @(234, 88, 12))
$cSvc = (Pc @(45, 212, 191) @(13, 148, 136))
$fCardT = New-Object System.Drawing.Font('Segoe UI Semibold', 8.5)
$fBig   = New-Object System.Drawing.Font('Segoe UI Semibold', 20)
$fPctBig = New-Object System.Drawing.Font('Segoe UI Semibold', 17)
$sfCenter = New-Object System.Drawing.StringFormat
$sfCenter.Alignment = [System.Drawing.StringAlignment]::Center
$sfCenter.LineAlignment = [System.Drawing.StringAlignment]::Center
$sfCenter.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
$sfCenter.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
$fSmall = New-Object System.Drawing.Font('Segoe UI', 9)
$fRow   = New-Object System.Drawing.Font('Segoe UI', 9.5)
$fRowV  = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)
$bText  = New-Object System.Drawing.SolidBrush($cText)
$bMuted = New-Object System.Drawing.SolidBrush($cMuted)
$sfEll = New-Object System.Drawing.StringFormat
$sfEll.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
$sfEll.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
$sfRight = New-Object System.Drawing.StringFormat
$sfRight.Alignment = [System.Drawing.StringAlignment]::Far
$sfRight.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
$sfTight = [System.Drawing.StringFormat]::GenericTypographic

$pnlRight = New-Object System.Windows.Forms.Panel
$pnlRight.Location = New-Object System.Drawing.Point(0, 64)
$pnlRight.Size = New-Object System.Drawing.Size(1100, 600)
$pnlRight.BackColor = $cBg
Enable-DoubleBuffer $pnlRight
$form.Controls.Add($pnlRight)

function Draw-Card($g, [int]$x, [int]$y, [int]$w, [int]$h, [string]$title) {
    $path = New-RoundPath $x $y ($w - 1) ($h - 1) 14
    $rc = New-Object System.Drawing.RectangleF -ArgumentList ([single]$x), ([single]$y), ([single]$w), ([single]$h)
    $br = New-Object System.Drawing.SolidBrush($cCard)
    $g.FillPath($br, $path)
    $br.Dispose()
    $pen = New-Object System.Drawing.Pen($cBorder, [single]1)
    $g.DrawPath($pen, $path)
    $pen.Dispose(); $path.Dispose()
    if ($title -ne '') {
        $tk = New-Object System.Drawing.SolidBrush($cAccent)
        $g.FillRectangle($tk, [single]($x + 18), [single]($y + 17), [single]3, [single]12)
        $tk.Dispose()
        $g.DrawString($title, $fCardT, $bMuted, [single]($x + 28), [single]($y + 14))
    }
}

function Format-Pct([double]$p) {
    if ($p -lt 0) { return '--' }
    return ([math]::Round($p)).ToString('0') + '%'
}
function Get-RingColor($accent, [double]$pct) {
    if ($pct -ge 90) { return $cLoadR }
    return $accent
}
function Draw-Ring($g, [single]$cx, [single]$cy, [single]$d, [single]$th, [double]$pct, $col) {
    $r = $d / 2.0
    $trk = New-Object System.Drawing.Pen($cTrack, $th)
    $g.DrawEllipse($trk, [single]($cx - $r), [single]($cy - $r), $d, $d)
    $trk.Dispose()
    if ($pct -ge 0.5) {
        $sweep = [math]::Max(8.0, [math]::Min(100.0, $pct) * 3.6)
        $ap = New-Object System.Drawing.Pen($col, $th)
        $ap.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $ap.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $g.DrawArc($ap, [single]($cx - $r), [single]($cy - $r), $d, $d, [single]-90, [single]$sweep)
        $ap.Dispose()
    }
}
function Draw-Glyph($g, [single]$cx, [single]$cy, [int]$kind, $col, [single]$k) {
    $st = $g.Save()
    $g.TranslateTransform($cx, $cy)
    $g.ScaleTransform($k, $k)
    $p = New-Object System.Drawing.Pen($col, [single]1.6)
    $p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $b = New-Object System.Drawing.SolidBrush($col)
    if ($kind -eq 0) {
        $g.DrawRectangle($p, [single]-4, [single]-4, [single]8, [single]8)
        $g.FillRectangle($b, [single]-1.5, [single]-1.5, [single]3, [single]3)
        foreach ($o in @(-2.5, 2.5)) {
            $g.DrawLine($p, [single]$o, [single]-6.5, [single]$o, [single]-4)
            $g.DrawLine($p, [single]$o, [single]4, [single]$o, [single]6.5)
        }
    } elseif ($kind -eq 1) {
        $p.Width = 2.4
        $g.DrawLine($p, [single]-4, [single]5, [single]-4, [single]0)
        $g.DrawLine($p, [single]0, [single]5, [single]0, [single]-5)
        $g.DrawLine($p, [single]4, [single]5, [single]4, [single]-2)
    } elseif ($kind -eq 2) {
        $g.DrawRectangle($p, [single]-6.5, [single]-4.5, [single]13, [single]8)
        $g.DrawEllipse($p, [single]-2.5, [single]-3, [single]5, [single]5)
        $g.DrawLine($p, [single]-4, [single]6.5, [single]4, [single]6.5)
    } else {
        $g.DrawRectangle($p, [single]-6.5, [single]-3.5, [single]13, [single]7)
        $g.FillEllipse($b, [single]2.5, [single]-1, [single]2.2, [single]2.2)
        $g.DrawLine($p, [single]-4, [single]0, [single]-0.5, [single]0)
    }
    $p.Dispose(); $b.Dispose()
    $g.Restore($st)
}

function Format-DiskPair([double]$u, [double]$t) {
    if ($t -ge 1TB) { return ($u / 1TB).ToString('0.0') + ' / ' + ($t / 1TB).ToString('0.0') + ' ' + (T 'unit.t') }
    return ($u / 1GB).ToString('0') + ' / ' + ($t / 1GB).ToString('0') + ' ' + (T 'unit.g')
}

function Draw-DiskTile($g, [int]$x, [int]$y, [int]$w, [int]$h, $disks) {
    Draw-Card $g $x $y $w $h ''
    Draw-Glyph $g ($x + 25) ($y + 24) 3 $aDsk 1.0
    $g.DrawString((T 'ui.disks'), $fCardT, $bMuted, [single]($x + 40), [single]($y + 17))
    $list = @($disks)
    if ($list.Count -eq 0) {
        $rn = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 10)), ([single]($y + 70)), ([single]($w - 20)), ([single]40)
        $g.DrawString((T 'ui.nodisk'), $fSmall, $bMuted, $rn, $sfCenter)
        return
    }
    $n = [math]::Min(4, $list.Count)
    for ($i = 0; $i -lt $n; $i++) {
        $d = $list[$i]
        $ry = $y + 46 + $i * 31
        $g.DrawString([string]$d.L, $fRowV, $bText, [single]($x + 14), [single]$ry)
        $rv = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 40)), ([single]($ry + 1)), ([single]($w - 54)), ([single]16)
        $g.DrawString((Format-DiskPair ([double]$d.Used) ([double]$d.Tot)), $fSmall, $bMuted, $rv, $sfRight)
        $tr = New-Object System.Drawing.SolidBrush($cTrack)
        $g.FillRectangle($tr, [single]($x + 14), [single]($ry + 20), [single]($w - 28), [single]5)
        $tr.Dispose()
        $col = Get-RingColor $aDsk ([double]$d.Pct)
        $fw = [math]::Max(3.0, ($w - 28) * [math]::Min(100.0, [double]$d.Pct) / 100.0)
        $fb = New-Object System.Drawing.SolidBrush($col)
        $g.FillRectangle($fb, [single]($x + 14), [single]($ry + 20), [single]$fw, [single]5)
        $fb.Dispose()
    }
}

function Draw-NetTile($g, [int]$x, [int]$y, [int]$w, [int]$h, [bool]$down, [double]$val, $hist, $accent, [string]$title) {
    Draw-Card $g $x $y $w $h ''
    $badge = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(46, $accent.R, $accent.G, $accent.B))
    $g.FillEllipse($badge, [single]($x + 16), [single]($y + 14), [single]30, [single]30)
    $badge.Dispose()
    Draw-Arrow $g ($x + 31) ($y + 29) $down $accent
    $g.DrawString($title, $fCardT, $bMuted, [single]($x + 56), [single]($y + 22))
    $txt = Format-Mbps $val
    $g.DrawString($txt, $fBig, $bText, [single]($x + 18), [single]($y + 50), $sfTight)
    $tw = $g.MeasureString($txt, $fBig, 1000, $sfTight).Width
    $g.DrawString('Mbps', $fSmall, $bMuted, [single]($x + 24 + $tw), [single]($y + 64), $sfTight)
    $mx = 1.0
    foreach ($hv in $hist) { if ($hv -gt $mx) { $mx = $hv } }
    Draw-Series $g $hist ($x + 18) ($y + $h - 34) ($w - 36) 22 $accent $mx $true
}

function Draw-RingTile($g, [int]$x, [int]$y, [int]$w, [int]$h, [string]$title, [double]$pct, $accent, [int]$kind, [string]$d1, [string]$d2) {
    Draw-Card $g $x $y $w $h ''
    Draw-Glyph $g ($x + 25) ($y + 24) $kind $accent 1.0
    $g.DrawString($title, $fCardT, $bMuted, [single]($x + 40), [single]($y + 17))
    $col = Get-RingColor $accent $pct
    $cx = $x + $w / 2.0
    $cy = $y + 84
    Draw-Ring $g $cx $cy 92 9 $pct $col
    $rt = New-Object System.Drawing.RectangleF -ArgumentList ([single]($cx - 40)), ([single]($cy - 18)), ([single]80), ([single]36)
    $g.DrawString((Format-Pct $pct), $fPctBig, $bText, $rt, $sfCenter)
    $r1 = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 8)), ([single]($y + $h - 46)), ([single]($w - 16)), ([single]18)
    $g.DrawString($d1, $fRowV, $bText, $r1, $sfCenter)
    $r2 = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 8)), ([single]($y + $h - 26)), ([single]($w - 16)), ([single]16)
    $g.DrawString($d2, $fSmall, $bMuted, $r2, $sfCenter)
}

function Draw-Series($g, $hist, [single]$x, [single]$y, [single]$w, [single]$h, $color, [double]$mx, [bool]$fill) {
    $cnt = $hist.Count
    if ($cnt -lt 2) { return }
    $step = $w / 39.0
    $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
    for ($i = 0; $i -lt $cnt; $i++) {
        $px1 = $x + $w - ($cnt - 1 - $i) * $step
        $py1 = $y + $h - ($hist[$i] / $mx) * $h
        $pts.Add((New-Object System.Drawing.PointF([single]$px1, [single]$py1)))
    }
    if ($fill) {
        $poly = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        $poly.AddRange($pts)
        $poly.Add((New-Object System.Drawing.PointF([single]($x + $w), [single]($y + $h))))
        $poly.Add((New-Object System.Drawing.PointF([single]($x + $w - ($cnt - 1) * $step), [single]($y + $h))))
        $fb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50, $color.R, $color.G, $color.B))
        $g.FillPolygon($fb, $poly.ToArray())
        $fb.Dispose()
    }
    $lp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(230, $color.R, $color.G, $color.B), [single]1.6)
    $lp.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawLines($lp, $pts.ToArray())
    $lp.Dispose()
}

function Draw-Arrow($g, [single]$cx, [single]$cy, [bool]$down, $color) {
    $pen = New-Object System.Drawing.Pen($color, [single]2)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawLine($pen, $cx, [single]($cy - 6), $cx, [single]($cy + 6))
    if ($down) {
        $g.DrawLine($pen, [single]($cx - 4.5), [single]($cy + 1.5), $cx, [single]($cy + 6))
        $g.DrawLine($pen, [single]($cx + 4.5), [single]($cy + 1.5), $cx, [single]($cy + 6))
    } else {
        $g.DrawLine($pen, [single]($cx - 4.5), [single]($cy - 1.5), $cx, [single]($cy - 6))
        $g.DrawLine($pen, [single]($cx + 4.5), [single]($cy - 1.5), $cx, [single]($cy - 6))
    }
    $pen.Dispose()
}

function Draw-Rate($g, [single]$x, [single]$y, [bool]$down, [double]$val, $color, [string]$caption) {
    Draw-Arrow $g ($x + 8) ($y + 17) $down $color
    $txt = Format-Mbps $val
    $g.DrawString($txt, $fBig, $bText, [single]($x + 24), [single]$y, $sfTight)
    $tw = $g.MeasureString($txt, $fBig, 1000, $sfTight).Width
    $g.DrawString('Mbps', $fSmall, $bMuted, [single]($x + 28 + $tw), [single]($y + 11), $sfTight)
    $g.DrawString($caption, $fSmall, $bMuted, [single]($x + 24), [single]($y + 32), $sfTight)
}

function Draw-Rows($g, $items, [int]$x, [int]$y0, $accent, [string]$emptyMsg, [int]$w = 358) {
    $cnt = @($items).Count
    if ($cnt -eq 0) {
        $g.DrawString($emptyMsg, $fSmall, $bMuted, [single]($x + 16), [single]($y0 + 6))
        return
    }
    $mx = 0.05
    foreach ($it in $items) { if ([double]$it.m -gt $mx) { $mx = [double]$it.m } }
    $i = 0
    foreach ($it in $items) {
        $ry = $y0 + $i * 26
        $rc1 = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 16)), ([single]$ry), ([single]($w - 128)), ([single]18)
        $g.DrawString([string]$it.n, $fRow, $bText, $rc1, $sfEll)
        $rc2 = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 16 + $w - 124)), ([single]$ry), ([single]124), ([single]18)
        $g.DrawString((Format-Mbps ([double]$it.m)) + ' Mbps', $fRowV, $bMuted, $rc2, $sfRight)
        $tr = New-Object System.Drawing.SolidBrush((Get-Ov 26))
        $g.FillRectangle($tr, [single]($x + 16), [single]($ry + 20), [single]$w, [single]3)
        $tr.Dispose()
        $fw = [math]::Max(2.0, [double]$w * [double]$it.m / $mx)
        $fbr = New-Object System.Drawing.SolidBrush($accent)
        $g.FillRectangle($fbr, [single]($x + 16), [single]($ry + 20), [single]$fw, [single]3)
        $fbr.Dispose()
        $i = $i + 1
    }
}

$S.Tab = 'home'
$S.HitHead = New-Object System.Collections.ArrayList
$S.HitMain = New-Object System.Collections.ArrayList
$fDial = New-Object System.Drawing.Font('Consolas', 34, [System.Drawing.FontStyle]::Bold)
$fTitle = New-Object System.Drawing.Font($UiFont, 22, [System.Drawing.FontStyle]::Bold)
$fTab = New-Object System.Drawing.Font($UiFont, 10, [System.Drawing.FontStyle]::Bold)
$fBrand = New-Object System.Drawing.Font($UiFont, 14, [System.Drawing.FontStyle]::Bold)
$sfWrapC = New-Object System.Drawing.StringFormat
$sfWrapC.Alignment = [System.Drawing.StringAlignment]::Center
$sfWrapC.LineAlignment = [System.Drawing.StringAlignment]::Near

function Add-Hit($list, [string]$n, [int]$x, [int]$y, [int]$w, [int]$h) {
    [void]$list.Add(@{ n = $n; x = $x; y = $y; w = $w; h = $h })
}
function Find-Hit($list, [int]$x, [int]$y) {
    foreach ($h in $list) {
        if (($x -ge $h.x) -and ($x -le ($h.x + $h.w)) -and ($y -ge $h.y) -and ($y -le ($h.y + $h.h))) { return [string]$h.n }
    }
    return ''
}
function Draw-Pill($g, [string]$text, [int]$x, [int]$y, [int]$w, [int]$h, $fill, $border, $fore, $font) {
    $p = New-RoundPath $x $y $w $h ([int]($h / 2))
    if ($fill -ne $null) { $fb = New-Object System.Drawing.SolidBrush($fill); $g.FillPath($fb, $p); $fb.Dispose() }
    if ($border -ne $null) { $pn = New-Object System.Drawing.Pen($border, [single]1); $g.DrawPath($pn, $p); $pn.Dispose() }
    $tb = New-Object System.Drawing.SolidBrush($fore)
    $rc = New-Object System.Drawing.RectangleF -ArgumentList ([single]$x), ([single]$y), ([single]$w), ([single]$h)
    $g.DrawString($text, $font, $tb, $rc, $sfCenter)
    $tb.Dispose(); $p.Dispose()
}

$pnlHead = New-Object System.Windows.Forms.Panel
$pnlHead.Location = New-Object System.Drawing.Point(0, 0)
$pnlHead.Size = New-Object System.Drawing.Size(1100, 64)
$pnlHead.BackColor = $cBg
Enable-DoubleBuffer $pnlHead
$form.Controls.Add($pnlHead)
$pnlHead.Add_Paint({
    param($sender, $pe)
    try {
        $g = $pe.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $S.HitHead.Clear()
        $g.DrawString('ZERKIWATCH', $fBrand, $bText, [single]24, [single]19)
        $g.DrawString(('v' + $APPVER), $fSmall, $bMuted, [single]142, [single]24)
        $bg = New-RoundPath 230 14 264 36 18
        $bb = New-Object System.Drawing.SolidBrush($cCard); $g.FillPath($bb, $bg); $bb.Dispose()
        $bp = New-Object System.Drawing.Pen($cBorder, [single]1); $g.DrawPath($bp, $bg); $bp.Dispose(); $bg.Dispose()
        $tabs = @(@('tab_home', (T 'ui.tab_home'), 233), @('tab_perf', (T 'ui.tab_perf'), 363))
        foreach ($tb in $tabs) {
            $sel = ($S.Tab -eq ($tb[0] -replace 'tab_', ''))
            if ($sel) { Draw-Pill $g $tb[1] $tb[2] 17 128 30 $cText $null $cBg $fTab } else { Draw-Pill $g $tb[1] $tb[2] 17 128 30 $null $null $cMuted $fTab }
            Add-Hit $S.HitHead $tb[0] $tb[2] 17 128 30
        }
        $acts = @(@('test', (T 'ui.retest')), @('hist', (T 'ui.history')), @('phone', (T 'ui.iphone')), @('set', (T 'ui.settings')))
        $ax = 636
        foreach ($ac in $acts) {
            Draw-Pill $g $ac[1] $ax 15 104 34 $null $cBorder $cText $fTab
            Add-Hit $S.HitHead $ac[0] $ax 15 104 34
            $ax = $ax + 112
        }
        $lp = New-Object System.Drawing.Pen($cBorder, [single]1)
        $g.DrawLine($lp, 0, 63, 1100, 63)
        $lp.Dispose()
    } catch { Write-Log ('Head paint: ' + $_.Exception.Message) 'ph' }
})
$pnlHead.Add_MouseMove({ param($snd, $ev) if ((Find-Hit $S.HitHead $ev.X $ev.Y) -ne '') { $snd.Cursor = [System.Windows.Forms.Cursors]::Hand } else { $snd.Cursor = [System.Windows.Forms.Cursors]::Default } })
$pnlHead.Add_MouseClick({
    param($snd, $ev)
    $h = Find-Hit $S.HitHead $ev.X $ev.Y
    try {
        if ($h -eq 'tab_home') { $S.Tab = 'home'; $pnlHead.Invalidate(); $pnlRight.Invalidate() }
        elseif ($h -eq 'tab_perf') { $S.Tab = 'perf'; $pnlHead.Invalidate(); $pnlRight.Invalidate() }
        elseif ($h -eq 'test') { if (-not $S.Busy) { Invoke-Tests } }
        elseif ($h -eq 'hist') { Show-History }
        elseif ($h -eq 'phone') { Show-PinDialog }
        elseif ($h -eq 'set') { Show-Settings }
    } catch { Write-Log ('Head click: ' + $_.Exception.Message) 'hc' }
})

$pnlRight.Add_MouseMove({
    param($snd, $ev)
    $h = Find-Hit $S.HitMain $ev.X $ev.Y
    if ($h -eq 'dial') { $dx = $ev.X - 290; $dy = $ev.Y - 165; if (([math]::Sqrt($dx * $dx + $dy * $dy)) -gt 130) { $h = '' } }
    if ($h -ne '') { $snd.Cursor = [System.Windows.Forms.Cursors]::Hand } else { $snd.Cursor = [System.Windows.Forms.Cursors]::Default }
})
$pnlRight.Add_MouseClick({
    param($snd, $ev)
    $h = Find-Hit $S.HitMain $ev.X $ev.Y
    try {
        if ($h -eq 'dial') {
            $dx = $ev.X - 290; $dy = $ev.Y - 165
            if (([math]::Sqrt($dx * $dx + $dy * $dy)) -le 130) { Invoke-Toggle }
        } elseif (@('15', '30', '60', 'tomorrow', 'cancel') -contains $h) {
            $ce = Start-TimedCut $h
            if ($ce -ne '') { try { $tray.ShowBalloonTip(3500, 'ZerkiWatch', (Tf 'p.err' @($ce)), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { } }
            Update-Ui
        }
    } catch { Write-Log ('Main click: ' + $_.Exception.Message) 'mc' }
})

$pnlRight.Add_Paint({
    param($sender, $pe)
    try {
        $g = $pe.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
        $S.HitMain.Clear()
        $msg1 = (T 'ui.noact')
        $msg2 = $msg1
        if (-not $S.EtwOk) {
            $msg1 = (T 'ui.noetw')
            $msg2 = $msg1
        } elseif (($S.EtwStatus -ne '') -and ($S.EtwStatus -notlike 'ok*') -and ($S.EtwStatus -ne 'starting')) {
            $msg1 = $S.EtwStatus
            $msg2 = $S.EtwStatus
        }
        if ($S.Tab -eq 'perf') {
            Draw-NetTile $g 20 16 523 128 $true $S.Dl $S.HistDl $cDl (T 'ui.recv')
            Draw-NetTile $g 557 16 523 128 $false $S.Ul $S.HistUl $cUl (T 'ui.send')
            $nc = [Environment]::ProcessorCount
            Draw-RingTile $g 20 158 254 176 (T 'ui.cpu') $S.Cpu $aCpu 0 (T 'ui.cpu_load') (Tf 'ui.cores' @([string]$nc))
            Draw-RingTile $g 288 158 254 176 (T 'ui.ram') $S.Ram $aRam 1 ((Format-Bytes $S.RamUsed) + ' / ' + (Format-Bytes $S.RamTot)) (T 'ui.ram_used')
            $gn = [string]$S.GpuName
            if ($gn -eq '') { $gn = (T 'ui.gpu_default') }
            $gd = (T 'ui.gpu_load')
            if ($S.Gpu -lt 0) { $gd = (T 'ui.gpu_nocounter') }
            if ($S.VramTot -gt 0) { $gd = (Tf 'ui.vram' @((Format-Bytes $S.VramUsed), (Format-Bytes $S.VramTot))) }
            Draw-RingTile $g 556 158 254 176 'GPU' $S.Gpu $aGpu 2 $gn $gd
            Draw-DiskTile $g 824 158 256 176 @($S.Disks)
            Draw-Card $g 20 348 523 232 (T 'ui.apps')
            Draw-Rows $g $S.Apps 20 386 $cApp $msg1 491
            Draw-Card $g 557 348 523 232 (T 'ui.services')
            Draw-Rows $g $S.Svcs 557 386 $cSvc $msg2 491
            return
        }
        # ----- Accueil : cadran -----
        $isLocal = [bool]$S.Local
        if ($isLocal) { $ac = $cRed } else { $ac = $cGreen }
        $cx = 290; $cy = 165; $r = 118
        $tp = New-Object System.Drawing.Pen($cTrack, [single]14)
        $g.DrawEllipse($tp, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
        $tp.Dispose()
        if ($isLocal) { $sweep = 360.0 } else { $sweep = [math]::Min(360.0, ([double]$S.Dl / 100.0) * 360.0) }
        if ($sweep -gt 1) {
            $ap = New-Object System.Drawing.Pen($ac, [single]14)
            $ap.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
            $ap.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
            $g.DrawArc($ap, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r), [single]-90, [single]([math]::Min(359.0, $sweep)))
            $ap.Dispose()
        }
        $ir = 98
        $ib = New-Object System.Drawing.SolidBrush($cCard)
        $g.FillEllipse($ib, [single]($cx - $ir), [single]($cy - $ir), [single](2 * $ir), [single](2 * $ir))
        $ib.Dispose()
        $ip = New-Object System.Drawing.Pen($cBorder, [single]1)
        $g.DrawEllipse($ip, [single]($cx - $ir), [single]($cy - $ir), [single](2 * $ir), [single](2 * $ir))
        $ip.Dispose()
        $acb = New-Object System.Drawing.SolidBrush($ac)
        if ($isLocal) { $mt = (T 'bar.local') } else { $mt = (T 'bar.internet') }
        $rc1 = New-Object System.Drawing.RectangleF -ArgumentList ([single]($cx - 90)), ([single]($cy - 56)), ([single]180), ([single]22)
        $g.DrawString($mt, $fTab, $acb, $rc1, $sfCenter)
        $acb.Dispose()
        $rc2 = New-Object System.Drawing.RectangleF -ArgumentList ([single]($cx - 90)), ([single]($cy - 30)), ([single]180), ([single]56)
        $g.DrawString(([math]::Round([double]$S.Dl)).ToString('0'), $fDial, $bText, $rc2, $sfCenter)
        $rc3 = New-Object System.Drawing.RectangleF -ArgumentList ([single]($cx - 90)), ([single]($cy + 30)), ([single]180), ([single]20)
        $g.DrawString((T 'ui.mbps_in'), $fSmall, $bMuted, $rc3, $sfCenter)
        Add-Hit $S.HitMain 'dial' ($cx - $r - 6) ($cy - $r - 6) (2 * $r + 12) (2 * $r + 12)
        $tbr = New-Object System.Drawing.SolidBrush($lblStatus.ForeColor)
        $rc4 = New-Object System.Drawing.RectangleF -ArgumentList ([single]20), ([single]304), ([single]540), ([single]36)
        $g.DrawString($lblStatus.Text, $fTitle, $bText, $rc4, $sfCenter)
        $tbr.Dispose()
        $rc5 = New-Object System.Drawing.RectangleF -ArgumentList ([single]70), ([single]346), ([single]440), ([single]44)
        $g.DrawString($lblSub.Text, $fRow, $bMuted, $rc5, $sfWrapC)
        if ($S.CutUntil -ne $null) {
            $back = (Tf 'menu.cut_until' @((([DateTime]$S.CutUntil).ToLocalTime()).ToString('t')))
            $ab = New-Object System.Drawing.SolidBrush($cAmber)
            $rc6 = New-Object System.Drawing.RectangleF -ArgumentList ([single]20), ([single]398), ([single]540), ([single]22)
            $g.DrawString($back, $fRowV, $ab, $rc6, $sfCenter)
            $ab.Dispose()
            Draw-Pill $g (T 'menu.cut_cancel') 150 428 280 36 $null $cBorder $cText $fTab
            Add-Hit $S.HitMain 'cancel' 150 428 280 36
        } elseif (-not $isLocal) {
            $chips = @(@('15', (T 'menu.cut_15'), 104), @('30', (T 'menu.cut_30'), 104), @('60', (T 'menu.cut_60'), 104), @('tomorrow', (T 'menu.cut_tomorrow'), 168))
            $rc7 = New-Object System.Drawing.RectangleF -ArgumentList ([single]20), ([single]398), ([single]540), ([single]20)
            $g.DrawString((T 'ui.cut_for'), $fSmall, $bMuted, $rc7, $sfCenter)
            $px = 38
            foreach ($cp in $chips) {
                Draw-Pill $g $cp[1] $px 426 $cp[2] 36 $cCard $cBorder $cText $fTab
                Add-Hit $S.HitMain $cp[0] $px 426 $cp[2] 36
                $px = $px + $cp[2] + 8
            }
        }
        # ----- colonne de droite -----
        Draw-NetTile $g 590 16 238 120 $true $S.Dl $S.HistDl $cDl (T 'ui.recv')
        Draw-NetTile $g 842 16 238 120 $false $S.Ul $S.HistUl $cUl (T 'ui.send')
        Draw-Card $g 590 150 490 262 (T 'ui.apps')
        Draw-Rows $g $S.Apps 590 188 $cApp $msg1 458
        Draw-Card $g 590 426 490 154 (T 'ui.network')
        $nb = New-Object System.Drawing.SolidBrush($valNet.ForeColor)
        $g.DrawString('Internet', $fRowV, $bText, [single]608, [single]462)
        $rv1 = New-Object System.Drawing.RectangleF -ArgumentList ([single]740), ([single]462), ([single]322), ([single]20)
        $g.DrawString($valNet.Text, $fRowV, $nb, $rv1, $sfRight)
        $nb.Dispose()
        $bb2 = New-Object System.Drawing.SolidBrush($valBox.ForeColor)
        $g.DrawString($nameBox.Text, $fRowV, $bText, [single]608, [single]492)
        $rv2 = New-Object System.Drawing.RectangleF -ArgumentList ([single]740), ([single]492), ([single]322), ([single]20)
        $g.DrawString($valBox.Text, $fRowV, $bb2, $rv2, $sfRight)
        $bb2.Dispose()
        $rv3 = New-Object System.Drawing.RectangleF -ArgumentList ([single]608), ([single]524), ([single]454), ([single]44)
        $g.DrawString($lblMsg.Text, $fSmall, $bMuted, $rv3, $sfEll)
    } catch { Write-Log ('Window paint: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'pw' }
})

# --- Animation du bouton ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 15
$timer.Add_Tick({
    if ($S.Local) { $target = 0.0 } else { $target = 1.0 }
    $diff = $target - [double]$S.Pos
    if ([math]::Abs($diff) -lt 0.03) {
        $S.Pos = $target
        $timer.Stop()
    } else {
        $S.Pos = [double]$S.Pos + $diff * 0.25
    }
    $toggle.Invalidate()
})

# --- Mise a jour de l'affichage ---
function Update-Ui([string]$Known = '') {
    if ($Known -eq '') { $Known = Get-Mode }
    $S.Local = ($Known -eq 'LOCAL')
    if ($S.Local) {
        $lblStatus.Text = (T 'ui.local')
        $lblStatus.ForeColor = $cRed
        $lblSub.Text = (T 'ui.local_sub')
    } else {
        $lblStatus.Text = (T 'ui.on')
        $lblStatus.ForeColor = $cGreen
        $lblSub.Text = (T 'ui.on_sub')
    }
    $timer.Start()
    $toggle.Invalidate()
    try { $pnlRight.Invalidate(); $pnlHead.Invalidate() } catch { }
}

function Set-Row($Dot, $Val, $Color, [string]$Text) {
    $Dot.ForeColor = $Color
    $Val.ForeColor = $Color
    $Val.Text = $Text
}

function Invoke-Tests {
    $S.Busy = $true
    Set-Row $dotNet $valNet $cMuted (T 'ui.testing')
    Set-Row $dotBox $valBox $cMuted (T 'ui.testing')
    $lblMsg.Text = ''
    [System.Windows.Forms.Application]::DoEvents()
    $net = Test-Internet
    $box = Test-Box
    if ($S.Local) {
        if ($net) { Set-Row $dotNet $valNet $cAmber (T 'ui.accessible_bang') } else { Set-Row $dotNet $valNet $cGreen (T 'ui.blocked') }
    } else {
        if ($net) { Set-Row $dotNet $valNet $cGreen (T 'ui.accessible') } else { Set-Row $dotNet $valNet $cAmber (T 'ui.unreachable') }
    }
    if ($box) { Set-Row $dotBox $valBox $cGreen (T 'ui.box_ok') } else { Set-Row $dotBox $valBox $cMuted (T 'ui.box_noping') }

    if ($S.Local -and $net) {
        $lblMsg.ForeColor = $cAmber
        $lblMsg.Text = (T 'ui.warn_still')
    } elseif ($S.Local -and (-not $box)) {
        $lblMsg.ForeColor = $cMuted
        $lblMsg.Text = (T 'ui.blocked_nobox')
    } elseif ((-not $S.Local) -and (-not $net)) {
        $lblMsg.ForeColor = $cAmber
        $lblMsg.Text = (T 'ui.no_internet')
    } else {
        $lblMsg.ForeColor = $cGreen
        $lblMsg.Text = (T 'ui.all_ok')
    }
    $S.Busy = $false
}

function Invoke-Toggle {
    if ($S.Busy) { return }
    $S.Busy = $true
    $S.Switching = $true
    $lblStatus.Text = (T 'ui.wait')
    $lblStatus.ForeColor = $cMuted
    $toggle.Invalidate()
    [System.Windows.Forms.Application]::DoEvents()
    try {
        if ((Get-Mode) -eq 'LOCAL') { Set-ModeInternet } else { Set-ModeLocal }
        $S.Switching = $false
        $S.Busy = $false
        Update-Ui
        Invoke-Tests
    } catch {
        $S.Switching = $false
        $S.Busy = $false
        Update-Ui
        $lblMsg.ForeColor = $cRed
        $lblMsg.Text = (Tf 'ui.error' @($_.Exception.Message))
    }
    $S.Switching = $false
    $S.Busy = $false
    $toggle.Invalidate()
}

$toggle.Add_Click({ Invoke-Toggle })
$btnRetest.Add_Click({ if (-not $S.Busy) { Invoke-Tests } })
$btnHist.Add_Click({ try { Show-History } catch { Write-Log ('History: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'sh' } })
$form.Add_Shown({ Invoke-Tests })

$S.Local = ((Get-Mode) -eq 'LOCAL')
Load-CutState
if ($S.Local) { $S.Pos = 0.0 } else { $S.Pos = 1.0 }
Update-Ui

# ---------- Barre flottante (CPU, RAM, debit) ----------
$cBg1 = (Pc @(30, 32, 39) @(250, 249, 247))
$cBg2 = (Pc @(17, 18, 22) @(242, 241, 238))
$bText   = New-Object System.Drawing.SolidBrush($cText)
$bMuted  = New-Object System.Drawing.SolidBrush($cMuted)
$barBorder = (Pc @(52, 56, 66) @(205, 201, 194))
$barIconBmp = $null
try { $barIconBmp = (New-Object System.Drawing.Icon($form.Icon, 32, 32)).ToBitmap() } catch { $barIconBmp = $null }
$cMenuBg = (Pc @(25, 27, 33) @(255, 255, 255))
$cTrack = (Pc @(44, 47, 56) @(226, 223, 217))
$cLoadG = (Pc @(74, 222, 128) @(22, 163, 74))
$cLoadA = (Pc @(251, 191, 36) @(180, 83, 9))
$cLoadR = (Pc @(255, 99, 88) @(220, 38, 38))
$px = [System.Drawing.GraphicsUnit]::Pixel
$reg = [System.Drawing.FontStyle]::Regular
$fVal  = New-Object System.Drawing.Font('Segoe UI Semibold', 17, $reg, $px)
$fUnit = New-Object System.Drawing.Font('Segoe UI', 9, $reg, $px)
$fPct  = New-Object System.Drawing.Font('Segoe UI Semibold', 15, $reg, $px)
$fLbl  = New-Object System.Drawing.Font('Segoe UI Semibold', 9, $reg, $px)
$fTip  = New-Object System.Drawing.Font('Segoe UI', 9)
$sfmt  = [System.Drawing.StringFormat]::GenericTypographic

$BAR = @{ W = 650.0; H = 46.0; K = 1.0; UserScale = 1.0; Top = $true; UserHidden = $false; AutoHidden = $false; Dirty = $false; DwmRound = $false; Dragging = $false; DragX = 0; DragY = 0; Dock = $false; DockK = 1.0; FloatPt = $null; DockHide = $false }
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$cfgFile = Join-Path $cfgDir 'config.txt'
$cfg = @{}
try {
    if (Test-Path -LiteralPath $cfgFile) {
        foreach ($ln in (Get-Content -LiteralPath $cfgFile)) {
            $kv = $ln.Split('=', 2)
            if ($kv.Count -eq 2) { $cfg[$kv[0].Trim()] = $kv[1].Trim() }
        }
    }
} catch { }
if ($cfg.ContainsKey('Scale')) { try { $sv = [double]::Parse($cfg['Scale'], $inv); if ($sv -ge 0.5 -and $sv -le 2.0) { $BAR.UserScale = $sv } } catch { } }
if ($cfg.ContainsKey('Top')) { $BAR.Top = ($cfg['Top'] -eq '1') }
if ($cfg.ContainsKey('Bar')) { $BAR.UserHidden = ($cfg['Bar'] -eq '0') }
if ($cfg.ContainsKey('Dock')) { $BAR.Dock = ($cfg['Dock'] -eq '1') }
$WID = @{ On = $false; AutoHidden = $false; Dirty = $false; Dragging = $false; DragX = 0; DragY = 0 }
if ($cfg.ContainsKey('Widget')) { $WID.On = ($cfg['Widget'] -eq '1') }
# First-run wizard: shown only when there is no config at all (existing users never see it automatically)
$BAR.Items = @('mode', 'dl', 'ul', 'cpu', 'ram', 'gpu', 'dsk')
if ($cfg.ContainsKey('Items')) {
    $its = @(([string]$cfg['Items']).Split(',') | ForEach-Object { $_.Trim() } | Where-Object { @('mode', 'dl', 'ul', 'cpu', 'ram', 'gpu', 'dsk') -contains $_ })
    if ($its.Count -gt 0) { $BAR.Items = $its }
}
$S.AlertSpeed = 0
$S.AlertCut = 0
$S.UpdCheck = ($cfg.ContainsKey('UpdCheck') -and ([string]$cfg['UpdCheck'] -eq '1'))
if ($cfg.ContainsKey('AlertSpeed')) { try { $S.AlertSpeed = [math]::Max(0, [math]::Min(10000, [int]$cfg['AlertSpeed'])) } catch { } }
if ($cfg.ContainsKey('AlertCut')) { try { $S.AlertCut = [math]::Max(0, [math]::Min(1440, [int]$cfg['AlertCut'])) } catch { } }
$S.WizDone = ($cfg.ContainsKey('Wizard') -or ($cfg.Count -gt 0))
$savedWPt = $null
if ($cfg.ContainsKey('WX') -and $cfg.ContainsKey('WY')) {
    try { $savedWPt = New-Object System.Drawing.Point([int]$cfg['WX'], [int]$cfg['WY']) } catch { $savedWPt = $null }
}
$S.HkList = @(
    @{ Id = 'CtrlAltN'; Txt = 'Ctrl+Alt+N'; Mod = 3; Vk = 0x4E },
    @{ Id = 'CtrlAltI'; Txt = 'Ctrl+Alt+I'; Mod = 3; Vk = 0x49 },
    @{ Id = 'CtrlAltL'; Txt = 'Ctrl+Alt+L'; Mod = 3; Vk = 0x4C },
    @{ Id = 'CtrlShiftF9'; Txt = 'Ctrl+Shift+F9'; Mod = 6; Vk = 0x78 }
)
$S.HkOn = $true
$S.HkId = 'CtrlAltN'
if ($cfg.ContainsKey('Hotkey')) { $S.HkOn = ($cfg['Hotkey'] -ne '0') }
if ($cfg.ContainsKey('HotkeyCombo')) { $S.HkId = [string]$cfg['HotkeyCombo'] }
$S.CumulOn = $true
if ($cfg.ContainsKey('Cumul')) { $S.CumulOn = ($cfg['Cumul'] -ne '0') }
if ($cfg.ContainsKey('Disks')) {
    $S.DiskCustom = $true
    foreach ($dd in ([string]$cfg['Disks']).Split(',')) { $dd = $dd.Trim().ToUpper(); if ($dd -match '^[A-Z]:$') { [void]$S.DiskWant.Add($dd) } }
}
$savedPt = $null
if ($cfg.ContainsKey('X') -and $cfg.ContainsKey('Y')) {
    try { $savedPt = New-Object System.Drawing.Point([int]$cfg['X'], [int]$cfg['Y']) } catch { $savedPt = $null }
}

function Format-Rate([double]$v) {
    if ($v -ge 100) { return $v.ToString('0') }
    return $v.ToString('0.0')
}
function Format-Bytes([double]$v) {
    if ($v -ge 1TB) { return ($v / 1TB).ToString('0.00') + ' ' + (T 'unit.t') }
    if ($v -ge 1GB) { return ($v / 1GB).ToString('0.00') + ' ' + (T 'unit.g') }
    if ($v -ge 1MB) { return ($v / 1MB).ToString('0.0') + ' ' + (T 'unit.m') }
    return ($v / 1KB).ToString('0') + ' ' + (T 'unit.k')
}
function Get-LoadColor([double]$p) {
    if ($p -ge 85) { return $cLoadR }
    if ($p -ge 60) { return $cLoadA }
    return $cLoadG
}
function Draw-NetSeg($g, [single]$x, [bool]$down, [double]$val, $hist, $accent) {
    $badge = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(46, $accent.R, $accent.G, $accent.B))
    $g.FillEllipse($badge, $x, [single]7, [single]20, [single]20)
    $badge.Dispose()
    $pen = New-Object System.Drawing.Pen($accent, [single]1.8)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $ax = $x + 10.0
    $ay = 17.0
    $g.DrawLine($pen, [single]$ax, [single]($ay - 4.5), [single]$ax, [single]($ay + 4.5))
    if ($down) {
        $g.DrawLine($pen, [single]($ax - 3.6), [single]($ay + 0.9), [single]$ax, [single]($ay + 4.5))
        $g.DrawLine($pen, [single]($ax + 3.6), [single]($ay + 0.9), [single]$ax, [single]($ay + 4.5))
    } else {
        $g.DrawLine($pen, [single]($ax - 3.6), [single]($ay - 0.9), [single]$ax, [single]($ay - 4.5))
        $g.DrawLine($pen, [single]($ax + 3.6), [single]($ay - 0.9), [single]$ax, [single]($ay - 4.5))
    }
    $pen.Dispose()

    $txt = Format-Rate $val
    $tx = $x + 26.0
    $g.DrawString($txt, $fVal, $bText, [single]$tx, [single]3, $sfmt)
    $tw = $g.MeasureString($txt, $fVal, 1000, $sfmt).Width
    $g.DrawString('Mbps', $fUnit, $bMuted, [single]($tx + $tw + 3), [single]11, $sfmt)

    $cnt = $hist.Count
    $x0 = $x + 26.0
    $w2 = 74.0
    $y0 = 31.0
    $h2 = 11.0
    $base = New-Object System.Drawing.Pen((Get-Ov 30), [single]1)
    $g.DrawLine($base, [single]$x0, [single]($y0 + $h2 + 1), [single]($x0 + $w2), [single]($y0 + $h2 + 1))
    $base.Dispose()
    if ($cnt -ge 2) {
        $mx = 1.0
        foreach ($hv in $hist) { if ($hv -gt $mx) { $mx = $hv } }
        $step = $w2 / 39.0
        $pts = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        for ($i = 0; $i -lt $cnt; $i++) {
            $sx = $x0 + $w2 - ($cnt - 1 - $i) * $step
            $sy = $y0 + $h2 - ($hist[$i] / $mx) * $h2
            $pts.Add((New-Object System.Drawing.PointF([single]$sx, [single]$sy)))
        }
        $poly = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        $poly.AddRange($pts)
        $poly.Add((New-Object System.Drawing.PointF([single]($x0 + $w2), [single]($y0 + $h2))))
        $poly.Add((New-Object System.Drawing.PointF([single]($x0 + $w2 - ($cnt - 1) * $step), [single]($y0 + $h2))))
        $fb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(58, $accent.R, $accent.G, $accent.B))
        $g.FillPolygon($fb, $poly.ToArray())
        $fb.Dispose()
        $lp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(215, $accent.R, $accent.G, $accent.B), [single]1.4)
        $lp.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $g.DrawLines($lp, $pts.ToArray())
        $lp.Dispose()
    }
}

function Draw-Gauge($g, [single]$x, [string]$label, [double]$pct, [int]$kind, $accent) {
    $col = Get-RingColor $accent $pct
    Draw-Ring $g ($x + 16) 23 28 4 $pct $col
    Draw-Glyph $g ($x + 16) 23 $kind $col 0.72
    $g.DrawString($label, $fLbl, $bMuted, [single]($x + 38), [single]9, $sfmt)
    $g.DrawString((Format-Pct $pct), $fPct, $bText, [single]($x + 38), [single]20, $sfmt)
}


$barForm = New-Object System.Windows.Forms.Form
$barForm.FormBorderStyle = 'None'
$barForm.ShowInTaskbar = $false
$barForm.StartPosition = 'Manual'
$barForm.TopMost = $BAR.Top
$barForm.BackColor = $cBg2
$barForm.Text = (T 'bar.title')
Enable-DoubleBuffer $barForm
try { if ($form.Icon -ne $null) { $barForm.Icon = $form.Icon } } catch { }

$barForm.Add_HandleCreated({
    if ($S.Native) {
        try { [MN]::NoActivate($barForm.Handle) } catch { }
        try { if (([MN]::Round($barForm.Handle)) -eq 0) { $BAR.DwmRound = $true } } catch { }
        try { $null = [MN]::Border($barForm.Handle, 0x623A2C) } catch { }
    }
})
$null = $barForm.Handle
$barForm.Text = 'ZerkiWatch - monitor'

$BarItemOrder = @('mode', 'dl', 'ul', 'cpu', 'ram', 'gpu', 'dsk')
$BarItemW = @{ mode = 84; dl = 123; ul = 115; cpu = 90; ram = 90; gpu = 90; dsk = 108 }
function Update-BarLayout {
    $lay = New-Object System.Collections.ArrayList
    $w = 34
    foreach ($k in $BarItemOrder) {
        if (@($BAR.Items) -contains $k) { [void]$lay.Add(@{ k = $k; w = $BarItemW[$k] }); $w = $w + $BarItemW[$k] }
    }
    $BAR.Layout = $lay.ToArray()
    $BAR.W = [double]$w
}

function Set-BarSize {
    Update-BarLayout
    if ($BAR.Dock) { $BAR.K = $BAR.DockK } else { $BAR.K = $BAR.UserScale }
    $cw = [int][math]::Round($BAR.W * $BAR.K)
    $ch = [int][math]::Round($BAR.H * $BAR.K)
    $barForm.ClientSize = New-Object System.Drawing.Size($cw, $ch)
    if (-not $BAR.DwmRound) {
        try { $barForm.Region = New-Object System.Drawing.Region((New-RoundPath 0 0 $cw $ch ([int](10 * $BAR.K)))) } catch { }
    }
    $barForm.Invalidate()
}
function Set-BarDefaultPos {
    $scr = [System.Windows.Forms.Screen]::PrimaryScreen
    $bd = $scr.Bounds
    $wa = $scr.WorkingArea
    $tbh = $bd.Bottom - $wa.Bottom
    if ($tbh -gt 0) { $py = $wa.Bottom + [int](($tbh - $barForm.Height) / 2) } else { $py = $wa.Bottom - $barForm.Height - 12 }
    $pxx = $wa.Right - $barForm.Width - 240
    if ($pxx -lt $wa.Left) { $pxx = $wa.Left + 10 }
    $barForm.Location = New-Object System.Drawing.Point($pxx, $py)
}
function Save-BarConfig {
    try {
        if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        $barOn = 1
        if ($BAR.UserHidden) { $barOn = 0 }
        $sx = $barForm.Location.X
        $sy = $barForm.Location.Y
        if ($BAR.Dock -and ($BAR.FloatPt -ne $null)) { $sx = $BAR.FloatPt.X; $sy = $BAR.FloatPt.Y }
        $lines = @(
            ('X=' + $sx),
            ('Y=' + $sy),
            ('Scale=' + $BAR.UserScale.ToString($inv)),
            ('Top=' + [int]$BAR.Top),
            ('Bar=' + $barOn),
            ('Dock=' + [int]$BAR.Dock),
            ('Widget=' + [int]$WID.On),
            ('Wizard=' + [int]($S.WizDone -eq $true)),
            ('Items=' + ((@($BAR.Items)) -join ',')),
            ('Theme=' + $ThemePref),
            ('UpdCheck=' + $(if ($S.UpdCheck) { '1' } else { '0' })),
            ('AlertSpeed=' + [int]$S.AlertSpeed),
            ('AlertCut=' + [int]$S.AlertCut),
            ('Cumul=' + [int]$S.CumulOn),
            ('Hotkey=' + [int]$S.HkOn),
            ('HotkeyCombo=' + $S.HkId)
        )
        try { $lines = $lines + ('WX=' + $wForm.Location.X) + ('WY=' + $wForm.Location.Y) } catch { }
        if ($LangPref -ne '') { $lines = $lines + ('Lang=' + $LangPref) }
        if ($S.DiskCustom) { $lines = $lines + ('Disks=' + (($S.DiskWant.ToArray()) -join ',')) }
        Set-Content -LiteralPath $cfgFile -Value $lines -Encoding ASCII
    } catch { }
}
function Set-BarScale([double]$v) {
    $mx = $barForm.Left + $barForm.Width / 2.0
    $my = $barForm.Top + $barForm.Height / 2.0
    $BAR.UserScale = $v
    Set-BarSize
    $barForm.Location = New-Object System.Drawing.Point([int]($mx - $barForm.Width / 2.0), [int]($my - $barForm.Height / 2.0))
    try { Set-WidgetSize } catch { }
    Save-BarConfig
}

Set-BarSize
$okPos = $false
if ($savedPt -ne $null) {
    $brc = New-Object System.Drawing.Rectangle($savedPt.X, $savedPt.Y, $barForm.Width, $barForm.Height)
    foreach ($sc in [System.Windows.Forms.Screen]::AllScreens) {
        $ix = [System.Drawing.Rectangle]::Intersect($brc, $sc.Bounds)
        if (($ix.Width -ge 60) -and ($ix.Height -ge 20)) { $okPos = $true }
    }
}
if ($okPos) { $barForm.Location = $savedPt } else {
    if ($savedPt -ne $null) { Write-Log ('Saved position off-screen (' + $savedPt.X + ',' + $savedPt.Y + ') : reset to default') }
    Set-BarDefaultPos
}
if ($BAR.Dock) { $BAR.FloatPt = $barForm.Location }

# Disposition de la barre : les indicateurs choisis ($BAR.Items) dans l'ordre fixe ci-dessous ; $BAR.W en decoule.
function Get-ToggleW {
    if (@($BAR.Items) -contains 'mode') { return (34 + $BarItemW['mode']) }
    return 34
}
# Dessin commun a la barre et au widget libre ($k = echelle)
function Draw-Bar($g, [double]$k) {
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $g.ScaleTransform([single]$k, [single]$k)
        $rc = New-Object System.Drawing.RectangleF -ArgumentList ([single]-2), ([single]-2), ([single]($BAR.W + 4)), ([single]($BAR.H + 4))
        $bgb = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $rc, $cBg1, $cBg2, ([single]90)
        $g.FillRectangle($bgb, $rc)
        $bgb.Dispose()
        $sepPen = New-Object System.Drawing.Pen((Get-Ov 34), [single]1)
        $sepPen.Dispose()
        $bp = New-Object System.Drawing.Pen($barBorder, [single]1)
        $g.DrawRectangle($bp, [single]0, [single]0, [single]($BAR.W - 1), [single]($BAR.H - 1))
        $bp.Dispose()
        $lr = New-Object System.Drawing.RectangleF -ArgumentList ([single]14), ([single]($BAR.H - 3)), ([single]($BAR.W - 28)), ([single]2)
        if ($S.Local) { $lcol = $cLoadR } else { $lcol = $cLoadG }
        $lb = New-Object System.Drawing.SolidBrush($lcol)
        $g.FillRectangle($lb, $lr)
        $lb.Dispose()
        if ($barIconBmp -ne $null) { $g.DrawImage($barIconBmp, [single]10, [single]11, [single]24, [single]24) }
        $md = $cLoadG
        if ($S.Local) { $md = $cLoadR }
        $db = New-Object System.Drawing.SolidBrush($md)
        $dp = New-Object System.Drawing.Pen($cBg2, [single]1.5)
        $g.FillEllipse($db, [single]26, [single]27, [single]9, [single]9)
        $g.DrawEllipse($dp, [single]26, [single]27, [single]9, [single]9)
        $db.Dispose(); $dp.Dispose()
        $g.TranslateTransform([single]34, [single]0)
        $sepPen = New-Object System.Drawing.Pen((Get-Ov 34), [single]1)
        $sx = 0
        foreach ($seg in @($BAR.Layout)) {
            if ($sx -gt 0) { $g.DrawLine($sepPen, [single]$sx, [single]10, [single]$sx, [single]36) }
            switch ([string]$seg.k) {
                'mode' {
                    $mw = (T 'bar.internet'); $mc = $cLoadG
                    if ($S.Local) { $mw = (T 'bar.local'); $mc = $cLoadR }
                    $mb = New-Object System.Drawing.SolidBrush($mc)
                    $g.DrawString($mw, $fLbl, $mb, [single]($sx + 8), [single]($BAR.H / 2 - 9), $sfmt)
                    $mb.Dispose()
                }
                'dl' { Draw-NetSeg $g ($sx + 14) $true $S.Dl $S.HistDl $cDl }
                'ul' { Draw-NetSeg $g ($sx + 6) $false $S.Ul $S.HistUl $cUl }
                'cpu' { Draw-Gauge $g ($sx + 10) 'CPU' $S.Cpu 0 $aCpu }
                'ram' { Draw-Gauge $g ($sx + 10) 'RAM' $S.Ram 1 $aRam }
                'gpu' { Draw-Gauge $g ($sx + 10) 'GPU' $S.Gpu 2 $aGpu }
                'dsk' {
                    $dpc = -1.0
                    $dlab = 'DSK'
                    if (@($S.Disks).Count -gt 0) { $d0 = @($S.Disks)[0]; $dpc = [double]$d0.Pct; $dlab = [string]$d0.L }
                    Draw-Gauge $g ($sx + 10) $dlab $dpc 3 $aDsk
                }
            }
            $sx = $sx + [int]$seg.w
        }
        $sepPen.Dispose()
    } catch { Write-Log ('Bar paint: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'pb' }
}
$barForm.Add_Paint({ param($sender, $pe) Draw-Bar $pe.Graphics $BAR.K })

$barForm.Add_MouseDown({
    param($sender, $me)
    if ($me.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ($me.X -lt ((Get-ToggleW) * $BAR.K)) { Invoke-Toggle; return }
        if ($BAR.Dock) { return }
        if ($S.Native) { try { [MN]::Drag($barForm.Handle) } catch { } }
        else { $BAR.Dragging = $true; $BAR.DragX = $me.X; $BAR.DragY = $me.Y }
    }
})
$barForm.Add_MouseMove({
    param($sender, $me)
    if ((-not $S.Native) -and $BAR.Dragging) {
        $cp = [System.Windows.Forms.Cursor]::Position
        $barForm.Location = New-Object System.Drawing.Point(($cp.X - $BAR.DragX), ($cp.Y - $BAR.DragY))
    }
})
$barForm.Add_MouseUp({ $BAR.Dragging = $false })
$barForm.Add_MouseDoubleClick({ Show-Main })
$barForm.Add_LocationChanged({ $BAR.Dirty = $true })

# ---------- Widget libre sur le bureau (en plus de la barre) : reutilise Draw-Bar ----------
$wForm = New-Object System.Windows.Forms.Form
$wForm.FormBorderStyle = 'None'
$wForm.ShowInTaskbar = $false
$wForm.StartPosition = 'Manual'
$wForm.TopMost = $BAR.Top
$wForm.BackColor = $cBg2
$wForm.Text = 'ZerkiWatch - widget'
Enable-DoubleBuffer $wForm
try { if ($form.Icon -ne $null) { $wForm.Icon = $form.Icon } } catch { }
$wForm.Add_HandleCreated({
    if ($S.Native) {
        try { [MN]::NoActivate($wForm.Handle) } catch { }
        try { [void][MN]::Round($wForm.Handle) } catch { }
        try { $null = [MN]::Border($wForm.Handle, 0x623A2C) } catch { }
    }
})
$null = $wForm.Handle
function Set-WidgetSize {
    Update-BarLayout
    $cw = [int][math]::Round($BAR.W * $BAR.UserScale)
    $ch = [int][math]::Round($BAR.H * $BAR.UserScale)
    $wForm.ClientSize = New-Object System.Drawing.Size($cw, $ch)
    if (-not $BAR.DwmRound) {
        try { $wForm.Region = New-Object System.Drawing.Region((New-RoundPath 0 0 $cw $ch ([int](10 * $BAR.UserScale)))) } catch { }
    }
    $wForm.Invalidate()
}
function Set-WidgetDefaultPos {
    $wa = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $px = $wa.Right - $wForm.Width - 40
    if ($px -lt $wa.Left) { $px = $wa.Left + 10 }
    $wForm.Location = New-Object System.Drawing.Point($px, ($wa.Top + 60))
}
Set-WidgetSize
$okW = $false
if ($savedWPt -ne $null) {
    $wrc = New-Object System.Drawing.Rectangle($savedWPt.X, $savedWPt.Y, $wForm.Width, $wForm.Height)
    foreach ($sc in [System.Windows.Forms.Screen]::AllScreens) {
        $ixw = [System.Drawing.Rectangle]::Intersect($wrc, $sc.Bounds)
        if (($ixw.Width -ge 60) -and ($ixw.Height -ge 20)) { $okW = $true }
    }
}
if ($okW) { $wForm.Location = $savedWPt } else { Set-WidgetDefaultPos }
$wForm.Add_Paint({ param($sender, $pe) Draw-Bar $pe.Graphics $BAR.UserScale })
$wForm.Add_MouseDown({
    param($sender, $me)
    if ($me.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        if ($me.X -lt ((Get-ToggleW) * $BAR.UserScale)) { Invoke-Toggle; return }
        if ($S.Native) { try { [MN]::Drag($wForm.Handle) } catch { } }
        else { $WID.Dragging = $true; $WID.DragX = $me.X; $WID.DragY = $me.Y }
    }
})
$wForm.Add_MouseMove({
    param($sender, $me)
    if ((-not $S.Native) -and $WID.Dragging) {
        $cp = [System.Windows.Forms.Cursor]::Position
        $wForm.Location = New-Object System.Drawing.Point(($cp.X - $WID.DragX), ($cp.Y - $WID.DragY))
    }
})
$wForm.Add_MouseUp({ $WID.Dragging = $false })
$wForm.Add_MouseDoubleClick({ Show-Main })
$wForm.Add_LocationChanged({ $WID.Dirty = $true })
function Update-Widget {
    if (-not $WID.On) { return }
    if ($S.Native) {
        try {
            $fs = [MN]::FullScreen()
            if ($fs -and (-not $WID.AutoHidden)) { $WID.AutoHidden = $true; if ($wForm.Visible) { $wForm.Hide() } }
            elseif ((-not $fs) -and $WID.AutoHidden) { $WID.AutoHidden = $false; $wForm.Show() }
            if ($BAR.Top -and $wForm.Visible) { [MN]::KeepTop($wForm.Handle) }
        } catch { }
    }
    if ($WID.Dirty) { $WID.Dirty = $false; Save-BarConfig }
    if ($wForm.Visible) { $wForm.Invalidate() }
}
function Set-BarItems([string[]]$items) {
    if (@($items).Count -eq 0) { return }
    $BAR.Items = @($items)
    $mx = $barForm.Left + $barForm.Width / 2.0
    $my = $barForm.Top + $barForm.Height / 2.0
    Set-BarSize
    if (-not $BAR.Dock) { $barForm.Location = New-Object System.Drawing.Point([int]($mx - $barForm.Width / 2.0), [int]($my - $barForm.Height / 2.0)) }
    $wx = $wForm.Left + $wForm.Width / 2.0
    $wy = $wForm.Top + $wForm.Height / 2.0
    Set-WidgetSize
    $wForm.Location = New-Object System.Drawing.Point([int]($wx - $wForm.Width / 2.0), [int]($wy - $wForm.Height / 2.0))
    Save-BarConfig
}
function Switch-Widget {
    if ($WID.On) { $WID.On = $false; $wForm.Hide() }
    else { $WID.On = $true; if (-not $WID.AutoHidden) { $wForm.Show() } }
    Save-BarConfig
}

# ---------- Integration a la barre des taches ----------
function Update-Dock {
    if ((-not $BAR.Dock) -or (-not $S.Native)) { return }
    try {
        $ti = [MN]::TaskbarInfo()
        if ($ti -eq $null) { return }
        $tl = [int]$ti[0]
        $tt = [int]$ti[1]
        $trr = [int]$ti[2]
        $tbm = [int]$ti[3]
        $nl = [int]$ti[4]
        $tw = $trr - $tl
        $th = $tbm - $tt
        if ($th -gt $tw) { return }
        $scr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $vis = [math]::Min($tbm, $scr.Bottom) - [math]::Max($tt, $scr.Top)
        if ($vis -lt ($th * 0.5)) {
            if ($barForm.Visible) { $barForm.Hide(); $BAR.DockHide = $true }
            return
        }
        if ($BAR.DockHide) {
            $BAR.DockHide = $false
            if ((-not $BAR.UserHidden) -and (-not $BAR.AutoHidden)) { $barForm.Show() }
        }
        $k = ($th - 8) / $BAR.H
        if ($k -lt 0.6) { $k = 0.6 }
        if ($k -gt 1.3) { $k = 1.3 }
        if ([math]::Abs($k - $BAR.DockK) -gt 0.005) { $BAR.DockK = $k; Set-BarSize }
        if ($nl -lt 0) { $nl = $trr - 260 }
        $x = $nl - $barForm.Width - 8
        if ($x -lt ($tl + 4)) { $x = $tl + 4 }
        $y = $tt + [int](($th - $barForm.Height) / 2)
        if (($barForm.Left -ne $x) -or ($barForm.Top -ne $y)) { $barForm.Location = New-Object System.Drawing.Point($x, $y) }
        if ($barForm.Visible) { [MN]::KeepTop($barForm.Handle) }
    } catch { Write-Log ('Docked bar: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'dk' }
}
$dockTimer = New-Object System.Windows.Forms.Timer
$dockTimer.Interval = 700
$dockTimer.Add_Tick({ try { Update-Dock } catch { } })
if ($BAR.Dock) { $dockTimer.Start() }


$barTip = New-Object System.Windows.Forms.ToolTip
$barTip.InitialDelay = 350
$barTip.AutoPopDelay = 30000
$barTip.OwnerDraw = $true
$barTip.Add_Popup({
    param($sender, $pe)
    try {
        $tsz = [System.Windows.Forms.TextRenderer]::MeasureText($barTip.GetToolTip($barForm), $fTip)
        $pe.ToolTipSize = New-Object System.Drawing.Size(($tsz.Width + 24), ($tsz.Height + 18))
    } catch { }
})
$barTip.Add_Draw({
    param($sender, $de)
    try {
        $tb = New-Object System.Drawing.SolidBrush($cMenuBg)
        $de.Graphics.FillRectangle($tb, $de.Bounds)
        $tb.Dispose()
        $tpen = New-Object System.Drawing.Pen($barBorder)
        $de.Graphics.DrawRectangle($tpen, 0, 0, ($de.Bounds.Width - 1), ($de.Bounds.Height - 1))
        $tpen.Dispose()
        [System.Windows.Forms.TextRenderer]::DrawText($de.Graphics, $de.ToolTipText, $fTip, (New-Object System.Drawing.Point(12, 9)), $cText)
    } catch { }
})

# ---------- Icone pres de l'horloge et menu ----------
if ($themed -and (-not $ThemeLight)) {
    try {
        $rend = New-Object System.Windows.Forms.ToolStripProfessionalRenderer((New-Object DarkColors))
        $rend.RoundedEdges = $false
        [System.Windows.Forms.ToolStripManager]::Renderer = $rend
    } catch { }
}
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.ShowImageMargin = $false
$menu.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$menu.BackColor = $cMenuBg
$menu.ForeColor = $cText

$miOpen  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.open'))
$miNet   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.cut'))
$miHist  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.history'))
$miCut   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.cut_timed'))
$miCutC  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.cut_cancel'))
foreach ($cq in @(@('15', 'menu.cut_15'), @('30', 'menu.cut_30'), @('60', 'menu.cut_60'), @('tomorrow', 'menu.cut_tomorrow'))) {
    $ci = New-Object System.Windows.Forms.ToolStripMenuItem((T $cq[1]))
    $ci.Tag = [string]$cq[0]
    $ci.ForeColor = $cText; $ci.BackColor = $cMenuBg
    $ci.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
    $ci.Add_Click({ param($snd, $ea) $ce = Start-TimedCut ([string]$snd.Tag); if ($ce -ne '') { try { $tray.ShowBalloonTip(3500, 'ZerkiWatch', (Tf 'p.err' @($ce)), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { } } })
    [void]$miCut.DropDownItems.Add($ci)
}
$miCutC.Tag = 'cancel'
$miCutC.ForeColor = $cText; $miCutC.BackColor = $cMenuBg
$miCutC.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
$miCutC.Add_Click({ [void](Start-TimedCut 'cancel') })
[void]$miCut.DropDownItems.Add($miCutC)
try { $miCut.DropDown.BackColor = $cMenuBg; $miCut.DropDown.ShowImageMargin = $false } catch { }
$miBar   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.bar'))
$miWid   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.widget'))
$miItems = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.items'))
$miItemList = @{}
foreach ($iq in @(@('mode', 'items.mode'), @('dl', 'items.dl'), @('ul', 'items.ul'), @('cpu', 'items.cpu'), @('ram', 'items.ram'), @('gpu', 'items.gpu'), @('dsk', 'items.dsk'))) {
    $ii = New-Object System.Windows.Forms.ToolStripMenuItem((T $iq[1]))
    $ii.Tag = [string]$iq[0]
    $ii.ForeColor = $cText; $ii.BackColor = $cMenuBg
    $ii.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
    $ii.Add_Click({
        param($snd, $ea)
        $kk = [string]$snd.Tag
        $cur = @($BAR.Items)
        if ($cur -contains $kk) { $nw = @($cur | Where-Object { $_ -ne $kk }) } else { $nw = $cur + $kk }
        Set-BarItems $nw
    })
    [void]$miItems.DropDownItems.Add($ii)
    $miItemList[[string]$iq[0]] = $ii
}
[void]$miItems.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
foreach ($pq in @(@('mini', 'items.mini'), @('full', 'items.full'))) {
    $ip = New-Object System.Windows.Forms.ToolStripMenuItem((T $pq[1]))
    $ip.Tag = [string]$pq[0]
    $ip.ForeColor = $cText; $ip.BackColor = $cMenuBg
    $ip.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
    $ip.Add_Click({
        param($snd, $ea)
        if ([string]$snd.Tag -eq 'mini') { Set-BarItems @('mode', 'dl', 'ul') } else { Set-BarItems @('mode', 'dl', 'ul', 'cpu', 'ram', 'gpu', 'dsk') }
    })
    [void]$miItems.DropDownItems.Add($ip)
}
try { $miItems.DropDown.BackColor = $cMenuBg; $miItems.DropDown.ShowImageMargin = $false } catch { }
$miTop   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.top'))
$miDock  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.dock'))
$miSize  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.size'))
$miS1    = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.small'))
$miS2    = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.normal'))
$miS3    = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.big'))
$miReset = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.reset'))
$miDisks = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.disks'))
$miAuto  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.auto'))
$miCumul = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.cumul'))
$miHot = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.hotkey'))
$miLang  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.language'))
$miWiz   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.wizard'))
$miSet   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.settings'))
$miPhone = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.iphone'))
$miLog   = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.log'))
$miQuit  = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.quit'))
$null = $miSize.DropDownItems.Add($miS1)
$null = $miSize.DropDownItems.Add($miS2)
$null = $miSize.DropDownItems.Add($miS3)
$null = $menu.Items.Add($miOpen)
$null = $menu.Items.Add($miHist)
$null = $menu.Items.Add($miNet)
$null = $menu.Items.Add($miCut)
$null = $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$null = $menu.Items.Add($miBar)
$null = $menu.Items.Add($miWid)
$null = $menu.Items.Add($miItems)
$null = $menu.Items.Add($miTop)
$null = $menu.Items.Add($miDock)
$null = $menu.Items.Add($miSize)
$null = $menu.Items.Add($miReset)
$null = $menu.Items.Add($miDisks)
$null = $menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$null = $menu.Items.Add($miCumul)
$null = $menu.Items.Add($miHot)
$null = $menu.Items.Add($miPhone)
$null = $menu.Items.Add($miSet)
$null = $menu.Items.Add($miLang)
$null = $menu.Items.Add($miWiz)
$null = $menu.Items.Add($miAuto)
$null = $menu.Items.Add($miLog)
$null = $menu.Items.Add($miQuit)
foreach ($it in @($miOpen, $miHist, $miNet, $miCut, $miBar, $miWid, $miItems, $miTop, $miDock, $miSize, $miDisks, $miS1, $miS2, $miS3, $miReset, $miCumul, $miHot, $miPhone, $miSet, $miLang, $miWiz, $miAuto, $miLog, $miQuit)) {
    $it.ForeColor = $cText
    $it.BackColor = $cMenuBg
    $it.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
}
try { $miSize.DropDown.BackColor = $cMenuBg; $miSize.DropDown.ShowImageMargin = $false } catch { }
try { $miDisks.DropDown.BackColor = $cMenuBg; $miDisks.DropDown.ShowImageMargin = $false } catch { }
try { $miHot.DropDown.BackColor = $cMenuBg; $miHot.DropDown.ShowImageMargin = $false } catch { }
try { $miLang.DropDown.BackColor = $cMenuBg; $miLang.DropDown.ShowImageMargin = $false } catch { }

function Test-Autostart {
    try { return ((Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\Tasks\ZerkiWatch')) -or (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\Tasks\ModeReseau'))) } catch { return $false }
}
function Get-SelfTarget {
    if ($env:SELF) { return $env:SELF }
    return [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}
function Set-Autostart([bool]$on) {
    try {
        if ($on) {
            $target = Get-SelfTarget
            try { Unblock-File -LiteralPath $target -ErrorAction SilentlyContinue } catch { }
            if ($env:SELF) { $act = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c "' + $target + '" tray') }
            else { $act = New-ScheduledTaskAction -Execute $target -Argument 'tray' }
            $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $trig = New-ScheduledTaskTrigger -AtLogOn -User $user
            try { $trig.Delay = 'PT15S' } catch { }
            $prin = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
            $setg = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Seconds 0) -StartWhenAvailable
            Unregister-ScheduledTask -TaskName 'ModeReseau' -Confirm:$false -ErrorAction SilentlyContinue
            Register-ScheduledTask -TaskName 'ZerkiWatch' -Action $act -Trigger $trig -Principal $prin -Settings $setg -Force | Out-Null
        } else {
            Unregister-ScheduledTask -TaskName 'ZerkiWatch' -Confirm:$false -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskName 'ModeReseau' -Confirm:$false -ErrorAction SilentlyContinue
        }
    } catch {
        try { $tray.ShowBalloonTip(4000, 'ZerkiWatch', (Tf 'bal.autostart_fail' @($_.Exception.Message)), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { }
    }
}
function Show-Main {
    try {
        $form.Show()
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) { $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal }
        $form.Activate()
        $form.BringToFront()
    } catch { }
}
function Set-Dock([bool]$on) {
    if ($on) {
        if (-not $S.Native) {
            try { $tray.ShowBalloonTip(4000, 'ZerkiWatch', (T 'bal.dock_na'), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { }
            return
        }
        $ti = $null
        try { $ti = [MN]::TaskbarInfo() } catch { }
        if (($ti -eq $null) -or (([int]$ti[3] - [int]$ti[1]) -gt ([int]$ti[2] - [int]$ti[0]))) {
            try { $tray.ShowBalloonTip(5000, 'ZerkiWatch', (T 'bal.dock_notaskbar'), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { }
            return
        }
        $BAR.FloatPt = $barForm.Location
        $BAR.Dock = $true
        $barForm.TopMost = $true
        Set-BarSize
        Update-Dock
        $dockTimer.Start()
    } else {
        $BAR.Dock = $false
        $dockTimer.Stop()
        $barForm.TopMost = $BAR.Top
        Set-BarSize
        if ($BAR.FloatPt -ne $null) { $barForm.Location = $BAR.FloatPt } else { Set-BarDefaultPos }
        if ($BAR.DockHide) {
            $BAR.DockHide = $false
            if ((-not $BAR.UserHidden) -and (-not $BAR.AutoHidden)) { $barForm.Show() }
        }
    }
    Save-BarConfig
}
function Switch-Bar {
    if ($BAR.UserHidden) { $BAR.UserHidden = $false; if (-not $BAR.AutoHidden) { $barForm.Show() } }
    else { $BAR.UserHidden = $true; $barForm.Hide() }
    Save-BarConfig
}
function Quit-App {
    $S.Quitting = $true
    try { $tray.Visible = $false } catch { }
    try { $barForm.Hide(); $wForm.Hide(); $form.Hide() } catch { }
    [System.Windows.Forms.Application]::Exit()
}
function Update-MenuText {
    if ($S.Local) { $miNet.Text = (T 'menu.restore') } else { $miNet.Text = (T 'menu.cut') }
    if ($S.CutUntil -ne $null) { $miCut.Text = (Tf 'menu.cut_until' @((([DateTime]$S.CutUntil).ToLocalTime()).ToString('t'))); $miCutC.Visible = $true }
    else { $miCut.Text = (T 'menu.cut_timed'); $miCutC.Visible = $false }
    $b1 = $dotOn; if ($BAR.UserHidden) { $b1 = $dotOff }
    $miBar.Text = $b1 + '  ' + (T 'menu.bar_full')
    foreach ($ik in @($miItemList.Keys)) { $im = $dotOff; if (@($BAR.Items) -contains $ik) { $im = $dotOn }; $miItemList[$ik].Text = $im + '  ' + (T ('items.' + $ik)) }
    $w1 = $dotOff; if ($WID.On) { $w1 = $dotOn }
    $miWid.Text = $w1 + '  ' + (T 'menu.widget')
    $t1 = $dotOff; if ($BAR.Top) { $t1 = $dotOn }
    $miTop.Text = $t1 + '  ' + (T 'menu.top')
    $d1 = $dotOff; if ($BAR.Dock) { $d1 = $dotOn }
    $miDock.Text = $d1 + '  ' + (T 'menu.dock')
    $a1 = $dotOff; if (Test-Autostart) { $a1 = $dotOn }
    $miAuto.Text = $a1 + '  ' + (T 'menu.auto')
    $c1 = $dotOff; if ($S.CumulOn) { $c1 = $dotOn }
    $miCumul.Text = $c1 + '  ' + (T 'menu.cumul')
    $o1 = $dotOff; $o2 = $dotOff; $o3 = $dotOff
    if ([math]::Abs($BAR.UserScale - 0.85) -lt 0.01) { $o1 = $dotOn }
    elseif ([math]::Abs($BAR.UserScale - 1.25) -lt 0.01) { $o3 = $dotOn }
    else { $o2 = $dotOn }
    $miS1.Text = $o1 + '  ' + (T 'menu.small')
    $miS2.Text = $o2 + '  ' + (T 'menu.normal')
    $miS3.Text = $o3 + '  ' + (T 'menu.big')
}
function Switch-Disk([string]$letter) {
    if ($S.DiskWant.Contains($letter)) { $S.DiskWant.Remove($letter) } else { [void]$S.DiskWant.Add($letter) }
    $S.DiskCustom = $true
    Save-BarConfig
    try { $barForm.Invalidate(); $wForm.Invalidate() } catch { }
}
function Update-DiskMenu {
    $miDisks.DropDownItems.Clear()
    $any = $false
    foreach ($e in @($S.AllDrives)) {
        $pp = ([string]$e).Split('|')
        if ($pp.Count -lt 4) { continue }
        $any = $true
        $tot = 0.0
        try { $tot = [double]$pp[3] } catch { }
        $nm = $pp[1]
        if ($nm -eq '') { if ($pp[2] -eq 'Removable') { $nm = (T 'menu.removable') } else { $nm = (T 'menu.disk') } }
        $mark = $dotOff
        if ($S.DiskWant.Contains($pp[0])) { $mark = $dotOn }
        $it2 = New-Object System.Windows.Forms.ToolStripMenuItem($mark + '  ' + $pp[0] + ' ' + $nm + ' (' + (Format-Bytes $tot) + ')')
        $it2.Tag = $pp[0]
        $it2.ForeColor = $cText
        $it2.BackColor = $cMenuBg
        $it2.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
        $it2.Add_Click({ param($snd, $ea) Switch-Disk ([string]$snd.Tag) })
        [void]$miDisks.DropDownItems.Add($it2)
    }
    if (-not $any) {
        $it3 = New-Object System.Windows.Forms.ToolStripMenuItem((T 'menu.nodisks'))
        $it3.Enabled = $false
        $it3.ForeColor = $cMuted
        $it3.BackColor = $cMenuBg
        [void]$miDisks.DropDownItems.Add($it3)
    }
}
function Get-HkEntry {
    $e = $null
    foreach ($h in $S.HkList) { if ($h.Id -eq $S.HkId) { $e = $h } }
    if ($e -eq $null) { $e = $S.HkList[0]; $S.HkId = $e.Id }
    return $e
}
function Apply-Hotkey {
    if ((-not $S.HkOk) -or ($S.HkWin -eq $null)) { return }
    try {
        $S.HkWin.Unregister()
        if (-not $S.HkOn) { return }
        $e = Get-HkEntry
        $ok = $S.HkWin.Register([uint32]$e.Mod, [uint32]$e.Vk)
        if (-not $ok) {
            Write-Log ('Hotkey ' + $e.Txt + ' unavailable (already used by another program)')
            try { $tray.ShowBalloonTip(5000, 'ZerkiWatch', (Tf 'bal.hk_used' @($e.Txt)), [System.Windows.Forms.ToolTipIcon]::Warning) } catch { }
        }
    } catch { Write-Log ('Hotkey: ' + $_.Exception.Message) 'hk' }
}
function Invoke-HotkeyToggle {
    if ($S.Busy) {
        try { $tray.ShowBalloonTip(2500, 'ZerkiWatch', (T 'bal.busy'), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
        return
    }
    Invoke-Toggle
    $msg = (T 'bal.restored')
    if ((Get-Mode) -eq 'LOCAL') { $msg = (T 'bal.cut') }
    try { $tray.ShowBalloonTip(2500, 'ZerkiWatch', $msg, [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
}
function Set-HotCombo([string]$id) {
    $S.HkId = $id
    $S.HkOn = $true
    Save-BarConfig
    Apply-Hotkey
}
function Update-HotMenu {
    $e = Get-HkEntry
    if ($S.HkOn) { $miHot.Text = (Tf 'menu.hotkey_cur' @($e.Txt)) } else { $miHot.Text = (T 'menu.hotkey_off') }
    $miHot.DropDownItems.Clear()
    $m0 = $dotOff; if ($S.HkOn) { $m0 = $dotOn }
    $i0 = New-Object System.Windows.Forms.ToolStripMenuItem($m0 + '  ' + (T 'menu.hotkey_enable'))
    $i0.ForeColor = $cText
    $i0.BackColor = $cMenuBg
    $i0.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
    if (-not $S.HkOk) { $i0.Enabled = $false }
    $i0.Add_Click({ $S.HkOn = (-not $S.HkOn); Save-BarConfig; Apply-Hotkey })
    [void]$miHot.DropDownItems.Add($i0)
    [void]$miHot.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    foreach ($h in $S.HkList) {
        $mk = $dotOff; if (($h.Id -eq $S.HkId) -and $S.HkOn) { $mk = $dotOn }
        $ih = New-Object System.Windows.Forms.ToolStripMenuItem($mk + '  ' + $h.Txt)
        $ih.Tag = [string]$h.Id
        $ih.ForeColor = $cText
        $ih.BackColor = $cMenuBg
        $ih.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
        if (-not $S.HkOk) { $ih.Enabled = $false }
        $ih.Add_Click({ param($snd, $ea) Set-HotCombo ([string]$snd.Tag) })
        [void]$miHot.DropDownItems.Add($ih)
    }
}
function Restart-App {
    try {
        $target = Get-SelfTarget
        $null = Start-Process -FilePath 'cmd.exe' -ArgumentList ('/c ping -n 4 127.0.0.1 >nul & "' + $target + '" tray') -WindowStyle Hidden
    } catch { return }
    Quit-App
}
function Set-Language([string]$code) {
    $script:LangPref = $code
    Save-BarConfig
    try { $tray.ShowBalloonTip(2500, 'ZerkiWatch', (T 'bal.lang_restart'), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
    Restart-App
}
function Update-LangMenu {
    $miLang.DropDownItems.Clear()
    $mk = $dotOff; if ($LangPref -eq '') { $mk = $dotOn }
    $ia = New-Object System.Windows.Forms.ToolStripMenuItem($mk + '  ' + (T 'menu.lang_auto'))
    $ia.Tag = ''
    $ia.ForeColor = $cText; $ia.BackColor = $cMenuBg
    $ia.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
    $ia.Add_Click({ param($snd, $ea) Set-Language ([string]$snd.Tag) })
    [void]$miLang.DropDownItems.Add($ia)
    foreach ($lc in @($LangDb.Keys | Sort-Object)) {
        $nm = $lc
        if ($LangDb[$lc].ContainsKey('lang.name')) { $nm = [string]$LangDb[$lc]['lang.name'] }
        $mk = $dotOff; if ($LangPref -eq $lc) { $mk = $dotOn }
        $il = New-Object System.Windows.Forms.ToolStripMenuItem($mk + '  ' + $nm)
        $il.Tag = [string]$lc
        $il.ForeColor = $cText; $il.BackColor = $cMenuBg
        $il.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 5)
        $il.Add_Click({ param($snd, $ea) Set-Language ([string]$snd.Tag) })
        [void]$miLang.DropDownItems.Add($il)
    }
}
# ---------- QR code for the certificate download address (byte mode, ECC level L, versions 1-5) ----------
function New-QrMatrix([string]$text) {
    $data = [System.Text.Encoding]::ASCII.GetBytes($text)
    $caps = @(0, 17, 32, 53, 78, 106)
    $ecN  = @(0, 7, 10, 15, 20, 26)
    $ver = 0
    for ($v = 1; $v -le 5; $v++) { if ($data.Length -le $caps[$v]) { $ver = $v; break } }
    if ($ver -eq 0) { return $null }
    $size = 17 + 4 * $ver
    $ecLen = $ecN[$ver]
    $total = @(0, 26, 44, 70, 100, 134)[$ver]
    $dataCw = $total - $ecLen
    # --- bit stream
    $bits = New-Object System.Collections.ArrayList
    function AddBits([int]$val, [int]$len) { for ($i = $len - 1; $i -ge 0; $i--) { [void]$bits.Add(($val -shr $i) -band 1) } }
    AddBits 4 4
    AddBits $data.Length 8
    foreach ($b in $data) { AddBits $b 8 }
    $room = $dataCw * 8 - $bits.Count
    $tl = [math]::Min(4, $room)
    AddBits 0 $tl
    while (($bits.Count % 8) -ne 0) { [void]$bits.Add(0) }
    $cw = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $bits.Count; $i += 8) {
        $x = 0
        for ($j = 0; $j -lt 8; $j++) { $x = ($x -shl 1) -bor $bits[$i + $j] }
        [void]$cw.Add($x)
    }
    $pad = 0xEC
    while ($cw.Count -lt $dataCw) { [void]$cw.Add($pad); if ($pad -eq 0xEC) { $pad = 0x11 } else { $pad = 0xEC } }
    # --- Reed-Solomon
    $exp = New-Object 'int[]' 512
    $log = New-Object 'int[]' 256
    $x = 1
    for ($i = 0; $i -lt 255; $i++) { $exp[$i] = $x; $log[$x] = $i; $x = $x -shl 1; if ($x -band 0x100) { $x = $x -bxor 0x11D } }
    for ($i = 255; $i -lt 512; $i++) { $exp[$i] = $exp[$i - 255] }
    $gen = New-Object 'int[]' ($ecLen + 1)
    $gen[0] = 1
    for ($i = 0; $i -lt $ecLen; $i++) {
        for ($j = $i + 1; $j -ge 0; $j--) {
            $t = 0
            if ($gen[$j] -ne 0) { $t = $exp[($log[$gen[$j]] + $i) % 255] }
            $prev = 0
            if ($j -gt 0) { $prev = $gen[$j - 1] }
            $gen[$j] = $prev -bxor $t
        }
    }
    # gen[k] is coefficient of x^k ; remainder computation
    $rem = New-Object 'int[]' $ecLen
    foreach ($d in $cw) {
        $f = $d -bxor $rem[0]
        for ($i = 0; $i -lt $ecLen - 1; $i++) { $rem[$i] = $rem[$i + 1] }
        $rem[$ecLen - 1] = 0
        if ($f -ne 0) {
            for ($i = 0; $i -lt $ecLen; $i++) {
                $g = $gen[$ecLen - 1 - $i]
                if ($g -ne 0) { $rem[$i] = $rem[$i] -bxor $exp[($log[$f] + $log[$g]) % 255] }
            }
        }
    }
    $all = New-Object System.Collections.ArrayList
    foreach ($d in $cw) { [void]$all.Add($d) }
    foreach ($d in $rem) { [void]$all.Add($d) }
    # --- matrix: 0 light, 1 dark ; fn marks function modules
    $m = New-Object 'int[,]' $size, $size
    $fn = New-Object 'bool[,]' $size, $size
    function SetF([int]$r, [int]$c, [int]$v) { $m[$r, $c] = $v; $fn[$r, $c] = $true }
    function Finder([int]$r0, [int]$c0) {
        for ($r = -1; $r -le 7; $r++) { for ($c = -1; $c -le 7; $c++) {
            $rr = $r0 + $r; $cc = $c0 + $c
            if ($rr -lt 0 -or $rr -ge $size -or $cc -lt 0 -or $cc -ge $size) { continue }
            $v = 0
            if (($r -ge 0 -and $r -le 6 -and ($c -eq 0 -or $c -eq 6)) -or ($c -ge 0 -and $c -le 6 -and ($r -eq 0 -or $r -eq 6)) -or ($r -ge 2 -and $r -le 4 -and $c -ge 2 -and $c -le 4)) { $v = 1 }
            SetF $rr $cc $v
        } }
    }
    Finder 0 0; Finder 0 ($size - 7); Finder ($size - 7) 0
    for ($i = 8; $i -lt $size - 8; $i++) { $v = 1 - ($i % 2); SetF 6 $i $v; SetF $i 6 $v }
    if ($ver -ge 2) {
        $ap = $size - 7
        for ($r = -2; $r -le 2; $r++) { for ($c = -2; $c -le 2; $c++) {
            $v = 0
            if (([math]::Max([math]::Abs($r), [math]::Abs($c)) -ne 1)) { $v = 1 }
            SetF ($ap + $r) ($ap + $c) $v
        } }
    }
    SetF ($size - 8) 8 1
    # reserve format areas
    for ($i = 0; $i -lt 9; $i++) { if (-not $fn[8, $i]) { $fn[8, $i] = $true }; if (-not $fn[$i, 8]) { $fn[$i, 8] = $true } }
    for ($i = 0; $i -lt 8; $i++) { $q = $size - 1 - $i; $fn[8, $q] = $true; $fn[$q, 8] = $true }
    $q = $size - 8
    $fn[$q, 8] = $true
    # --- place data
    $bitList = New-Object System.Collections.ArrayList
    foreach ($d in $all) { for ($i = 7; $i -ge 0; $i--) { [void]$bitList.Add(($d -shr $i) -band 1) } }
    $pos = 0
    $up = $true
    for ($col = $size - 1; $col -ge 1; $col -= 2) {
        if ($col -eq 6) { $col = 5 }
        for ($k = 0; $k -lt $size; $k++) {
            if ($up) { $r = $size - 1 - $k } else { $r = $k }
            for ($dc = 0; $dc -lt 2; $dc++) {
                $c = $col - $dc
                if ($fn[$r, $c]) { continue }
                $v = 0
                if ($pos -lt $bitList.Count) { $v = $bitList[$pos]; $pos++ }
                $m[$r, $c] = $v
            }
        }
        $up = -not $up
    }
    # --- masks + penalty
    $best = $null; $bestPen = [int]::MaxValue
    for ($mask = 0; $mask -lt 8; $mask++) {
        $t = New-Object 'int[,]' $size, $size
        for ($r = 0; $r -lt $size; $r++) { for ($c = 0; $c -lt $size; $c++) {
            $v = $m[$r, $c]
            if (-not $fn[$r, $c]) {
                switch ($mask) {
                    0 { $f = (($r + $c) % 2) -eq 0 }
                    1 { $f = ($r % 2) -eq 0 }
                    2 { $f = ($c % 3) -eq 0 }
                    3 { $f = (($r + $c) % 3) -eq 0 }
                    4 { $f = ((([math]::Floor($r / 2)) + ([math]::Floor($c / 3))) % 2) -eq 0 }
                    5 { $f = ((($r * $c) % 2) + (($r * $c) % 3)) -eq 0 }
                    6 { $f = (((($r * $c) % 2) + (($r * $c) % 3)) % 2) -eq 0 }
                    7 { $f = (((($r + $c) % 2) + (($r * $c) % 3)) % 2) -eq 0 }
                }
                if ($f) { $v = 1 - $v }
            }
            $t[$r, $c] = $v
        } }
        # format info
        $fmt = (1 -shl 3) -bor $mask   # ECC L = 01
        $rm = $fmt -shl 10
        for ($i = 14; $i -ge 10; $i--) { if ((($rm -shr $i) -band 1) -ne 0) { $rm = $rm -bxor (0x537 -shl ($i - 10)) } }
        $fb = (($fmt -shl 10) -bor $rm) -bxor 0x5412
        for ($i = 0; $i -lt 15; $i++) {
            $b = ($fb -shr $i) -band 1
            if ($i -lt 6) { $t[$i, 8] = $b }
            elseif ($i -eq 6) { $t[7, 8] = $b }
            elseif ($i -eq 7) { $t[8, 8] = $b }
            elseif ($i -eq 8) { $t[8, 7] = $b }
            else { $q = 14 - $i; $t[8, $q] = $b }
            if ($i -lt 8) { $q = $size - 1 - $i; $t[8, $q] = $b }
            else { $q = $size - 15 + $i; $t[$q, 8] = $b }
        }
        $q = $size - 8
        $t[$q, 8] = 1
        # penalty
        $pen = 0
        for ($r = 0; $r -lt $size; $r++) {
            $run = 1
            for ($c = 1; $c -lt $size; $c++) { if ($t[$r, $c] -eq $t[$r, ($c - 1)]) { $run++ } else { if ($run -ge 5) { $pen += $run - 2 }; $run = 1 } }
            if ($run -ge 5) { $pen += $run - 2 }
        }
        for ($c = 0; $c -lt $size; $c++) {
            $run = 1
            for ($r = 1; $r -lt $size; $r++) { if ($t[$r, $c] -eq $t[($r - 1), $c]) { $run++ } else { if ($run -ge 5) { $pen += $run - 2 }; $run = 1 } }
            if ($run -ge 5) { $pen += $run - 2 }
        }
        for ($r = 0; $r -lt $size - 1; $r++) { for ($c = 0; $c -lt $size - 1; $c++) {
            $s = $t[$r, $c] + $t[($r + 1), $c] + $t[$r, ($c + 1)] + $t[($r + 1), ($c + 1)]
            if ($s -eq 0 -or $s -eq 4) { $pen += 3 }
        } }
        $dark = 0
        for ($r = 0; $r -lt $size; $r++) { for ($c = 0; $c -lt $size; $c++) { $dark += $t[$r, $c] } }
        $pen += 10 * [math]::Floor([math]::Abs(($dark * 100 / ($size * $size)) - 50) / 5)
        if ($pen -lt $bestPen) { $bestPen = $pen; $best = $t }
    }
    return ,$best
}

function New-QrBitmap([string]$text, [int]$scale) {
    $m = New-QrMatrix $text
    if ($m -eq $null) { return $null }
    $n = $m.GetLength(0)
    $px = ($n + 8) * $scale
    $bmp = New-Object System.Drawing.Bitmap($px, $px)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $blk = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Black)
    for ($r = 0; $r -lt $n; $r++) { for ($c = 0; $c -lt $n; $c++) {
        if ($m[$r, $c] -eq 1) { $g.FillRectangle($blk, (($c + 4) * $scale), (($r + 4) * $scale), $scale, $scale) }
    } }
    $blk.Dispose(); $g.Dispose()
    return $bmp
}

# Fenetre "Certificat iPhone" : fichier exporte, etapes, empreinte et QR code de telechargement.
function Show-CertDialog($lanIp) {
    $cp = Export-CaFile
    $fp = Get-CaFingerprint
    $url = ''
    if ($lanIp) { $url = 'https://' + $lanIp + ':' + $RemotePort + '/ca.cer' }
    $d = New-Object System.Windows.Forms.Form
    $d.Text = (T 'pin.cert')
    $d.ClientSize = New-Object System.Drawing.Size(520, 700)
    $d.StartPosition = 'CenterScreen'
    $d.FormBorderStyle = 'FixedDialog'
    $d.MaximizeBox = $false
    $d.MinimizeBox = $false
    $d.BackColor = $cBg
    $d.ForeColor = $cText
    $d.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $lt = New-Label (Tf 'cert.help' @($cp, $fp, $url)) 20 16 480 340 $d.Font $cText 'TopLeft'
    $d.Controls.Add($lt)
    $bmp = $null
    if ($url -ne '') { try { $bmp = New-QrBitmap $url 5 } catch { $bmp = $null } }
    if ($bmp -ne $null) {
        $pb = New-Object System.Windows.Forms.PictureBox
        $pb.Image = $bmp
        $pb.SizeMode = 'AutoSize'
        $pb.Location = New-Object System.Drawing.Point([int]((520 - $bmp.Width) / 2), 364)
        $d.Controls.Add($pb)
        $lq = New-Label (T 'cert.qr') 20 (364 + $bmp.Height + 6) 480 60 $d.Font $cMuted 'TopCenter'
        $d.Controls.Add($lq)
    }
    $okb = New-Object System.Windows.Forms.Button
    $okb.Text = 'OK'
    $okb.Location = New-Object System.Drawing.Point(205, 654)
    $okb.Size = New-Object System.Drawing.Size(110, 30)
    $okb.FlatStyle = 'Flat'; $okb.BackColor = $cCard; $okb.ForeColor = $cText
    $okb.Add_Click({ $d.Close() })
    $d.AcceptButton = $okb
    $d.Controls.Add($okb)
    [void]$d.ShowDialog()
    $d.Dispose()
    if ($bmp -ne $null) { $bmp.Dispose() }
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + $cp + '"') } catch { }
}

function Show-PinDialog {
    $lanIp = Get-LanIp
    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = (T 'pin.title')
    $dlg.ClientSize = New-Object System.Drawing.Size(380, 370)
    $dlg.StartPosition = 'CenterScreen'
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.MaximizeBox = $false
    $dlg.MinimizeBox = $false
    $dlg.BackColor = $cBg
    $dlg.ForeColor = $cText
    $dlg.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    if ($S.Listener -eq $null) { $addr = (T 'pin.off') }
    elseif ($lanIp) { $addr = (Tf 'pin.addr' @('https://' + $lanIp + ':' + $RemotePort)) }
    else { $addr = (T 'pin.noaddr') }
    $l1 = New-Label $addr 16 16 348 24 $dlg.Font $cText 'MiddleLeft'
    $l2 = New-Label (T 'pin.label') 16 56 348 22 $dlg.Font $cMuted 'MiddleLeft'
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = New-Object System.Drawing.Point(16, 82)
    $tb.Size = New-Object System.Drawing.Size(348, 26)
    $tb.Text = [string]$S.Pin
    $tb.BackColor = $cCard
    $tb.ForeColor = $cText
    $tb.BorderStyle = 'FixedSingle'
    $lerr = New-Label '' 16 112 348 22 $dlg.Font $cAmber 'MiddleLeft'
    $pbq = $null
    if (($S.Listener -ne $null) -and $lanIp) {
        try {
            $qb = New-QrBitmap ('https://' + $lanIp + ':' + $RemotePort + '/') 5
            if ($qb -ne $null) {
                $pbq = New-Object System.Windows.Forms.PictureBox
                $pbq.Image = $qb
                $pbq.SizeMode = 'Zoom'
                $pbq.Location = New-Object System.Drawing.Point(110, 144)
                $pbq.Size = New-Object System.Drawing.Size(160, 160)
            }
        } catch { $pbq = $null }
    }
    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = (T 'pin.save')
    $ok.Location = New-Object System.Drawing.Point(150, 326)
    $ok.Size = New-Object System.Drawing.Size(110, 30)
    $ok.FlatStyle = 'Flat'; $ok.BackColor = $cCard; $ok.ForeColor = $cText
    $ca = New-Object System.Windows.Forms.Button
    $ca.Text = (T 'pin.cancel')
    $ca.Location = New-Object System.Drawing.Point(270, 326)
    $ca.Size = New-Object System.Drawing.Size(94, 30)
    $ca.FlatStyle = 'Flat'; $ca.BackColor = $cCard; $ca.ForeColor = $cText
    $ca.Add_Click({ $dlg.Close() })
    $bc = New-Object System.Windows.Forms.Button
    $bc.Text = (T 'pin.cert')
    $bc.Location = New-Object System.Drawing.Point(16, 326)
    $bc.Size = New-Object System.Drawing.Size(124, 30)
    $bc.FlatStyle = 'Flat'; $bc.BackColor = $cCard; $bc.ForeColor = $cText
    $bc.Add_Click({
        try { Show-CertDialog $lanIp } catch { $lerr.Text = (Tf 'cert.fail' @($_.Exception.Message)) }
    })
    $ok.Add_Click({
        if (Set-Pin $tb.Text) { $dlg.Close() } else { $lerr.Text = (T 'pin.invalid') }
    })
    $dlg.AcceptButton = $ok
    $dlg.CancelButton = $ca
    foreach ($c in @($l1, $l2, $tb, $lerr, $bc, $ok, $ca)) { $dlg.Controls.Add($c) }
    if ($pbq -ne $null) { $dlg.Controls.Add($pbq) }
    [void]$dlg.ShowDialog()
    $dlg.Dispose()
    try { $lblFoot.Text = (Get-FootText) } catch { }
}
# Assistant de premiere ouverture (reutilise Set-Pin, Show-CertDialog, Set-Autostart, Set-Language)
# ---------- Fenetre de reglages : chaque case agit tout de suite (reutilise les fonctions des menus) ----------
# ---------- A propos et verification des mises a jour (aucun telechargement automatique) ----------
function Get-LatestRelease {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/zerkino/ZerkiWatch/releases/latest' -UserAgent 'ZerkiWatch' -TimeoutSec 6
        $tag = ([string]$r.tag_name).TrimStart('v','V')
        return @{ Tag = $tag; Url = [string]$r.html_url; Newer = ([Version]($tag -replace '[^0-9.].*$','') -gt [Version]$APPVER) }
    } catch { return $null }
}
function Show-About {
    $res = Get-LatestRelease
    if ($res -eq $null) { $m = (T 'about.offline') }
    elseif ($res.Newer) { $m = (Tf 'about.newer' @($res.Tag)) }
    else { $m = (T 'about.uptodate') }
    $txt = 'ZerkiWatch v' + $APPVER + "`r`nMIT - github.com/zerkino/ZerkiWatch`r`n`r`n" + $m
    if (($res -ne $null) -and $res.Newer) {
        $a = [System.Windows.Forms.MessageBox]::Show($txt + "`r`n`r`n" + (T 'about.open'), 'ZerkiWatch', 'YesNo', 'Information')
        if ($a -eq 'Yes') { try { Start-Process $res.Url } catch { } }
    } else { [void][System.Windows.Forms.MessageBox]::Show($txt, 'ZerkiWatch', 'OK', 'Information') }
}

function Show-Settings {
    $d = New-Object System.Windows.Forms.Form
    $d.Text = (T 'set.title')
    $d.ClientSize = New-Object System.Drawing.Size(520, 700)
    $d.StartPosition = 'CenterScreen'
    $d.FormBorderStyle = 'FixedDialog'
    $d.MaximizeBox = $false
    $d.MinimizeBox = $false
    $d.BackColor = $cBg
    $d.ForeColor = $cText
    $d.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $fH = New-Object System.Drawing.Font('Segoe UI Semibold', 9)
    $ld = @{ v = $true }
    $y = 14
    function Add-Head([string]$txt) {
        $d.Controls.Add((New-Label $txt.ToUpper() 24 $script:y 472 20 $fH $cMuted 'MiddleLeft'))
        $script:y = $script:y + 26
    }
    function Add-Check([string]$txt, [bool]$val) {
        $c = New-Object System.Windows.Forms.CheckBox
        $c.Text = $txt
        $c.Location = New-Object System.Drawing.Point(28, $script:y)
        $c.Size = New-Object System.Drawing.Size(468, 24)
        $c.ForeColor = $cText
        $c.Checked = $val
        $d.Controls.Add($c)
        $script:y = $script:y + 26
        return $c
    }
    function Add-Combo([string]$txt, [string[]]$items, [int]$sel) {
        $d.Controls.Add((New-Label $txt 28 ($script:y + 2) 200 22 $d.Font $cText 'MiddleLeft'))
        $c = New-Object System.Windows.Forms.ComboBox
        $c.DropDownStyle = 'DropDownList'
        $c.FlatStyle = 'Standard'
        $c.DropDownHeight = 200
        $c.IntegralHeight = $false
        $c.Location = New-Object System.Drawing.Point(236, $script:y)
        $c.Size = New-Object System.Drawing.Size(260, 26)
        foreach ($it in $items) { [void]$c.Items.Add($it) }
        $c.SelectedIndex = $sel
        $d.Controls.Add($c)
        $script:y = $script:y + 32
        return $c
    }
    function Add-Num([System.Windows.Forms.CheckBox]$chk, [int]$val, [int]$max, [string]$unit) {
        $n = New-Object System.Windows.Forms.NumericUpDown
        $n.Minimum = 1
        $n.Maximum = $max
        $n.Value = [math]::Max(1, [math]::Min($max, $val))
        $n.Location = New-Object System.Drawing.Point(320, ($script:y - 28))
        $n.Size = New-Object System.Drawing.Size(80, 26)
        $n.BackColor = $cCard; $n.ForeColor = $cText
        $d.Controls.Add($n)
        $d.Controls.Add((New-Label $unit 408 ($script:y - 26) 88 22 $d.Font $cMuted 'MiddleLeft'))
        return $n
    }
    $script:y = 14
    Add-Head (T 'set.display')
    $cbBar = Add-Check (T 'menu.bar_full') (-not $BAR.UserHidden)
    $cbWid = Add-Check (T 'menu.widget') $WID.On
    $cbDock = Add-Check (T 'menu.dock') $BAR.Dock
    $cbTop = Add-Check (T 'menu.top') $BAR.Top
    $selSz = 1
    if ([math]::Abs($BAR.UserScale - 0.85) -lt 0.01) { $selSz = 0 } elseif ([math]::Abs($BAR.UserScale - 1.25) -lt 0.01) { $selSz = 2 }
    $coSz = Add-Combo (T 'menu.size') @((T 'menu.small'), (T 'menu.normal'), (T 'menu.big')) $selSz
    $tlist = @('auto', 'light', 'dark', 'blue', 'violet', 'green', 'gray'); $selTh = [array]::IndexOf($tlist, $ThemePref); if ($selTh -lt 0) { $selTh = 2 }
    $coTh = Add-Combo (T 'set.theme') @((T 'set.theme_auto'), (T 'set.theme_light'), (T 'set.theme_dark'), (T 'set.theme_blue'), (T 'set.theme_violet'), (T 'set.theme_green'), (T 'set.theme_gray')) $selTh
    $script:y = $script:y + 6
    Add-Head (T 'set.general')
    $cbAuto = Add-Check (T 'menu.auto') (Test-Autostart)
    $cbCum = Add-Check (T 'menu.cumul') $S.CumulOn
    $cbHot = Add-Check (T 'menu.hotkey_enable') $S.HkOn
    if (-not $S.HkOk) { $cbHot.Enabled = $false }
    $script:y = $script:y + 6
    Add-Head (T 'set.alerts')
    $cbAs = Add-Check (T 'set.alert_speed') ($S.AlertSpeed -gt 0)
    $nuAs = Add-Num $cbAs ([math]::Max(1, [int]$S.AlertSpeed)) 10000 'Mbps'
    $cbAc = Add-Check (T 'set.alert_cut') ($S.AlertCut -gt 0)
    $nuAc = Add-Num $cbAc ([math]::Max(1, [int]$S.AlertCut)) 1440 (T 'set.min')
    $script:y = $script:y + 6
    Add-Head (T 'set.remote')
    $btnPw = New-Object System.Windows.Forms.Button
    $btnPw.Text = (T 'set.pw')
    $btnPw.Location = New-Object System.Drawing.Point(28, $script:y)
    $btnPw.Size = New-Object System.Drawing.Size(230, 30)
    $btnCe = New-Object System.Windows.Forms.Button
    $btnCe.Text = (T 'pin.cert')
    $btnCe.Location = New-Object System.Drawing.Point(266, $script:y)
    $btnCe.Size = New-Object System.Drawing.Size(230, 30)
    $btnWz = New-Object System.Windows.Forms.Button
    $btnWz.Text = (T 'menu.wizard')
    $btnWz.Location = New-Object System.Drawing.Point(28, ($script:y + 38))
    $btnWz.Size = New-Object System.Drawing.Size(230, 30)
    $btnAb = New-Object System.Windows.Forms.Button
    $btnAb.Text = (T 'about.btn')
    $btnAb.Location = New-Object System.Drawing.Point(266, ($script:y + 38))
    $btnAb.Size = New-Object System.Drawing.Size(230, 30)
    $cbUp = New-Object System.Windows.Forms.CheckBox
    $cbUp.Text = (T 'about.startup')
    $cbUp.Location = New-Object System.Drawing.Point(28, ($script:y + 76))
    $cbUp.Size = New-Object System.Drawing.Size(468, 24)
    $cbUp.ForeColor = $cText
    $cbUp.Checked = [bool]$S.UpdCheck
    $d.Controls.Add($cbUp)
    $btnCl = New-Object System.Windows.Forms.Button
    $btnCl.Text = (T 'set.close')
    $btnCl.Location = New-Object System.Drawing.Point(386, 654)
    $btnCl.Size = New-Object System.Drawing.Size(110, 32)
    foreach ($bt in @($btnPw, $btnCe, $btnWz, $btnAb, $btnCl)) { $bt.FlatStyle = 'Flat'; $bt.BackColor = $cCard; $bt.ForeColor = $cText; $d.Controls.Add($bt) }
    if ($S.Listener -eq $null) { $btnCe.Enabled = $false }
    $lanIp = Get-LanIp
    $d.CancelButton = $btnCl
    $d.AcceptButton = $btnCl
    $btnCl.Add_Click({ $d.Close() })
    $btnPw.Add_Click({ try { Show-PinDialog } catch { } })
    $btnCe.Add_Click({ try { Show-CertDialog $lanIp } catch { } })
    $btnAb.Add_Click({ try { Show-About } catch { } })
    $cbUp.Add_CheckedChanged({ if (-not $ld.v) { $S.UpdCheck = $cbUp.Checked; Save-BarConfig } })
    $btnWz.Add_Click({ $d.Close(); try { Show-Wizard } catch { } })
    $cbBar.Add_CheckedChanged({ if (-not $ld.v) { if ($cbBar.Checked -eq $BAR.UserHidden) { Switch-Bar } } })
    $cbWid.Add_CheckedChanged({ if (-not $ld.v) { if ($cbWid.Checked -ne $WID.On) { Switch-Widget } } })
    $cbDock.Add_CheckedChanged({ if (-not $ld.v) { if ($cbDock.Checked -ne $BAR.Dock) { Set-Dock $cbDock.Checked; $ld.v = $true; $cbDock.Checked = $BAR.Dock; $ld.v = $false } } })
    $cbTop.Add_CheckedChanged({ if (-not $ld.v) { $BAR.Top = $cbTop.Checked; $barForm.TopMost = $BAR.Top; $wForm.TopMost = $BAR.Top; Save-BarConfig } })
    $coSz.Add_SelectedIndexChanged({ if (-not $ld.v) { $scl = @(0.85, 1.0, 1.25)[$coSz.SelectedIndex]; Set-BarScale ([double]$scl) } })
    $coTh.Add_SelectedIndexChanged({
        if ($ld.v) { return }
        $tl = @('auto', 'light', 'dark', 'blue', 'violet', 'green', 'gray')
        $np = [string]$tl[$coTh.SelectedIndex]
        if ($np -ne $ThemePref) {
            $script:ThemePref = $np
            Save-BarConfig
            try { $tray.ShowBalloonTip(2500, 'ZerkiWatch', (T 'bal.theme_restart'), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
            $d.Close()
            Restart-App
        }
    })
    $cbAuto.Add_CheckedChanged({ if (-not $ld.v) { if ($cbAuto.Checked -ne (Test-Autostart)) { Set-Autostart $cbAuto.Checked } } })
    $cbCum.Add_CheckedChanged({ if (-not $ld.v) { $S.CumulOn = $cbCum.Checked; Save-BarConfig } })
    $cbHot.Add_CheckedChanged({ if (-not $ld.v) { $S.HkOn = $cbHot.Checked; Save-BarConfig; Apply-Hotkey } })
    $cbAs.Add_CheckedChanged({ if (-not $ld.v) { if ($cbAs.Checked) { $S.AlertSpeed = [int]$nuAs.Value } else { $S.AlertSpeed = 0 }; $S.AlHi = 0; $S.AlArm = $true; Save-BarConfig } })
    $nuAs.Add_ValueChanged({ if ((-not $ld.v) -and $cbAs.Checked) { $S.AlertSpeed = [int]$nuAs.Value; Save-BarConfig } })
    $cbAc.Add_CheckedChanged({ if (-not $ld.v) { if ($cbAc.Checked) { $S.AlertCut = [int]$nuAc.Value } else { $S.AlertCut = 0 }; $S.AlCutSent = $false; Save-BarConfig } })
    $nuAc.Add_ValueChanged({ if ((-not $ld.v) -and $cbAc.Checked) { $S.AlertCut = [int]$nuAc.Value; Save-BarConfig } })
    $ld.v = $false
    [void]$d.ShowDialog()
    $d.Dispose()
    try { Update-Ui } catch { }
}

function Show-Wizard {
    $lanIp = Get-LanIp
    $d = New-Object System.Windows.Forms.Form
    $d.Text = (T 'wiz.title')
    $d.ClientSize = New-Object System.Drawing.Size(480, 430)
    $d.StartPosition = 'CenterScreen'
    $d.FormBorderStyle = 'FixedDialog'
    $d.MaximizeBox = $false
    $d.MinimizeBox = $false
    $d.BackColor = $cBg
    $d.ForeColor = $cText
    $d.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $fT = New-Object System.Drawing.Font('Segoe UI Semibold', 13)
    $d.Controls.Add((New-Label (T 'wiz.title') 24 18 432 28 $fT $cText 'MiddleLeft'))
    $d.Controls.Add((New-Label (T 'wiz.intro') 24 50 432 40 $d.Font $cMuted 'TopLeft'))
    $d.Controls.Add((New-Label (T 'wiz.lang') 24 100 432 20 $d.Font $cMuted 'MiddleLeft'))
    $cb = New-Object System.Windows.Forms.ComboBox
    $cb.DropDownStyle = 'DropDownList'
    $cb.Location = New-Object System.Drawing.Point(24, 122)
    $cb.Size = New-Object System.Drawing.Size(432, 26)
    $codes = New-Object System.Collections.ArrayList
    [void]$cb.Items.Add((T 'menu.lang_auto')); [void]$codes.Add('')
    foreach ($lc in @($LangDb.Keys | Sort-Object)) {
        $nm = $lc
        if ($LangDb[$lc].ContainsKey('lang.name')) { $nm = [string]$LangDb[$lc]['lang.name'] }
        [void]$cb.Items.Add($nm); [void]$codes.Add([string]$lc)
    }
    $cb.SelectedIndex = [math]::Max(0, $codes.IndexOf([string]$LangPref))
    $d.Controls.Add($cb)
    $d.Controls.Add((New-Label (T 'wiz.pin') 24 162 432 20 $d.Font $cMuted 'MiddleLeft'))
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Location = New-Object System.Drawing.Point(24, 184)
    $tb.Size = New-Object System.Drawing.Size(200, 26)
    $tb.Text = [string]$S.Pin
    $tb.BackColor = $cCard; $tb.ForeColor = $cText; $tb.BorderStyle = 'FixedSingle'
    $d.Controls.Add($tb)
    $btCert = New-Object System.Windows.Forms.Button
    $btCert.Text = (T 'pin.cert')
    $btCert.Location = New-Object System.Drawing.Point(236, 182)
    $btCert.Size = New-Object System.Drawing.Size(220, 30)
    $btCert.FlatStyle = 'Flat'; $btCert.BackColor = $cCard; $btCert.ForeColor = $cText
    if ($S.Listener -eq $null) { $btCert.Enabled = $false }
    $btCert.Add_Click({ try { Show-CertDialog $lanIp } catch { } })
    $d.Controls.Add($btCert)
    $d.Controls.Add((New-Label (T 'wiz.cert_hint') 24 218 432 56 $d.Font $cMuted 'TopLeft'))
    $ck = New-Object System.Windows.Forms.CheckBox
    $ck.Text = (T 'menu.auto')
    $ck.Location = New-Object System.Drawing.Point(24, 286)
    $ck.Size = New-Object System.Drawing.Size(432, 26)
    $ck.ForeColor = $cText
    $ck.Checked = (Test-Autostart)
    $d.Controls.Add($ck)
    $lerr = New-Label '' 24 322 432 22 $d.Font $cAmber 'MiddleLeft'
    $d.Controls.Add($lerr)
    $bf = New-Object System.Windows.Forms.Button
    $bf.Text = (T 'wiz.finish')
    $bf.Location = New-Object System.Drawing.Point(236, 380)
    $bf.Size = New-Object System.Drawing.Size(130, 32)
    $bf.FlatStyle = 'Flat'; $bf.BackColor = $cCard; $bf.ForeColor = $cText
    $bs = New-Object System.Windows.Forms.Button
    $bs.Text = (T 'wiz.skip')
    $bs.Location = New-Object System.Drawing.Point(376, 380)
    $bs.Size = New-Object System.Drawing.Size(80, 32)
    $bs.FlatStyle = 'Flat'; $bs.BackColor = $cCard; $bs.ForeColor = $cText
    $S.WizLang = $null
    $bs.Add_Click({ $S.WizDone = $true; Save-BarConfig; $d.Close() })
    $bf.Add_Click({
        $newPin = $tb.Text.Trim()
        if (($newPin -ne [string]$S.Pin) -and (-not (Set-Pin $newPin))) { $lerr.Text = (T 'pin.invalid'); return }
        try { if ($ck.Checked -ne (Test-Autostart)) { Set-Autostart $ck.Checked } } catch { }
        $S.WizDone = $true
        Save-BarConfig
        $pick = [string]$codes[[math]::Max(0, $cb.SelectedIndex)]
        if ($pick -ne [string]$LangPref) { $S.WizLang = $pick }
        $d.Close()
    })
    $d.AcceptButton = $bf
    $d.CancelButton = $bs
    $d.Controls.Add($bf)
    $d.Controls.Add($bs)
    [void]$d.ShowDialog()
    $d.Dispose()
    try { $lblFoot.Text = (Get-FootText) } catch { }
    if ($S.WizLang -ne $null) { $pl = [string]$S.WizLang; $S.WizLang = $null; Set-Language $pl }
}
$menu.Add_Opening({ try { Update-MenuText } catch { }; try { Update-LangMenu } catch { }; try { Update-DiskMenu } catch { Write-Log ('Disk menu: ' + $_.Exception.Message) 'md' }; try { Update-HotMenu } catch { Write-Log ('Hotkey menu: ' + $_.Exception.Message) 'mh' } })
$miOpen.Add_Click({ Show-Main })
$miHist.Add_Click({ try { Show-History } catch { Write-Log ('History: ' + $_.Exception.Message) 'sh' } })
$miNet.Add_Click({ Invoke-Toggle })
$miBar.Add_Click({ Switch-Bar })
$miWid.Add_Click({ Switch-Widget })
$miTop.Add_Click({ $BAR.Top = (-not $BAR.Top); $barForm.TopMost = $BAR.Top; $wForm.TopMost = $BAR.Top; Save-BarConfig })
$miS1.Add_Click({ Set-BarScale 0.85 })
$miS2.Add_Click({ Set-BarScale 1.0 })
$miS3.Add_Click({ Set-BarScale 1.25 })
$miReset.Add_Click({ if ($BAR.Dock) { Set-Dock $false }; Set-BarDefaultPos; Set-WidgetDefaultPos; Save-BarConfig })
$miDock.Add_Click({ Set-Dock (-not $BAR.Dock) })
$miAuto.Add_Click({ Set-Autostart (-not (Test-Autostart)) })
$miCumul.Add_Click({ $S.CumulOn = (-not $S.CumulOn); Save-BarConfig })
$miLog.Add_Click({
    try {
        if (-not (Test-Path -LiteralPath $logFile)) { Write-Log 'Log opened' }
        Start-Process -FilePath 'notepad.exe' -ArgumentList ('"' + $logFile + '"')
    } catch { }
})
$miPhone.Add_Click({ try { Show-PinDialog } catch { Write-Log ('PIN dialog: ' + $_.Exception.Message) } })
$miSet.Add_Click({ try { Show-Settings } catch { Write-Log ('Settings: ' + $_.Exception.Message) 'st' } })
$btnSet.Add_Click({ try { Show-Settings } catch { Write-Log ('Settings: ' + $_.Exception.Message) 'st' } })
$miWiz.Add_Click({ try { Show-Wizard } catch { Write-Log ('Wizard: ' + $_.Exception.Message) 'wz' } })
$miQuit.Add_Click({ Quit-App })
$barForm.ContextMenuStrip = $menu
$wForm.ContextMenuStrip = $menu

$tray = New-Object System.Windows.Forms.NotifyIcon
if ($form.Icon -ne $null) { $tray.Icon = $form.Icon } else { $tray.Icon = [System.Drawing.SystemIcons]::Application }
$tray.Text = 'ZerkiWatch'
$tray.ContextMenuStrip = $menu
$tray.Visible = $true
$tray.Add_DoubleClick({ Show-Main })

# ---------- Historique : enregistrement, lecture, totaux ----------
$histFile = Join-Path $cfgDir 'history.csv'
$daysFile = Join-Path $cfgDir 'totals.csv'
$invc = [System.Globalization.CultureInfo]::InvariantCulture
$frc = $LangCulture
$histEpoch = New-Object DateTime(2020, 1, 1)
$S.HistMem = New-Object System.Collections.ArrayList
$S.Days = New-Object 'System.Collections.Generic.SortedDictionary[string,double[]]'
$S.HA = @{ Key = ''; T = 0.0; Dl = 0.0; Ul = 0.0; Cpu = 0.0; Ram = 0.0; Gpu = 0.0; GpuT = 0.0; Rx = 0.0; Tx = 0.0 }
$S.DaysDirty = $false
$S.DaysSaved = [DateTime]::UtcNow
$S.HistDay = ''
$S.HistRange = '24h'
$S.HistData = $null
$S.HistTot = $null
$S.HistForm = $null
$S.PnlHist = $null
$S.HistTimer = $null
$S.HistPills = @()

function Get-MinIdx([DateTime]$d) { return [long][math]::Floor(($d - $histEpoch).TotalMinutes) }

function Format-HistRec($r) {
    return ($histEpoch.AddMinutes($r[0]).ToString('yyyyMMddHHmm', $invc) + ',' +
        $r[1].ToString('0.000', $invc) + ',' + $r[2].ToString('0.000', $invc) + ',' +
        $r[3].ToString('0.0', $invc) + ',' + $r[4].ToString('0.0', $invc) + ',' + $r[5].ToString('0.0', $invc) + ',' +
        $r[6].ToString('0', $invc) + ',' + $r[7].ToString('0', $invc))
}

function Load-History {
    try {
        if (Test-Path -LiteralPath $histFile) {
            $cut = (Get-Date).AddDays(-7)
            $keep = New-Object System.Collections.ArrayList
            $total = 0
            foreach ($ln in [System.IO.File]::ReadAllLines($histFile)) {
                $total++
                $p = $ln.Split(',')
                if ($p.Count -lt 8) { continue }
                try {
                    $dt = [DateTime]::ParseExact($p[0], 'yyyyMMddHHmm', $invc)
                    if ($dt -lt $cut) { continue }
                    $rec = New-Object 'double[]' 8
                    $rec[0] = [double](Get-MinIdx $dt)
                    for ($i = 1; $i -lt 8; $i++) { $rec[$i] = [double]::Parse($p[$i], $invc) }
                    [void]$S.HistMem.Add($rec)
                    [void]$keep.Add($ln)
                } catch { }
            }
            if ($keep.Count -ne $total) { [System.IO.File]::WriteAllLines($histFile, [string[]]$keep.ToArray()) }
        }
    } catch { Write-Log ('History read: ' + $_.Exception.Message) }
    try {
        if (Test-Path -LiteralPath $daysFile) {
            foreach ($ln in [System.IO.File]::ReadAllLines($daysFile)) {
                $p = $ln.Split(',')
                if ($p.Count -lt 3) { continue }
                try { $S.Days[$p[0]] = [double[]]@([double]::Parse($p[1], $invc), [double]::Parse($p[2], $invc)) } catch { }
            }
        }
    } catch { Write-Log ('Totals read: ' + $_.Exception.Message) }
}

function Save-Days {
    try {
        if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        $out = New-Object System.Collections.ArrayList
        foreach ($k in $S.Days.Keys) {
            $v = $S.Days[$k]
            [void]$out.Add($k + ',' + $v[0].ToString('0', $invc) + ',' + $v[1].ToString('0', $invc))
        }
        [System.IO.File]::WriteAllLines($daysFile, [string[]]$out.ToArray())
        $S.DaysDirty = $false
        $S.DaysSaved = [DateTime]::UtcNow
    } catch { Write-Log ('Totals write: ' + $_.Exception.Message) 'sd' }
}

function Flush-Minute {
    $a = $S.HA
    if (($a.Key -eq '') -or ($a.T -le 0)) { $a.Key = ''; return }
    try {
        $dtm = [DateTime]::ParseExact($a.Key, 'yyyyMMddHHmm', $invc)
        $rec = New-Object 'double[]' 8
        $rec[0] = [double](Get-MinIdx $dtm)
        $rec[1] = $a.Dl / $a.T
        $rec[2] = $a.Ul / $a.T
        $rec[3] = $a.Cpu / $a.T
        $rec[4] = $a.Ram / $a.T
        if ($a.GpuT -gt 0) { $rec[5] = $a.Gpu / $a.GpuT } else { $rec[5] = -1.0 }
        $rec[6] = $a.Rx
        $rec[7] = $a.Tx
        if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        [System.IO.File]::AppendAllText($histFile, (Format-HistRec $rec) + [Environment]::NewLine)
        [void]$S.HistMem.Add($rec)
        $lim = $rec[0] - 10080
        while (($S.HistMem.Count -gt 0) -and ($S.HistMem[0][0] -lt $lim)) { $S.HistMem.RemoveAt(0) }
        $day = $dtm.ToString('yyyy-MM-dd', $invc)
        if ($S.Days.ContainsKey($day)) {
            $v = $S.Days[$day]
            $v[0] = $v[0] + $a.Rx
            $v[1] = $v[1] + $a.Tx
        } else {
            $S.Days[$day] = [double[]]@($a.Rx, $a.Tx)
        }
        $S.DaysDirty = $true
        if (($S.HistDay -ne '') -and ($S.HistDay -ne $day)) {
            $lines = New-Object System.Collections.ArrayList
            foreach ($r in $S.HistMem) { [void]$lines.Add((Format-HistRec $r)) }
            [System.IO.File]::WriteAllLines($histFile, [string[]]$lines.ToArray())
        }
        $S.HistDay = $day
    } catch { Write-Log ('Minute history: ' + $_.Exception.Message) 'fm' }
    $a.Key = ''; $a.T = 0.0; $a.Dl = 0.0; $a.Ul = 0.0; $a.Cpu = 0.0; $a.Ram = 0.0; $a.Gpu = 0.0; $a.GpuT = 0.0; $a.Rx = 0.0; $a.Tx = 0.0
    if ($S.DaysDirty -and (([DateTime]::UtcNow - $S.DaysSaved).TotalSeconds -gt 300)) { Save-Days }
}

function Update-Hist([double]$drx, [double]$dtx, [double]$dt) {
    $a = $S.HA
    $key = (Get-Date).ToString('yyyyMMddHHmm', $invc)
    if (($a.Key -ne '') -and ($a.Key -ne $key)) { Flush-Minute }
    $a.Key = $key
    $w = [math]::Min($dt, 10.0)
    $a.T = $a.T + $w
    $a.Dl = $a.Dl + [double]$S.Dl * $w
    $a.Ul = $a.Ul + [double]$S.Ul * $w
    $a.Cpu = $a.Cpu + [double]$S.Cpu * $w
    $a.Ram = $a.Ram + [double]$S.Ram * $w
    if ([double]$S.Gpu -ge 0) { $a.Gpu = $a.Gpu + [double]$S.Gpu * $w; $a.GpuT = $a.GpuT + $w }
    $a.Rx = $a.Rx + $drx
    $a.Tx = $a.Tx + $dtx
}

function Get-HistSeries([string]$range) {
    $bm = 1
    $n = 60
    if ($range -eq '24h') { $bm = 15; $n = 96 }
    elseif ($range -eq '7d') { $bm = 60; $n = 168 }
    else { $range = '1h' }
    $endIdx = Get-MinIdx (Get-Date)
    $lastB = $endIdx - ($endIdx % $bm)
    $startIdx = $lastB - ($n - 1) * $bm
    $sum = New-Object 'double[]' (5 * $n)
    $cnt = New-Object 'double[]' (5 * $n)
    for ($i = $S.HistMem.Count - 1; $i -ge 0; $i--) {
        $r = $S.HistMem[$i]
        if ($r[0] -lt $startIdx) { break }
        $b = [int][math]::Floor(($r[0] - $startIdx) / $bm)
        if (($b -lt 0) -or ($b -ge $n)) { continue }
        for ($m = 0; $m -lt 5; $m++) {
            $v = $r[$m + 1]
            if (($m -eq 4) -and ($v -lt 0)) { continue }
            $ix = ($m * $n) + $b
            $sum[$ix] = $sum[$ix] + $v
            $cnt[$ix] = $cnt[$ix] + 1
        }
    }
    $o = @{}
    $names = @('dl', 'ul', 'cpu', 'ram', 'gpu')
    for ($m = 0; $m -lt 5; $m++) {
        $arr = New-Object 'double[]' $n
        for ($b = 0; $b -lt $n; $b++) {
            $ix = ($m * $n) + $b
            if ($cnt[$ix] -gt 0) { $arr[$b] = [math]::Round(($sum[$ix] / $cnt[$ix]), 2) } else { $arr[$b] = -1.0 }
        }
        $o[$names[$m]] = $arr
    }
    $startDt = $histEpoch.AddMinutes($startIdx)
    $o.range = $range
    $o.n = $n
    $o.step = $bm * 60
    $o.start = ([DateTimeOffset]$startDt).ToUnixTimeSeconds()
    return $o
}

function Get-DayBytes([string]$key) {
    $rx = 0.0
    $tx = 0.0
    if ($S.Days.ContainsKey($key)) { $v = $S.Days[$key]; $rx = $v[0]; $tx = $v[1] }
    $hk = [string]$S.HA.Key
    if ($hk.Length -ge 8) {
        $dk = $hk.Substring(0, 4) + '-' + $hk.Substring(4, 2) + '-' + $hk.Substring(6, 2)
        if ($dk -eq $key) { $rx = $rx + $S.HA.Rx; $tx = $tx + $S.HA.Tx }
    }
    return @($rx, $tx)
}

function Get-HistTotals {
    $today = (Get-Date).Date
    $days = New-Object System.Collections.ArrayList
    for ($i = 6; $i -ge 0; $i--) {
        $d = $today.AddDays(-$i)
        $bb = Get-DayBytes ($d.ToString('yyyy-MM-dd', $invc))
        [void]$days.Add(@{ d = $d.ToString('ddd dd/MM', $frc); rx = [math]::Round($bb[0]); tx = [math]::Round($bb[1]) })
    }
    $tb = Get-DayBytes ($today.ToString('yyyy-MM-dd', $invc))
    $mon = @{}
    foreach ($k in $S.Days.Keys) {
        $mk = $k.Substring(0, 7)
        $v = $S.Days[$k]
        if (-not $mon.ContainsKey($mk)) { $mon[$mk] = [double[]]@(0.0, 0.0) }
        $mon[$mk][0] = $mon[$mk][0] + $v[0]
        $mon[$mk][1] = $mon[$mk][1] + $v[1]
    }
    $hk = [string]$S.HA.Key
    if ($hk.Length -ge 6) {
        $mk = $hk.Substring(0, 4) + '-' + $hk.Substring(4, 2)
        if (-not $mon.ContainsKey($mk)) { $mon[$mk] = [double[]]@(0.0, 0.0) }
        $mon[$mk][0] = $mon[$mk][0] + $S.HA.Rx
        $mon[$mk][1] = $mon[$mk][1] + $S.HA.Tx
    }
    $months = New-Object System.Collections.ArrayList
    foreach ($k in @($mon.Keys | Sort-Object -Descending | Select-Object -First 6)) {
        $lab = $k
        try { $lab = [DateTime]::ParseExact($k + '-01', 'yyyy-MM-dd', $invc).ToString('MMM yyyy', $frc) } catch { }
        [void]$months.Add(@{ m = $lab; rx = [math]::Round($mon[$k][0]); tx = [math]::Round($mon[$k][1]) })
    }
    return @{ todayRx = [math]::Round($tb[0]); todayTx = [math]::Round($tb[1]); days = $days.ToArray(); months = $months.ToArray() }
}

function Get-HistPayload([string]$range) {
    $o = Get-HistSeries $range
    $o.totals = Get-HistTotals
    $o.top = Get-TopPayload
    return $o
}

Load-History

# ---------- Cumul par application et par service (35 jours) ----------
$appsFile = Join-Path $cfgDir 'apps.csv'
$S.AppDays = New-Object 'System.Collections.Generic.SortedDictionary[string,double[]]'
$S.AppDirty = $false
$S.AppSaved = [DateTime]::UtcNow
$S.AppKeep = 35
$S.HistTop = $null
$S.TopRange = 'd1'
$S.TopPills = @()

function Clean-AppName([string]$s) {
    $s = $s.Replace(',', ' ').Replace('|', ' ').Replace("`r", ' ').Replace("`n", ' ').Trim()
    if ($s.Length -gt 60) { $s = $s.Substring(0, 60) }
    if ($s.Length -eq 0) { $s = '?' }
    return $s
}

function Get-ProcClass([int]$procId) {
    if ($procId -eq 4) { return @('S', (T 'app.system')) }
    if ($S.SvcMap.ContainsKey($procId)) {
        $names = $S.SvcMap[$procId]
        $nm = [string]$names[0]
        if ($names.Count -gt 1) { $nm = $nm + ' (+' + ($names.Count - 1) + ')' }
        return @('S', $nm)
    }
    $lbl = [string](Get-AppLabel $procId)
    if ($lbl.StartsWith('Process ')) { $lbl = (T 'app.others') }
    return @('A', $lbl)
}

function Get-AppCut {
    return (Get-Date).Date.AddDays(-($S.AppKeep - 1)).ToString('yyyy-MM-dd', $invc)
}

function Load-AppDays {
    try {
        if (Test-Path -LiteralPath $appsFile) {
            $cut = Get-AppCut
            foreach ($ln in [System.IO.File]::ReadAllLines($appsFile)) {
                $p = $ln.Split(',')
                if ($p.Count -lt 5) { continue }
                if ([string]::CompareOrdinal($p[0], $cut) -lt 0) { continue }
                try { $S.AppDays[$p[0] + '|' + $p[1] + '|' + $p[2]] = [double[]]@([double]::Parse($p[3], $invc), [double]::Parse($p[4], $invc)) } catch { }
            }
        }
    } catch { Write-Log ('App totals read: ' + $_.Exception.Message) }
}

function Save-AppDays {
    try {
        if (-not (Test-Path -LiteralPath $cfgDir)) { New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null }
        $cut = Get-AppCut
        $out = New-Object System.Collections.ArrayList
        $drop = New-Object System.Collections.ArrayList
        foreach ($k in $S.AppDays.Keys) {
            if ([string]::CompareOrdinal($k.Substring(0, 10), $cut) -lt 0) { [void]$drop.Add($k); continue }
            $v = $S.AppDays[$k]
            $p = $k.Split('|')
            [void]$out.Add($p[0] + ',' + $p[1] + ',' + $p[2] + ',' + $v[0].ToString('0', $invc) + ',' + $v[1].ToString('0', $invc))
        }
        foreach ($k in $drop) { [void]$S.AppDays.Remove($k) }
        [System.IO.File]::WriteAllLines($appsFile, [string[]]$out.ToArray())
        $S.AppDirty = $false
        $S.AppSaved = [DateTime]::UtcNow
    } catch { Write-Log ('App totals write: ' + $_.Exception.Message) 'sa' }
}

function Update-AppAcc {
    if (-not $S.EtwOk) { return }
    if ((([DateTime]::UtcNow - $S.SvcStamp).TotalSeconds -gt 30) -and (([DateTime]::UtcNow - $S.SvcAsk).TotalSeconds -gt 30)) { $S.SvcAsk = [DateTime]::UtcNow; Start-BgWork 'svc' }
    if ($S.SvcMap.Count -eq 0) { return }
    $rows = [NetEtw]::TakeTotals()
    if ($rows.Count -eq 0) { return }
    $day = (Get-Date).ToString('yyyy-MM-dd', $invc)
    foreach ($row in $rows) {
        $rx = [double]$row[1]
        $tx = [double]$row[2]
        if (($rx + $tx) -le 0) { continue }
        $c = Get-ProcClass ([int]$row[0])
        $key = $day + '|' + [string]$c[0] + '|' + (Clean-AppName ([string]$c[1]))
        if ($S.AppDays.ContainsKey($key)) {
            $v = $S.AppDays[$key]
            $v[0] = $v[0] + $rx
            $v[1] = $v[1] + $tx
        } else {
            $S.AppDays[$key] = [double[]]@($rx, $tx)
        }
    }
    $S.AppDirty = $true
    if ((([DateTime]::UtcNow - $S.AppSaved).TotalSeconds -gt 300)) { Save-AppDays }
}

function Get-TopList([int]$days) {
    $from = (Get-Date).Date.AddDays(-($days - 1)).ToString('yyyy-MM-dd', $invc)
    $acc = @{}
    foreach ($k in $S.AppDays.Keys) {
        if ([string]::CompareOrdinal($k.Substring(0, 10), $from) -lt 0) { continue }
        $v = $S.AppDays[$k]
        $nk = $k.Substring(11)
        if ($acc.ContainsKey($nk)) {
            $a = $acc[$nk]
            $a[0] = $a[0] + $v[0]
            $a[1] = $a[1] + $v[1]
        } else {
            $acc[$nk] = [double[]]@($v[0], $v[1])
        }
    }
    $rows = New-Object System.Collections.ArrayList
    foreach ($nk in $acc.Keys) {
        $a = $acc[$nk]
        [void]$rows.Add(@{ k = $nk.Substring(0, 1); n = $nk.Substring(2); rx = [math]::Round($a[0]); tx = [math]::Round($a[1]) })
    }
    $sorted = @($rows.ToArray() | Sort-Object -Property @{ Expression = { [double]$_.rx + [double]$_.tx } } -Descending | Select-Object -First 10)
    return $sorted
}

function Get-TopPayload {
    return @{ d1 = @(Get-TopList 1); d7 = @(Get-TopList 7); d30 = @(Get-TopList 30) }
}

Load-AppDays

# ---------- Fenetre Historique ----------
$fH1 = New-Object System.Drawing.Font('Segoe UI Semibold', 13)

function Get-NiceMax([double]$v) {
    if ($v -le 0) { return 1.0 }
    $e = [math]::Pow(10, [math]::Floor([math]::Log10($v)))
    $f = $v / $e
    if ($f -le 1) { return 1.0 * $e }
    if ($f -le 2) { return 2.0 * $e }
    if ($f -le 2.5) { return 2.5 * $e }
    if ($f -le 5) { return 5.0 * $e }
    return 10.0 * $e
}

function Format-Axis([double]$v, [string]$unit) {
    if ($unit -eq '%') { return ([math]::Round($v)).ToString('0') + '%' }
    if ($v -ge 100) { return $v.ToString('0') }
    return $v.ToString('0.#')
}

function Draw-Legend($g, [single]$x, [single]$y, $items) {
    $cx = $x
    foreach ($it in $items) {
        $br = New-Object System.Drawing.SolidBrush($it.C)
        $g.FillEllipse($br, $cx, [single]($y + 4), [single]8, [single]8)
        $br.Dispose()
        $g.DrawString([string]$it.N, $fSmall, $bMuted, [single]($cx + 12), [single]$y, $sfTight)
        $tw = $g.MeasureString([string]$it.N, $fSmall, 1000, $sfTight).Width
        $cx = $cx + 12 + $tw + 16
    }
}

function Draw-Chart($g, [int]$x, [int]$y, [int]$w, [int]$h, $series, [double]$maxV, [string]$unit, [double]$startTs, [double]$step, [int]$n, [int]$mode) {
    $px0 = $x + 60
    $py0 = $y + 46
    $pw = $w - 60 - 24
    $ph = $h - 46 - 32
    $gp = New-Object System.Drawing.Pen((Get-Ov 26), [single]1)
    for ($i = 0; $i -le 4; $i++) {
        $gy = $py0 + $ph - $ph * $i / 4.0
        $g.DrawLine($gp, [single]$px0, [single]$gy, [single]($px0 + $pw), [single]$gy)
        $rc = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 6)), ([single]($gy - 8)), ([single]48), ([single]16)
        $g.DrawString((Format-Axis ($maxV * $i / 4.0) $unit), $fSmall, $bMuted, $rc, $sfRight)
    }
    $gp.Dispose()
    for ($i = 0; $i -le 4; $i++) {
        $frac = $i / 4.0
        $tsx = $startTs + $step * ($n - 1) * $frac
        $dtl = [DateTimeOffset]::FromUnixTimeSeconds([long]$tsx).LocalDateTime
        if ($mode -eq 1) { $lab = $dtl.ToString('ddd HH:mm', $frc) } else { $lab = $dtl.ToString('HH:mm', $invc) }
        $rc = New-Object System.Drawing.RectangleF -ArgumentList ([single]($px0 + $pw * $frac - 45)), ([single]($py0 + $ph + 8)), ([single]90), ([single]16)
        $g.DrawString($lab, $fSmall, $bMuted, $rc, $sfCenter)
    }
    $any = $false
    $base = $py0 + $ph
    foreach ($sr in $series) {
        $vals = $sr.V
        $col = $sr.C
        $run = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
        for ($i = 0; $i -le $n; $i++) {
            $v = -1.0
            if ($i -lt $n) { $v = [double]$vals[$i] }
            if ($v -ge 0) {
                $any = $true
                $ptx = $px0 + $pw * $i / [math]::Max(1, $n - 1)
                $pty = $base - [math]::Min(1.0, $v / $maxV) * $ph
                $run.Add((New-Object System.Drawing.PointF([single]$ptx, [single]$pty)))
            } else {
                if ($run.Count -ge 2) {
                    if ($sr.Fill) {
                        $poly = New-Object 'System.Collections.Generic.List[System.Drawing.PointF]'
                        $poly.AddRange($run)
                        $poly.Add((New-Object System.Drawing.PointF([single]$run[$run.Count - 1].X, [single]$base)))
                        $poly.Add((New-Object System.Drawing.PointF([single]$run[0].X, [single]$base)))
                        $fb = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(46, $col.R, $col.G, $col.B))
                        $g.FillPolygon($fb, $poly.ToArray())
                        $fb.Dispose()
                    }
                    $lp = New-Object System.Drawing.Pen($col, [single]1.8)
                    $lp.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
                    $g.DrawLines($lp, $run.ToArray())
                    $lp.Dispose()
                } elseif ($run.Count -eq 1) {
                    $db = New-Object System.Drawing.SolidBrush($col)
                    $g.FillEllipse($db, [single]($run[0].X - 2), [single]($run[0].Y - 2), [single]4, [single]4)
                    $db.Dispose()
                }
                $run.Clear()
            }
        }
    }
    if (-not $any) {
        $rn = New-Object System.Drawing.RectangleF -ArgumentList ([single]$px0), ([single]$py0), ([single]$pw), ([single]$ph)
        $g.DrawString((T 'hist.nodata_period'), $fSmall, $bMuted, $rn, $sfCenter)
    }
}

function Draw-StackRows($g, [int]$x, [int]$y, [int]$w, $items, [string]$key, [int]$rowH, [int]$labW, [int]$valW) {
    $mx = 1.0
    foreach ($it in $items) { $t = [double]$it.rx + [double]$it.tx; if ($t -gt $mx) { $mx = $t } }
    $i = 0
    $bw = $w - 32 - $labW - $valW
    foreach ($it in $items) {
        $ry = $y + $i * $rowH
        $rl = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 16)), ([single]$ry), ([single]$labW), ([single]16)
        $g.DrawString([string]$it.$key, $fSmall, $bMuted, $rl, $sfEll)
        $tot = [double]$it.rx + [double]$it.tx
        $bx = $x + 16 + $labW
        $tr = New-Object System.Drawing.SolidBrush($cTrack)
        $g.FillRectangle($tr, [single]$bx, [single]($ry + 5), [single]$bw, [single]7)
        $tr.Dispose()
        if ($tot -gt 0) {
            $wr = [math]::Max(2.0, $bw * [double]$it.rx / $mx)
            $wt = [math]::Max(2.0, $bw * [double]$it.tx / $mx)
            $b1 = New-Object System.Drawing.SolidBrush($cDl)
            $g.FillRectangle($b1, [single]$bx, [single]($ry + 5), [single]$wr, [single]7)
            $b1.Dispose()
            $b2 = New-Object System.Drawing.SolidBrush($cUl)
            $g.FillRectangle($b2, [single]($bx + $wr), [single]($ry + 5), [single]$wt, [single]7)
            $b2.Dispose()
        }
        $rv = New-Object System.Drawing.RectangleF -ArgumentList ([single]($bx + $bw + 4)), ([single]$ry), ([single]($valW - 4 + 12)), ([single]16)
        $g.DrawString((Format-Bytes $tot), $fRowV, $bText, $rv, $sfRight)
        $i = $i + 1
    }
}

function Draw-TopCard($g) {
    $x = 940
    $w = 334
    Draw-Card $g $x 60 $w 616 ''
    $g.DrawString((T 'hist.top'), $fCardT, $bMuted, [single]($x + 18), [single]74)
    $pills = @(@('d1', (T 'hist.today'), 96), @('d7', (T 'hist.d7'), 82), @('d30', (T 'hist.d30'), 86))
    $pxx = $x + 18
    $lst = New-Object System.Collections.ArrayList
    foreach ($pl in $pills) {
        $path = New-RoundPath $pxx 100 $pl[2] 26 13
        $rc = New-Object System.Drawing.RectangleF -ArgumentList ([single]$pxx), ([single]100), ([single]$pl[2]), ([single]26)
        if ($S.TopRange -eq $pl[0]) {
            $fb = New-Object System.Drawing.SolidBrush($cDl)
            $g.FillPath($fb, $path)
            $fb.Dispose()
            $tb = New-Object System.Drawing.SolidBrush($cBg)
            $g.DrawString([string]$pl[1], $fSmall, $tb, $rc, $sfCenter)
            $tb.Dispose()
        } else {
            $fb = New-Object System.Drawing.SolidBrush($cCard)
            $g.FillPath($fb, $path)
            $fb.Dispose()
            $bp = New-Object System.Drawing.Pen($cBorder, [single]1)
            $g.DrawPath($bp, $path)
            $bp.Dispose()
            $g.DrawString([string]$pl[1], $fSmall, $bMuted, $rc, $sfCenter)
        }
        $path.Dispose()
        [void]$lst.Add(@{ R = $pl[0]; X = $pxx; W = $pl[2] })
        $pxx = $pxx + $pl[2] + 8
    }
    $S.TopPills = $lst.ToArray()
    $items = @()
    if ($S.HistTop -ne $null) { $items = @($S.HistTop[[string]$S.TopRange]) }
    if ($items.Count -eq 0) {
        $g.DrawString((T 'hist.nodata'), $fSmall, $bMuted, [single]($x + 18), [single]150)
    } else {
        $mx = 1.0
        foreach ($it in $items) { $t = [double]$it.rx + [double]$it.tx; if ($t -gt $mx) { $mx = $t } }
        $bw = $w - 36
        $i = 0
        foreach ($it in $items) {
            $ry = 142 + $i * 46
            $tot = [double]$it.rx + [double]$it.tx
            $rl = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 18)), ([single]$ry), ([single]($bw - 84)), ([single]16)
            $g.DrawString(([string]($i + 1) + '.  ' + [string]$it.n), $fSmall, $bText, $rl, $sfEll)
            $rv = New-Object System.Drawing.RectangleF -ArgumentList ([single]($x + 18 + $bw - 84)), ([single]$ry), ([single]84), ([single]16)
            $g.DrawString((Format-Bytes $tot), $fRowV, $bText, $rv, $sfRight)
            $tr = New-Object System.Drawing.SolidBrush($cTrack)
            $g.FillRectangle($tr, [single]($x + 18), [single]($ry + 22), [single]$bw, [single]8)
            $tr.Dispose()
            $kc = $cApp
            if ([string]$it.k -eq 'S') { $kc = $cSvc }
            $kb = New-Object System.Drawing.SolidBrush($kc)
            $g.FillRectangle($kb, [single]($x + 18), [single]($ry + 22), [single]([math]::Max(2.0, $bw * $tot / $mx)), [single]8)
            $kb.Dispose()
            $i = $i + 1
        }
    }
    Draw-Legend $g ($x + 18) 646 @(@{ N = (T 'hist.legend_app'); C = $cApp }, @{ N = (T 'hist.legend_svc'); C = $cSvc })
}

function Get-TopPillAt([int]$mx, [int]$my) {
    if (($my -lt 100) -or ($my -gt 126)) { return '' }
    foreach ($pl in @($S.TopPills)) {
        if (($mx -ge $pl.X) -and ($mx -le ($pl.X + $pl.W))) { return [string]$pl.R }
    }
    return ''
}

function Draw-History($g) {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.DrawString((T 'hist.title'), $fH1, $bText, [single]20, [single]16)

    $pills = @(@('1h', (T 'hist.h1'), 64), @('24h', (T 'hist.h24'), 64), @('7d', (T 'hist.d7'), 84))
    $pxx = 924 - (64 + 64 + 84 + 16)
    $lst = New-Object System.Collections.ArrayList
    foreach ($pl in $pills) {
        $path = New-RoundPath $pxx 14 $pl[2] 32 16
        $rc = New-Object System.Drawing.RectangleF -ArgumentList ([single]$pxx), ([single]14), ([single]$pl[2]), ([single]32)
        if ($S.HistRange -eq $pl[0]) {
            $fb = New-Object System.Drawing.SolidBrush($cDl)
            $g.FillPath($fb, $path)
            $fb.Dispose()
            $tb = New-Object System.Drawing.SolidBrush($cBg)
            $g.DrawString([string]$pl[1], $fRowV, $tb, $rc, $sfCenter)
            $tb.Dispose()
        } else {
            $fb = New-Object System.Drawing.SolidBrush($cCard)
            $g.FillPath($fb, $path)
            $fb.Dispose()
            $bp = New-Object System.Drawing.Pen($cBorder, [single]1)
            $g.DrawPath($bp, $path)
            $bp.Dispose()
            $g.DrawString([string]$pl[1], $fRowV, $bMuted, $rc, $sfCenter)
        }
        $path.Dispose()
        [void]$lst.Add(@{ R = $pl[0]; X = $pxx; W = $pl[2] })
        $pxx = $pxx + $pl[2] + 8
    }
    $S.HistPills = $lst.ToArray()

    $d = $S.HistData
    $tt = $S.HistTot
    $mode = 0
    if (($d -ne $null) -and ($d.range -eq '7d')) { $mode = 1 }

    Draw-Card $g 16 60 908 220 ''
    $g.DrawString((T 'hist.speed'), $fCardT, $bMuted, [single]34, [single]74)
    Draw-Legend $g 150 72 @(@{ N = (T 'hist.recv'); C = $cDl }, @{ N = (T 'hist.sendw'); C = $cUl })
    Draw-Card $g 16 290 908 170 ''
    $g.DrawString((T 'hist.perf'), $fCardT, $bMuted, [single]34, [single]304)
    Draw-Legend $g 190 302 @(@{ N = 'CPU'; C = $aCpu }, @{ N = 'RAM'; C = $aRam }, @{ N = 'GPU'; C = $aGpu })
    if ($d -ne $null) {
        $mxd = 0.0
        foreach ($v in $d.dl) { if ($v -gt $mxd) { $mxd = $v } }
        foreach ($v in $d.ul) { if ($v -gt $mxd) { $mxd = $v } }
        $mx1 = Get-NiceMax ($mxd * 1.05)
        Draw-Chart $g 16 60 908 220 @(@{ V = $d.dl; C = $cDl; Fill = $true }, @{ V = $d.ul; C = $cUl; Fill = $false }) $mx1 'Mbps' ([double]$d.start) ([double]$d.step) ([int]$d.n) $mode
        Draw-Chart $g 16 290 908 170 @(@{ V = $d.cpu; C = $aCpu; Fill = $false }, @{ V = $d.ram; C = $aRam; Fill = $false }, @{ V = $d.gpu; C = $aGpu; Fill = $false }) 100.0 '%' ([double]$d.start) ([double]$d.step) ([int]$d.n) $mode
    }

    Draw-Card $g 16 470 250 206 ''
    $g.DrawString((T 'hist.today_caps'), $fCardT, $bMuted, [single]34, [single]484)
    Draw-Card $g 276 470 330 206 ''
    $g.DrawString((T 'hist.last7'), $fCardT, $bMuted, [single]294, [single]484)
    Draw-Card $g 616 470 308 206 ''
    $g.DrawString((T 'hist.bymonth'), $fCardT, $bMuted, [single]634, [single]484)
    if ($tt -ne $null) {
        $trx = [double]$tt.todayRx
        $ttx = [double]$tt.todayTx
        Draw-Arrow $g 44 531 $true $cDl
        $g.DrawString((Format-Bytes $trx), $fBig, $bText, [single]62, [single]514, $sfTight)
        $g.DrawString((T 'hist.received'), $fSmall, $bMuted, [single]62, [single]544, $sfTight)
        Draw-Arrow $g 44 595 $false $cUl
        $g.DrawString((Format-Bytes $ttx), $fBig, $bText, [single]62, [single]578, $sfTight)
        $g.DrawString((T 'hist.sent'), $fSmall, $bMuted, [single]62, [single]608, $sfTight)
        $g.DrawString((Tf 'hist.total' @((Format-Bytes ($trx + $ttx)))), $fRowV, $bText, [single]34, [single]642, $sfTight)
        Draw-StackRows $g 276 516 330 @($tt.days) 'd' 22 80 70
        Draw-StackRows $g 616 516 308 @($tt.months) 'm' 25 70 70
    }
    Draw-TopCard $g
}

function Hit-History([int]$mx, [int]$my) {
    $tp = Get-TopPillAt $mx $my
    if ($tp -ne '') { $S.TopRange = $tp; if ($S.PnlHist -ne $null) { $S.PnlHist.Invalidate() }; return }
    if (($my -lt 14) -or ($my -gt 46)) { return }
    foreach ($pl in @($S.HistPills)) {
        if (($mx -ge $pl.X) -and ($mx -le ($pl.X + $pl.W))) {
            $S.HistRange = [string]$pl.R
            Refresh-History
            return
        }
    }
}

function Refresh-History {
    try {
        $S.HistData = Get-HistSeries $S.HistRange
        $S.HistTot = Get-HistTotals
        $S.HistTop = Get-TopPayload
        if ($S.PnlHist -ne $null) { $S.PnlHist.Invalidate() }
    } catch { Write-Log ('History: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'rh' }
}

function Show-History {
    if ($S.HistForm -eq $null) {
        $hf = New-Object System.Windows.Forms.Form
        $hf.Text = (T 'hist.title_win')
        $hf.ClientSize = New-Object System.Drawing.Size(1290, 692)
        $hf.StartPosition = 'CenterScreen'
        $hf.FormBorderStyle = 'FixedSingle'
        $hf.MaximizeBox = $false
        $hf.BackColor = $cBg
        try { if ($form.Icon -ne $null) { $hf.Icon = $form.Icon } } catch { }
        $pn = New-Object System.Windows.Forms.Panel
        $pn.Dock = 'Fill'
        $pn.BackColor = $cBg
        Enable-DoubleBuffer $pn
        $pn.Add_Paint({
            param($snd, $pe)
            try { Draw-History $pe.Graphics } catch { Write-Log ('History paint: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'dh' }
        })
        $pn.Add_MouseDown({ param($snd, $me) try { Hit-History $me.X $me.Y } catch { } })
        $pn.Add_MouseMove({
            param($snd, $me)
            $hand = $false
            if ((Get-TopPillAt $me.X $me.Y) -ne '') { $hand = $true }
            if (($me.Y -ge 14) -and ($me.Y -le 46)) {
                foreach ($pl in @($S.HistPills)) { if (($me.X -ge $pl.X) -and ($me.X -le ($pl.X + $pl.W))) { $hand = $true } }
            }
            if ($hand) { $snd.Cursor = [System.Windows.Forms.Cursors]::Hand } else { $snd.Cursor = [System.Windows.Forms.Cursors]::Default }
        })
        $hf.Controls.Add($pn)
        $hf.Add_FormClosing({
            param($snd, $ce)
            if (-not $S.Quitting) { $ce.Cancel = $true; $S.HistForm.Hide() }
        })
        $ht = New-Object System.Windows.Forms.Timer
        $ht.Interval = 30000
        $ht.Add_Tick({ try { if ($S.HistForm.Visible) { Refresh-History } } catch { } })
        $ht.Start()
        $S.HistForm = $hf
        $S.PnlHist = $pn
        $S.HistTimer = $ht
    }
    Refresh-History
    $S.HistForm.Show()
    if ($S.HistForm.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) { $S.HistForm.WindowState = [System.Windows.Forms.FormWindowState]::Normal }
    $S.HistForm.Activate()
}

# Mesures en direct
if ($S.EtwOk) {
    try { [NetEtw]::Start((Join-Path $cfgDir 'etw')) } catch { $S.EtwOk = $false; $S.EtwStatus = $_.Exception.Message }
}
try { Update-Adapters } catch { }
$monTimer = New-Object System.Windows.Forms.Timer
$monTimer.Interval = 1000
$monTimer.Add_Tick({ try { Update-Mon } catch { Write-Log ('Update-Mon: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')') 'um' } })
$monTimer.Start()

# Telecommande iPhone
$remoteOn = Start-Remote
function Get-FootText {
    $lanIp = Get-LanIp
    if ($S.Listener -ne $null) {
        if ($lanIp) { $t = (Tf 'foot.remote' @(('https://' + $lanIp + ':' + $RemotePort), $S.Pin)) }
        else { $t = (Tf 'foot.noip' @($RemotePort, $S.Pin)) }
    } else { $t = (Tf 'foot.off' @($S.RemoteError)) }
    if (($S.Listener -ne $null) -and ($S.RemoteError -ne '')) { $t = $t + "`n" + '(' + $S.RemoteError + ')' }
    return $t
}
$lblFoot.Text = (Get-FootText)
$netTimer = New-Object System.Windows.Forms.Timer
$netTimer.Interval = 200
$netTimer.Add_Tick({ try { Poll-Remote } catch { Write-Log ('Remote: ' + $_.Exception.Message) 'pr' }; try { if ($showEvt.WaitOne(0)) { Show-Main } } catch { } })
$netTimer.Start()
$form.Add_FormClosing({
    param($sender, $ce)
    if (-not $S.Quitting) {
        $ce.Cancel = $true
        $form.Hide()
        $S.LastTrim = [DateTime]::MinValue
        if (-not $S.BalloonShown) {
            $S.BalloonShown = $true
            try { $tray.ShowBalloonTip(3500, 'ZerkiWatch', (T 'bal.minimized'), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
        }
    }
})
if (-not $BAR.UserHidden) { $barForm.Show() }
if ($WID.On) { $wForm.Show() }
if (-not $startHidden) { $form.Show() }
if (-not $S.WizDone) {
    $wizTimer = New-Object System.Windows.Forms.Timer
    $wizTimer.Interval = 1500
    $wizTimer.Add_Tick({ $wizTimer.Stop(); try { Show-Wizard } catch { Write-Log ('Wizard: ' + $_.Exception.Message) 'wz' } })
    $wizTimer.Start()
}
if ($S.UpdCheck) {
    $updTimer = New-Object System.Windows.Forms.Timer
    $updTimer.Interval = 15000
    $updTimer.Add_Tick({
        $updTimer.Stop()
        try {
            $r = Get-LatestRelease
            if (($r -ne $null) -and $r.Newer) { $tray.ShowBalloonTip(6000, 'ZerkiWatch', (Tf 'about.newer' @($r.Tag)), [System.Windows.Forms.ToolTipIcon]::Info) }
        } catch { }
    })
    $updTimer.Start()
}
Update-Mon
Write-Log ('Start v' + $APPVER + ' | native=' + $native + ' theme=' + $themed + ' | bar: hidden_by_user=' + $BAR.UserHidden + ' auto_hidden=' + $BAR.AutoHidden + ' visible=' + $barForm.Visible + ' pos=' + $barForm.Location.X + ',' + $barForm.Location.Y + ' taille=' + $barForm.Width + 'x' + $barForm.Height + ' | ecrans=' + [System.Windows.Forms.Screen]::AllScreens.Count + ' | ETW=' + $S.EtwOk)
if ($BAR.UserHidden) {
    try { $tray.ShowBalloonTip(4000, 'ZerkiWatch', (T 'bal.bar_hidden'), [System.Windows.Forms.ToolTipIcon]::Info) } catch { }
}
if ($S.HkOk) {
    try {
        $S.HkWin = New-Object HotKeyWin
        $S.HkWin.OnHotKey = [Action]{ try { Invoke-HotkeyToggle } catch { Write-Log ('Hotkey: ' + $_.Exception.Message) 'hkt' } }
        Apply-Hotkey
    } catch { Write-Log ('Hotkey unavailable: ' + $_.Exception.Message); $S.HkOk = $false }
}
try {
    if ((Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\Tasks\ModeReseau')) -and (-not (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32\Tasks\ZerkiWatch')))) { Set-Autostart $true }
} catch { }
$appCtx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($appCtx)

# nettoyage a la fermeture
try { $netTimer.Stop(); $monTimer.Stop() } catch { }
Stop-Remote
try { if ($S.EtwOk) { [NetEtw]::Stop() } } catch { }
try { Flush-Minute; Save-Days } catch { }
try { Update-AppAcc; Save-AppDays } catch { }
Save-BarConfig
try { $S.Hw.Stop = $true } catch { }
try { if ($S.HkWin -ne $null) { $S.HkWin.Dispose() } } catch { }
try { $S.Bg.Dispose() } catch { }
try { $tray.Visible = $false; $tray.Dispose() } catch { }
try { $mutex.ReleaseMutex() } catch { }
} catch {
    Write-Log ('FATAL ERROR: ' + $_.Exception.Message + ' (line ' + $_.InvocationInfo.ScriptLineNumber + ')')
    [System.Windows.Forms.MessageBox]::Show((Tf 'err.fatal' @($_.Exception.Message)), 'ZerkiWatch') | Out-Null
}
