## 🇬🇧 ZerkiWatch 6.1.3
**Network speed in your Windows taskbar + one-click Internet kill switch that keeps your local network (Plex, NAS…).**

- **New: QR code for the iPhone certificate.** *iPhone remote…* → *iPhone certificate* now shows the steps, the SHA-256 fingerprint and a QR code: scan it with the iPhone camera to download the certificate (Safari's "not private" warning is expected until the certificate is installed — see the README).
- **New `ZerkiWatch.exe`:** a tiny launcher (source in `tools/launcher`, no embedded script) that just starts the readable `ZerkiWatch.bat` next to it. It replaces the previous PS2EXE build that Windows Defender flagged as a false positive. It is unsigned: if Windows still warns, run `ZerkiWatch.bat` directly. Build provenance is attested on GitHub.
- **Fix:** the HTTPS certificate could not be created on some PCs ("invalid extension" error). Use 6.1.3 instead of 6.1.
- **iPhone remote now uses HTTPS.** ZerkiWatch creates a local certificate authority on your PC; install it once on your iPhone (tray menu → *iPhone remote…* → *iPhone certificate*, steps in the [README](https://github.com/zerkino/ZerkiWatch#https-certificate-on-the-iphone-one-time)). If the certificate cannot be set up, the remote does not start (no HTTP fallback).
- The password is no longer accepted in the URL, only in the `X-Pin` header: **update your Apple Shortcuts**. After upgrading, re-enter the password once in Safari and re-add the Home Screen icon.
- **New: desktop widget.** Right-click the tray icon → *Desktop widget (movable)*: a second bar you can drag anywhere on the desktop, in addition to the one in the taskbar.
- Everything else from 6.0 is unchanged (6 languages, floating bar, history, per-app bandwidth).

**Download:** `ZerkiWatch-windows.zip` (`ZerkiWatch.exe` launcher + the readable `ZerkiWatch.bat`, the installer and the languages — keep both files together) — or just `ZerkiWatch.bat`. Use `Installer.bat` for shortcuts and start with Windows. The whole program is readable in `ZerkiWatch.bat`; SHA-256 in `SHA256.txt`.

☕ [Support on Ko-fi](https://ko-fi.com/zerkino)

## 🇫🇷 ZerkiWatch 6.1.3
**Le débit réseau dans la barre des tâches Windows + un interrupteur Internet en un clic qui garde le réseau local (Plex, NAS…).**

- **Nouveau : QR code pour le certificat iPhone.** *Télécommande iPhone…* → *Certificat iPhone* affiche maintenant les étapes, l'empreinte SHA-256 et un QR code : scannez-le avec l'appareil photo de l'iPhone pour télécharger le certificat (l'avertissement « connexion non privée » de Safari est normal tant que le certificat n'est pas installé — voir le README).
- **Nouveau `ZerkiWatch.exe` :** un petit lanceur (source dans `tools/launcher`, aucun script embarqué) qui démarre simplement le `ZerkiWatch.bat` lisible placé à côté. Il remplace l'ancienne version PS2EXE que Windows Defender signalait à tort. Il n'est pas signé : si Windows avertit encore, lancez directement `ZerkiWatch.bat`. La provenance du build est attestée par GitHub.
- **Correctif :** le certificat HTTPS ne pouvait pas être créé sur certains PC (erreur « extension non valide »). Utilisez la 6.1.3 plutôt que la 6.1.
- **La télécommande iPhone passe en HTTPS.** ZerkiWatch crée une autorité de certification locale sur votre PC ; installez-la une fois sur l'iPhone (menu de l'icône → *Télécommande iPhone…* → *Certificat iPhone*, étapes dans le [README](https://github.com/zerkino/ZerkiWatch/blob/main/README.fr.md)). Si le certificat ne peut pas être configuré, la télécommande ne démarre pas (pas de repli en HTTP).
- Le mot de passe n'est plus accepté dans l'URL, seulement dans l'en-tête `X-Pin` : **mettez à jour vos Raccourcis Apple**. Après la mise à jour, ressaisissez le mot de passe une fois dans Safari et réajoutez l'icône sur l'écran d'accueil.
- **Nouveau : widget sur le bureau.** Menu de l'icône → *Widget sur le bureau (déplaçable)* : une seconde barre à placer où vous voulez, en plus de celle de la barre des tâches.
- Le reste de la 6.0 est inchangé (6 langues, barre flottante, historique, consommation par application).

**Téléchargement :** `ZerkiWatch-windows.zip` (lanceur `ZerkiWatch.exe` + le `ZerkiWatch.bat` lisible, l'installateur et les langues — gardez les deux fichiers ensemble) — ou simplement `ZerkiWatch.bat`. `Installer.bat` crée les raccourcis et le lancement avec Windows. Tout le programme est lisible dans `ZerkiWatch.bat` ; SHA-256 dans `SHA256.txt`.

☕ [Soutenir sur Ko-fi](https://ko-fi.com/zerkino)
