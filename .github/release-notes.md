## ZerkiWatch 7.0.0

### English
**New**
- Redesigned interface: a central dial (its ring follows live traffic; click to cut or restore Internet), tabs Home / Performance, graphite design system, light / dark / auto and four colour themes (midnight blue, violet, green, grey)
- Timed Internet cut (15 / 30 / 60 min or until tomorrow 7:00) with automatic return, also from the iPhone page
- INTERNET / LOCAL label on the floating bar and widget; choose what the bar and widget show, Mini / Full presets
- Settings window, first-run wizard, optional alerts (heavy traffic with the top app, Internet cut for too long)
- iPhone page: light/dark follows the phone, 44 px touch targets, padlock indicator; QR code of the remote address
- About + manual update check (never downloads anything; optional check at startup, off by default)
- Windows installer `ZerkiWatch-Setup.exe` (Start menu, clean uninstall) and a portable zip

**Faster start**: the window shows in about 2 s instead of 13 s (last known mode, background firewall check, iPhone remote prepared in the background, cached helper modules).

**Trust, without paying for a certificate**
- Built by GitHub Actions from this repository, with a signed build attestation: `gh attestation verify ZerkiWatch-Setup.exe --repo zerkino/ZerkiWatch`
- `SHA256.txt` for every file; the program is a readable script, the exe is a tiny launcher and the installer only copies files
- Not code-signed (a certificate costs money): SmartScreen may warn the first time, choose *More info, Run anyway*

Still free, MIT, no telemetry. Early stage: tested mostly by its author, please report problems in Issues.

### Français
**Nouveautés**
- Interface repensée : cadran central (l'anneau suit le débit en direct ; un clic coupe ou rétablit Internet), onglets Accueil / Performances, thème graphite, clair / sombre / auto et quatre thèmes de couleur (bleu nuit, violet, vert, gris)
- Coupure Internet minutée (15 / 30 / 60 min ou jusqu'à demain 7 h) avec retour automatique, aussi depuis la page iPhone
- Mention INTERNET / LOCAL sur la barre flottante et le widget ; choix du contenu de la barre et du widget, presets Mini / Complet
- Fenêtre de réglages, assistant de premier lancement, alertes optionnelles (trafic élevé avec l'appli principale, Internet coupé trop longtemps)
- Page iPhone : clair/sombre selon le téléphone, cibles tactiles de 44 px, indicateur cadenas ; QR code de l'adresse de la télécommande
- À propos + vérification manuelle des mises à jour (ne télécharge jamais rien ; vérification au démarrage optionnelle, désactivée par défaut)
- Installateur Windows `ZerkiWatch-Setup.exe` (menu Démarrer, désinstallation propre) et zip portable

**Démarrage plus rapide** : la fenêtre s'affiche en 2 s environ au lieu de 13 s (dernier mode connu, vérification du pare-feu en arrière-plan, télécommande iPhone préparée en arrière-plan, modules en cache).

**Confiance, sans payer de certificat**
- Construit par GitHub Actions à partir de ce dépôt, avec une attestation de build signée : `gh attestation verify ZerkiWatch-Setup.exe --repo zerkino/ZerkiWatch`
- `SHA256.txt` pour chaque fichier ; le programme est un script lisible, l'exe est un petit lanceur et l'installateur ne fait que copier des fichiers
- Non signé par un certificat de code (payant) : SmartScreen peut avertir la première fois, choisissez *Informations complémentaires, Exécuter quand même*

Toujours gratuit, MIT, sans télémétrie. Stade précoce : testé surtout par son auteur, signalez les problèmes dans Issues.
