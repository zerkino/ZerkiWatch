# How ZerkiWatch works

`ZerkiWatch.bat` is a polyglot: the first lines are batch code that asks for administrator rights and starts `powershell` with a command that reads the file itself and runs everything after the `#PSSTART` marker. This keeps the project to **one readable file** and avoids any installer or compiled binary.

## Main parts (all in `ZerkiWatch.bat`)
| Part | What it does |
|---|---|
| i18n block | Loads texts from the embedded `lang` data (plus optional external `lang\*.txt`), picks the language, provides `T 'key'` and `Tf 'key' @(args)`. |
| `MN` (C# via `Add-Type`) | Win32 helpers: CPU / memory counters, window dragging, taskbar rectangle, full-screen detection, screen-off, working-set trimming. |
| `NetEtw` (C#) | Starts a Windows ETW trace (`Microsoft-Windows-Kernel-Network` through `logman`) and aggregates bytes per process for the per-app / per-service bandwidth. |
| Firewall logic | Computes "everything except private ranges" as IP intervals and creates two Windows Firewall block rules (in / out), group `ZerkiWatch-LocalOnly`. Removing the group = Internet mode. |
| UI | WinForms + GDI+ custom-drawn window, floating bar, taskbar docking, tray icon and menu, history window. |
| Remote | `HttpListener` on `https://+:8765/` (local CA + server certificate in `Cert:\LocalMachine\My`, bound with `netsh http add sslcert`; no HTTP fallback), a firewall rule limited to `LocalSubnet`, a password check (header `X-Pin` only) with 5-failure / 60 s lock-out, and the web page (`$PageHtml`) built per language by `Build-Page`. |
| History | `history.csv`, `totals.csv`, `apps.csv` in `%APPDATA%\ZerkiWatch`. |

## Languages
`lang/*.txt` are the source of truth. `tools/embed-lang.ps1` copies them (non-ASCII → `\uXXXX`) between `# LANGDATA BEGIN` / `# LANGDATA END` so the app stays a single ASCII file. At run time external `lang` folders can add or override languages. The web page contains `{{p.key}}` tokens (replaced with HTML-escaped text) and a `LG` JavaScript object with all `p.*` texts.

## Conventions
- ASCII only, CRLF, Windows PowerShell 5.1 compatible (no ternary, no `?.`, no 2-D indexing tricks that PowerShell 7 tolerates but 5.1 does not).
- Update the UI from the UI thread; background work uses runspaces / timers.
- Log with `Write-Log` in English.
