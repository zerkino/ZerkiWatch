## 🇬🇧 ZerkiWatch 6.1.1
**Network speed in your Windows taskbar + one-click Internet kill switch that keeps your local network (Plex, NAS…).**

- **Fix:** the HTTPS certificate could not be created on some PCs ("invalid extension" error). Use 6.1.1 instead of 6.1.
- **iPhone remote now uses HTTPS.** ZerkiWatch creates a local certificate authority on your PC; install it once on your iPhone (tray menu → *iPhone remote…* → *iPhone certificate*, steps in the [README](https://github.com/zerkino/ZerkiWatch#https-certificate-on-the-iphone-one-time)). If the certificate cannot be set up, the remote does not start (no HTTP fallback).
- The password is no longer accepted in the URL, only in the `X-Pin` header: **update your Apple Shortcuts**. After upgrading, re-enter the password once in Safari and re-add the Home Screen icon.
- **New: desktop widget.** Right-click the tray icon → *Desktop widget (movable)*: a second bar you can drag anywhere on the desktop, in addition to the one in the taskbar.
- Everything else from 6.0 is unchanged (6 languages, floating bar, history, per-app bandwidth).

**Download:** `ZerkiWatch-windows.zip` (contains `ZerkiWatch.exe`, the readable `ZerkiWatch.bat`, the installer and the languages) — or just `ZerkiWatch.bat`.
The `.exe` is not code-signed: Windows SmartScreen may warn ("More info" → "Run anyway"). SHA-256 of the exe is in `SHA256.txt`.

☕ [Support on Ko-fi](https://ko-fi.com/zerkino)

## 🇫🇷 ZerkiWatch 6.1.1
**Le débit réseau dans la barre des tâches Windows + un interrupteur Internet en un clic qui garde le réseau local (Plex, NAS…).**

- **Correctif :** le certificat HTTPS ne pouvait pas être créé sur certains PC (erreur « extension non valide »). Utilisez la 6.1.1 plutôt que la 6.1.
- **La télécommande iPhone passe en HTTPS.** ZerkiWatch crée une autorité de certification locale sur votre PC ; installez-la une fois sur l'iPhone (menu de l'icône → *Télécommande iPhone…* → *Certificat iPhone*, étapes dans le [README](https://github.com/zerkino/ZerkiWatch/blob/main/README.fr.md)). Si le certificat ne peut pas être configuré, la télécommande ne démarre pas (pas de repli en HTTP).
- Le mot de passe n'est plus accepté dans l'URL, seulement dans l'en-tête `X-Pin` : **mettez à jour vos Raccourcis Apple**. Après la mise à jour, ressaisissez le mot de passe une fois dans Safari et réajoutez l'icône sur l'écran d'accueil.
- **Nouveau : widget sur le bureau.** Menu de l'icône → *Widget sur le bureau (déplaçable)* : une seconde barre à placer où vous voulez, en plus de celle de la barre des tâches.
- Le reste de la 6.0 est inchangé (6 langues, barre flottante, historique, consommation par application).

**Téléchargement :** `ZerkiWatch-windows.zip` (contient `ZerkiWatch.exe`, le `ZerkiWatch.bat` lisible, l'installateur et les langues) — ou simplement `ZerkiWatch.bat`.
L'`.exe` n'est pas signé : SmartScreen peut afficher un avertissement (« Informations complémentaires » → « Exécuter quand même »). Le SHA-256 de l'exe est dans `SHA256.txt`.

☕ [Soutenir sur Ko-fi](https://ko-fi.com/zerkino)
