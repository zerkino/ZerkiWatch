# Run by the uninstaller: restores Internet and removes what ZerkiWatch added to Windows.
# User data (history, config, log in %APPDATA%\ZerkiWatch) is kept.
$ErrorActionPreference = 'SilentlyContinue'
Get-Process -Name 'ZerkiWatch' | Stop-Process -Force
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { ([string]$_.CommandLine).Contains("IndexOf('#PS'") } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
foreach ($g in @('ZerkiWatch-LocalOnly', 'ZerkiWatch-Remote', 'ModeReseau-LocalUniquement', 'ModeReseau-Telecommande')) {
    $r = @(Get-NetFirewallRule -Group $g)
    if ($r.Count -gt 0) { $r | Remove-NetFirewallRule }
}
& cmd.exe /c 'netsh.exe http delete sslcert ipport=0.0.0.0:8765 >nul 2>&1'
Get-ChildItem Cert:\LocalMachine\My | Where-Object { ($_.Subject -eq 'CN=ZerkiWatch iPhone remote') -or ($_.Subject -eq 'CN=ZerkiWatch Local CA') } | Remove-Item
Unregister-ScheduledTask -TaskName 'ZerkiWatch' -Confirm:$false
Unregister-ScheduledTask -TaskName 'ModeReseau' -Confirm:$false
