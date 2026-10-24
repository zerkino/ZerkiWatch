# Translating ZerkiWatch · Traduire ZerkiWatch

**Adding or improving a language needs no programming**: it is one text file. · *Ajouter ou corriger une langue ne demande aucune programmation : c'est un fichier texte.*

## How it works
All texts live in `lang/<code>.txt` (`fr.txt`, `en.txt`, `es.txt`, `de.txt`, `it.txt`, `pt.txt`). The code asks for a text by key (`menu.quit`), and the app picks the language from the Windows display language, or from the *Language* tray menu. When a key is missing in your language it falls back to English, then French — so a partial translation already works.

## File format
```
# comments start with #
[xx]                      <- your language code (es, de, ja, pt-br …), same as the file name
menu.quit=Quit
tip.cpu=CPU: {0} %        <- {0}, {1}… are values filled in by the program: keep them
foot.remote=Line one\nLine two        <- \n is a line break
```
Save the file as **UTF-8**. Accents and any alphabet are fine (non-ASCII characters are converted automatically when embedding).

## Add a new language
1. Copy `lang/en.txt` to `lang/xx.txt` (xx = [ISO 639-1 code](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes), e.g. `nl`, `pl`, `ja`, `ar`, `tr`).
2. Change the section line to `[xx]` and translate every value after the `=`. Do not touch the keys.
3. Set these special keys:
   - `lang.name` — your language's own name, shown in the menu (e.g. `Nederlands`).
   - `p.days` — 7 comma-separated short weekday names, **starting with Sunday**.
   - `p.dec` — decimal separator on the iPhone page (`.` or `,`).
   - `unit.k`, `unit.m`, `unit.g`, `unit.t` and `p.unit_k/m/g/t` — how KB / MB / GB / TB are written.
4. Keep texts **short** where the English is short: buttons, tabs (`hist.d7`, `p.d7`…), tiles and the ALL-CAPS card titles sit in fixed-size widgets. Test how it looks if you can.
5. Check and embed (Windows PowerShell, from the repository folder):
   ```powershell
   powershell -ExecutionPolicy Bypass -File tools\embed-lang.ps1
   powershell -ExecutionPolicy Bypass -File tools\check-lang.ps1
   ```
   Can't run it? No problem: open a pull request with just `lang/xx.txt`, a maintainer will embed it.
6. Open a pull request. 🎉

### Right-to-left languages
The Windows interface is drawn with standard WinForms/GDI+ controls; right-to-left layout is not supported yet. Translations are still welcome, and help to add RTL support is appreciated.

## Try a translation without rebuilding
Copy your `xx.txt` into a folder named `lang` next to `ZerkiWatch.bat`, or into `%APPDATA%\ZerkiWatch\lang`, and pick the language in the tray menu → *Language*. Files found there are loaded on top of the built-in ones.

## Improving an existing translation
Edit the value in `lang/<code>.txt` and open a pull request. Native-speaker corrections are the most valuable contribution there is.

---
*FR — Copiez `lang/en.txt` en `lang/xx.txt`, remplacez `[en]` par `[xx]`, traduisez les valeurs (jamais les clés), gardez les `{0}`, `{1}` et les `\n`, renseignez `lang.name`, `p.days` (7 jours, commençant par le dimanche), `p.dec` et les unités, puis lancez `tools\embed-lang.ps1` et `tools\check-lang.ps1` — ou ouvrez simplement une pull request avec votre fichier.*
