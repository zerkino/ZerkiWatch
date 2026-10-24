# Contributing to ZerkiWatch · Contribuer à ZerkiWatch

**English** · [Français](#français)

Thank you for wanting to help! ZerkiWatch is open source (MIT) and **every kind of help is welcome**, from a one-word translation fix to a new feature. You do not need to be an expert: if something is unclear, open an issue and ask.

## Ways to help

| You can… | How |
|---|---|
| 🌍 **Translate** | Add or improve a language: one text file, no code. See [docs/TRANSLATING.md](docs/TRANSLATING.md). |
| 🧪 **Test** | Run it on your PC (Windows 10 / 11, laptop / desktop, different Wi-Fi/VPN set-ups) and tell us what works or not. |
| 🐞 **Report bugs** | Use the *Bug report* issue template. Attach `%APPDATA%\ZerkiWatch\log.txt` (check it for private data first). |
| 💡 **Suggest ideas** | Use the *Feature request* template. |
| 📸 **Share real screenshots** | <a id="screenshots"></a>The desktop images in the README are illustrations. Real captures (`Win + Shift + S`) of your own PC (hide anything private) are very welcome; open a PR replacing the files in `docs/images`. |
| 🔒 **Review security** | See [SECURITY.md](SECURITY.md). |
| 💻 **Write code or docs** | See below. |

Good first things to pick up: translation polish, README improvements, testing on Windows 10 vs 11, real screenshots, a better error message, a new keyboard-shortcut option, dark/light details.

## Development set-up

You only need Windows 10/11 and a text editor (VS Code is fine). No build step.

1. Fork the repository and clone it.
2. Edit `ZerkiWatch.bat`. It is a `.bat` whose first lines start a PowerShell script stored after the `#PSSTART` marker. Run it by double-clicking (accept the administrator prompt).
3. Rules to respect:
   - **The file must stay pure ASCII with Windows (CRLF) line endings.** Non-ASCII characters are not allowed in `ZerkiWatch.bat`; texts shown to users live in `lang/*.txt` and are referenced by key (`T 'menu.quit'`, `Tf 'tip.cpu' @($x)`).
   - **It must run on Windows PowerShell 5.1** (the one shipped with Windows), not only on PowerShell 7.
   - Never hard-code user-visible text in the code: add a key to every file in `lang/` (French and English at least; if you cannot translate the others, copy the English text and say so in the PR — maintainers/community will translate).
   - Keep log messages (`Write-Log`) in English.
4. Before opening a PR run (Windows PowerShell):
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\embed-lang.ps1     # after editing lang\*.txt
   powershell -ExecutionPolicy Bypass -File tools\check-lang.ps1
   powershell -ExecutionPolicy Bypass -File tools\check-syntax.ps1
   ```
   The same checks run automatically on every pull request.
5. Open a pull request describing **what** changed and **how you tested it** (Windows version, what you clicked).

Small, focused pull requests are easier to review than big ones. If you plan a big change, open an issue first so we can talk about it.

## Be kind
Please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Beginners and non-native English speakers are very welcome; French and English are both fine in issues.

---

## Français

Merci de vouloir aider ! ZerkiWatch est open source (MIT) et **toute aide est la bienvenue**, d'une faute corrigée à une nouvelle fonctionnalité. Pas besoin d'être expert : si quelque chose n'est pas clair, ouvrez un ticket et posez la question.

**Façons d'aider** : traduire ([docs/TRANSLATING.md](docs/TRANSLATING.md)), tester sur votre PC, signaler des bugs (modèle *Bug report*, joignez `%APPDATA%\ZerkiWatch\log.txt` après avoir vérifié qu'il ne contient rien de privé), proposer des idées, envoyer de **vraies captures d'écran** (`Win + Maj + S`, dans `docs/images`), relire la sécurité ([SECURITY.md](SECURITY.md)), écrire du code ou de la doc.

**Règles de code** : `ZerkiWatch.bat` doit rester **en ASCII pur avec fins de ligne CRLF**, compatible **Windows PowerShell 5.1** ; aucun texte visible dans le code : on ajoute une clé dans chaque fichier de `lang/` ; messages du journal en anglais. Avant une pull request, lancez `tools\embed-lang.ps1`, `tools\check-lang.ps1` et `tools\check-syntax.ps1` (la CI les relance). Décrivez dans la PR **ce qui change** et **comment vous l'avez testé**.

Merci de respecter le [code de conduite](CODE_OF_CONDUCT.md). Le français et l'anglais sont tous deux acceptés dans les tickets.
