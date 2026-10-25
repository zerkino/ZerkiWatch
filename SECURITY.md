# Security policy · Sécurité

ZerkiWatch runs as administrator, edits Windows Firewall rules and exposes a small password-protected web page on the local network (port 8765, HTTPS with a local certificate authority). Security reviews are very welcome.

## Reporting a vulnerability
Please **do not** open a public issue for a real vulnerability. Use GitHub's private "Report a vulnerability" button (Security tab of the repository) or contact the maintainer privately through his GitHub profile ([@zerkino](https://github.com/zerkino)). You will get an answer as soon as possible; fixes are credited unless you prefer otherwise.

Examples of what is in scope: bypassing the password or its 5-attempt lock-out, reaching the remote from outside the local subnet, command injection through the API, unsafe file permissions on `%APPDATA%\ZerkiWatch`.

## Known design limits
- The iPhone page uses HTTPS with a certificate issued by a local authority (`ZerkiWatch Local CA`) stored in the Windows machine certificate store; install it on your iPhone only (see README). The authority's private key is non-exportable and stays on the PC; the password is only accepted in the `X-Pin` header, never in the URL. Never forward the port to the Internet.
- The password is stored in clear text in `%APPDATA%\ZerkiWatch\password.txt` (per Windows user).

*FR : ne publiez pas une vraie faille dans un ticket public ; utilisez le signalement privé de GitHub (onglet Security) ou contactez le mainteneur via son profil.*
