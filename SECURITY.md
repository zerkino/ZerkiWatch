# Security policy · Sécurité

ZerkiWatch runs as administrator, edits Windows Firewall rules and exposes a small password-protected web page on the local network (port 8765, plain HTTP). Security reviews are very welcome.

## Reporting a vulnerability
Please **do not** open a public issue for a real vulnerability. Use GitHub's private "Report a vulnerability" button (Security tab of the repository) or contact the maintainer privately through his GitHub profile ([@zerkino](https://github.com/zerkino)). You will get an answer as soon as possible; fixes are credited unless you prefer otherwise.

Examples of what is in scope: bypassing the password or its 5-attempt lock-out, reaching the remote from outside the local subnet, command injection through the API, unsafe file permissions on `%APPDATA%\ZerkiWatch`.

## Known design limits
- The iPhone page uses unencrypted HTTP; anyone who can see your Wi-Fi traffic can read the password. Use a password you do not use anywhere else and never forward the port.
- The password is stored in clear text in `%APPDATA%\ZerkiWatch\password.txt` (per Windows user).

*FR : ne publiez pas une vraie faille dans un ticket public ; utilisez le signalement privé de GitHub (onglet Security) ou contactez le mainteneur via son profil.*
