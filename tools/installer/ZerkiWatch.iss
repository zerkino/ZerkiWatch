; ZerkiWatch installer (Inno Setup 6). Built by .github/workflows/build-exe.yml:
;   ISCC.exe /DAppVer=7.0.0 tools\installer\ZerkiWatch.iss  ->  dist-setup\ZerkiWatch-Setup.exe
; It only copies the same files as the zip, creates shortcuts and registers an uninstaller.
#ifndef AppVer
  #define AppVer "0.0.0"
#endif

[Setup]
AppId={{6F1D2B7A-3C54-4E0B-9B35-5A2E7C9D1F40}
AppName=ZerkiWatch
AppVersion={#AppVer}
AppPublisher=zerkino
AppPublisherURL=https://github.com/zerkino/ZerkiWatch
AppSupportURL=https://github.com/zerkino/ZerkiWatch/issues
AppUpdatesURL=https://github.com/zerkino/ZerkiWatch/releases
DefaultDirName={autopf}\ZerkiWatch
DefaultGroupName=ZerkiWatch
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist-setup
OutputBaseFilename=ZerkiWatch-Setup
SetupIconFile=..\..\ZerkiWatch.ico
UninstallDisplayIcon={app}\ZerkiWatch.ico
LicenseFile=..\..\LICENSE
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "de"; MessagesFile: "compiler:Languages\German.isl"
Name: "it"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "pt"; MessagesFile: "compiler:Languages\Portuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\ZerkiWatch.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\ZerkiWatch.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\ZerkiWatch.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\README.fr.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\lang\*.txt"; DestDir: "{app}\lang"; Flags: ignoreversion
Source: "cleanup.ps1"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\ZerkiWatch"; Filename: "{app}\ZerkiWatch.exe"; IconFilename: "{app}\ZerkiWatch.ico"; AppUserModelID: "zerkino.ZerkiWatch"
Name: "{autodesktop}\ZerkiWatch"; Filename: "{app}\ZerkiWatch.exe"; IconFilename: "{app}\ZerkiWatch.ico"; AppUserModelID: "zerkino.ZerkiWatch"; Tasks: desktopicon

[Run]
Filename: "{app}\ZerkiWatch.exe"; Description: "{cm:LaunchProgram,ZerkiWatch}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\cleanup.ps1"""; Flags: runhidden waituntilterminated; RunOnceId: "ZerkiWatchCleanup"

[Code]
// Close a running ZerkiWatch before files are replaced.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  rc: Integer;
begin
  Exec('powershell.exe', '-NoProfile -ExecutionPolicy Bypass -Command "Get-Process -Name ZerkiWatch -ErrorAction SilentlyContinue | Stop-Process -Force; Get-CimInstance Win32_Process -Filter \"Name=''powershell.exe''\" | Where-Object { $_.CommandLine -like ''*IndexOf(''''#PS''''*'' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"', '', SW_HIDE, ewWaitUntilTerminated, rc);
  Result := '';
end;
