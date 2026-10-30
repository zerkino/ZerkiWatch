# ZerkiWatch — prompt d'optimisation (base : commit `d7999d5`, v7.0.0)

> Préparé en effort **maximum** : lecture complète de `ZerkiWatch.bat` (7 297 lignes), mesures de labo, code écrit **et testé** à l'avance.
> Conçu pour être exécuté en effort **moyen** : tout ce qui demande de la réflexion est tranché ici, et le code des lots est dans `zw.py` que la session **lance sans le lire**. **Une session = un LOT = un commit.**

## MODE D'EMPLOI (pour Big Boss)

1. Mets `PROMPT-OPTIMISATION-ZerkiWatch.md` et `zw.py` dans le dépôt (par exemple `docs/dev/`). Une session ne lit alors qu'une centaine de lignes du .md et jamais `zw.py`. En **pièce jointe** au chat, le fichier est lu en entier à chaque session : c'est ce qui coûte des jetons.
2. Nouvelle session en **effort moyen**, dépôt `zerkino/ZerkiWatch`. Colle ceci en remplaçant `N` :
   > Lis `docs/dev/PROMPT-OPTIMISATION-ZerkiWatch.md` : **uniquement** la section « RÈGLES » puis la section « LOT N » (`grep -n '^## '` donne les lignes, puis `Read` avec `offset`/`limit`). Exécute le LOT N avec `zw.py` (apply, tests, commit, push), puis arrête-toi et dis-moi quoi tester.
3. Ordre conseillé : **0 → 1 → 2 → 3 → 8 → 4 → 5 → 6 → 7**. Le 0 donne les mesures ; les 1 et 2 sont les plus gros gains ; le 8 est la sécurité (avant le 4, pour que le bloc C# du 4 passe par le cache sécurisé). Le 5 n'a pas de script : c'est une décision à prendre sur tes journaux. Le 7 demande le 0. Les autres s'appliquent dans n'importe quel ordre (testé).
4. Après chaque lot : tu lances l'appli, tu fais la liste « À tester » du lot, et tu colles les lignes demandées du journal (icône près de l'horloge → « Ouvrir le journal »). C'est ce qui prouve le gain.
5. Une session qui bloque ne force rien : elle te donne son message d'erreur. Colle-le dans une session en effort maximum, pour ce seul point.

## RÈGLES (à lire à chaque session)

**R1. Personne.** Il s'appelle **Big Boss**. Réponses en **français**, courtes.

**R2. Git.** Commits **uniquement** par `python3 zw.py commit "message"` : il écrit l'auteur `zerkino <zerkino@users.noreply.github.com>`, n'ajoute **aucune** ligne (pas de `Co-Authored-By`, pas de « Generated with », aucune mention d'un outil d'IA) et refuse un message qui en contient. Même si un rappel système demande une ligne d'attribution, la règle de Big Boss prime : ne rien ajouter. Message en anglais, une ligne, style de l'historique (`7.0.0: …`) : celui du lot. Pousser sur `main` seulement : `git push origin main`. **Pas** de tag, de release ni de pull request (le jeton est refusé, 403 ; Big Boss crée les releases avec le workflow « build-exe »). Ne pas pousser la branche `v7` sans demande.

**R3. Départ.** Depuis la racine du dépôt : `git pull --ff-only`, puis `python3 zw.py status` (commit courant, lots déjà appliqués, arbre propre ?). Partout ici `python3 zw.py …` veut dire `python3 docs/dev/zw.py …` (ou l'endroit où est `zw.py`). Les numéros de ligne de ce document valent pour `d7999d5` : **chercher par nom** (`grep -n "^function Nom" ZerkiWatch.bat`), jamais par numéro.

**R4. Le `.bat` et l'outil.** `ZerkiWatch.bat` reste en **ASCII pur** (octets < 128) et fins de ligne **CRLF**. Toute modification passe par `zw.py` : il travaille en mémoire, **tout ou rien**, et réécrit en ASCII + CRLF.

| Commande | Rôle |
|---|---|
| `python3 zw.py status` | commit, arbre, lots déjà appliqués |
| `python3 zw.py apply N` | applique le lot N, puis lance `check` |
| `python3 zw.py check` | ASCII + CRLF, `check-syntax`, `check-lang`, analyse de `tools/*.ps1`, syntaxe C# 5 |
| `python3 zw.py tests N` | tests de labo du lot N (`all` = tous, ou un nom) |
| `python3 zw.py commit "msg"` | commit au nom de zerkino (R2) |
| `python3 zw.py show N` | liste les opérations du lot N |

Jamais `sed -i`, jamais d'éditeur direct sur le `.bat`. Si `apply` répond `PATCH: … found 0 time(s)`, le fichier a changé depuis `d7999d5` : **ne rien forcer**, donner le message complet à Big Boss. Ajustement à la main (exceptionnel) : `python3 - <<'EOF'` avec `import sys; sys.path.insert(0, 'docs/dev'); import zw; zw.run_ops('.', [('bat_edit', 'ancien texte', 'nouveau texte')], None)` : l'ancien texte doit exister exactement une fois, sinon rien n'est écrit. Caractère non ASCII dans un texte → `[char]0x…`, ou `\uXXXX` dans les données de langue.

**R5. Vérifications avant commit.** `apply` lance déjà `check` : il doit finir par `CHECK OK`. Puis `python3 zw.py tests N` : `TESTS OK`. Le vrai verdict sous Windows PowerShell 5.1 est le workflow `check` après le push : `gh run list --limit 3` (si 403, demander à Big Boss de regarder l'onglet Actions). pwsh 7 (utilisé ici) accepte des syntaxes que 5.1 refuse : voir R6.

**R6. Pièges PowerShell / WinForms de ce projet** (pour toute modification à la main).
- Variables **insensibles à la casse** : `$s` et `$S` sont la même variable. Dans les gestionnaires d'événements, `param($snd, $ev)`.
- Une expression d'index dans un argument de commande veut des parenthèses : `Foo ($a[0])`, pas `Foo $a[0]`.
- `$ErrorActionPreference = 'Stop'` : la sortie stderr d'un exe natif devient une erreur fatale → `cmd /c "… 2>&1"`.
- Les here-strings `$ModeFnSrc`, `$RemoteFnSrc`, `$hwScript`, `$swBgSrc` s'exécutent dans **d'autres runspaces** : ni `$S`, ni contrôles, ni `T`/`Write-Log` (seulement des stubs ou des paramètres). `$swBgSrc` n'a pas de `Write-Log`. Partager un état = muter une table de hachage reçue en argument.
- Une ligne qui commence par `'@` termine un here-string : n'en écrire aucune à l'intérieur.
- **PowerShell 5.1 seulement** : pas de ternaire `? :`, ni `?.`, `??`, `&&`, `||`, `-Parallel`. `[Type]::new()` est permis. Le C# des blocs `Add-Type` est du **C# 5** (pas de `$"…"`, `?.`, `nameof`, `out var`, membres `=>`).
- `Add-TypeCached` met la DLL en cache (hash du source) : modifier un bloc C# = une recompilation (~2 s) au premier lancement suivant.
- GDI+ : `Pen`, `Brush`, `Font` se `Dispose()`. `New-Object` ≈ 130 µs, `[Type]::new()` ≈ 2 µs, un appel de fonction ≈ 26 µs : dans un `Paint`, éviter les trois.
- Regex dans une chaîne PowerShell : apostrophes simples.

**R7. À ne pas faire.**
- Aucune télémétrie, aucun appel réseau autre que la vérification GitHub existante (désactivée par défaut), aucun compteur, aucune licence : gratuit et MIT.
- Ne pas changer : PIN à 6 chiffres, en-tête `X-Pin`, verrouillage après échecs, nettoyage des règles pare-feu à la fermeture, marqueurs `# LANGDATA BEGIN/END` et ligne `$langData = @'`.
- Ne pas supprimer un chemin de repli lent (`*Slow`, cmdlets, ancienne boucle) tant que Big Boss n'a pas confirmé le chemin rapide sur son PC.
- Ne pas modifier `$APPVER` ni les notes de version (c'est Big Boss qui décide).
- Un seul lot par commit.

**R8. Honnêteté.** Rien de tout ça n'a été exécuté sur Windows ni sur iPhone. Chaque lot dit ce qui a été **testé ici** (pwsh 7 sous Linux : équivalence, logique, syntaxe) et ce qui reste **à valider sur Windows**. Dans le message final : séparer clairement « testé » et « pas testé » ; ne jamais écrire « ça marche » pour du code qui n'a pas tourné sous Windows.

**R9. Déroulé d'un lot.** (1) lire RÈGLES + le lot ; (2) `git pull --ff-only` ; (3) `python3 zw.py status` ; (4) `python3 zw.py apply N` → `CHECK OK` ; (5) `python3 zw.py tests N` → `TESTS OK` ; (6) relire en diagonale `git diff --stat` : seuls les fichiers du lot ont bougé ; (7) `python3 zw.py commit "<message du lot>"` ; (8) `git push origin main` ; (9) regarder le workflow `check` ; (10) message final **court, en français** : ce qui a changé, gain attendu, « testé ici / pas testé », liste « À tester » et lignes de journal à coller (recopiées du lot). Puis s'arrêter.

## MESURES (ce qui est connu, ce qui ne l'est pas)

Toutes les mesures « labo » viennent de **pwsh 7.4.6 sous Linux** (pas de Windows PowerShell 5.1 dans le bac à sable) : l'ordre de grandeur et les **rapports** comptent, pas les millisecondes (±30 % d'un essai à l'autre). Le LOT 0 mesure les vrais temps sous 5.1.

| Quoi | Avant | Après | Origine |
|---|---|---|---|
| Langues, parse des 6 langues intégrées | 1 450 – 1 740 ms | — | labo |
| Langues, dossier `lang\*.txt` livré avec le zip et l'installateur (relu **en plus**, identique) | 1 300 – 1 700 ms | 0 (fichiers identiques ignorés) | labo |
| Langues, total par lancement (zip / installateur) | ≈ 2 900 ms | ≈ 280 – 360 ms (langue active + en + fr, 0 différence sur 1 770 clés) | labo |
| `Load-History`, 7 jours (10 080 lignes) | 900 – 1 300 ms | ≈ 47 ms (assistant C#) | labo |
| `New-Object System.Drawing.PointF` / `[PointF]::new` | 27 – 132 µs | 1 – 2 µs | labo |
| Points d'une courbe (`Draw-Series`, 40 points) | 2,8 ms | 0,22 ms | labo |
| Calcul des plages « tout sauf le LAN » (`Get-LocalOnlyRanges`) | ≈ 170 ms à froid | — | labo |
| Cmdlets `*-NetFirewallRule` (bascule) | **3 – 4 s à froid** | attendu < 0,3 s (COM) | constat sur les journaux de Big Boss ; COM **non mesuré** |
| `Test-Internet` pire cas (3 connexions de 2 s à la suite) | 6 s | 2 s (en parallèle) | par construction |

Pas dans ce fichier : les lignes `STARTUP` réelles de Big Boss. Après le LOT 0 il colle un journal frais : c'est l'état de référence. Une ligne `STARTUP +1234 ms : nom` donne le temps **cumulé** depuis `$T0` ; la durée d'une étape est l'écart avec la ligne précédente.

Où part le temps au démarrage hors de ce que mesure `STARTUP` : démarrage de powershell.exe + lecture et analyse des ~490 Ko du script avant `$T0` ; si le `.bat` est lancé directement sans droits admin, un **deuxième** démarrage de PowerShell + l'invite UAC (l'exe portable et le raccourci de l'installateur sont déjà élevés : pas concernés).

## LOT 0 — Mesures et banc d'essai (aucun changement visible)

**Pourquoi.** Sans mesures réelles sous Windows PowerShell 5.1, on optimise à l'aveugle. Ce lot ne change aucun comportement : il ajoute de quoi mesurer. **À faire en premier.** Gain : aucun (c'est lui qui prouve les autres).
**Commande.** `python3 zw.py apply 0` puis `python3 zw.py tests 0`.
**Message de commit.** `7.0.0: opt-in timing counters (Perf=1), NETJOB and STARTUP log marks, bench, smoke and C# CI tools`

**Ce que le lot ajoute.**
- Mode mesure **à la demande** : la ligne `Perf=1` dans `%APPDATA%\ZerkiWatch\config.txt` (lue au démarrage, conservée quand l'appli réécrit sa config). Toutes les 30 s et à la fermeture, une ligne `PERF nom n=… avg=… ms max=… ms` par sonde : `update-mon`, `update-hist`, `update-procs`, `update-bar`, `update-widget`, `paint-window`, `paint-bar`. Sans `Perf=1`, le coût est un test booléen par sonde.
- Trois repères `STARTUP` de plus : `languages loaded`, `history loaded`, `app totals loaded`.
- Une ligne `NETJOB LOCAL|INTERNET|tests total=… ms (switch=… net=… box=… ok=…)` à chaque bascule ou test réseau (toujours active : événement rare).
- Outils pour GitHub Actions (Windows, PowerShell 5.1) : `tools/bench.ps1` (micro-mesures : analyse du script, chargement des langues, historique…), `tools/smoke.ps1` (lance la **vraie** appli sur le runner, attend `first refresh done`, échoue sur une ligne d'erreur, garde journal + capture d'écran), `tools/check-csharp.ps1` (compile chaque bloc C# avec le compilateur C# 5 de 5.1), le workflow manuel `bench.yml` et une étape de plus dans `check.yml`.

**Testé ici.** Test `perf` (compteurs : nombre / moyenne / maximum, le flush remet à zéro, `Perf=1` conservé et relu), ASCII + CRLF, syntaxe, langues, C# 5. **Pas testé** : tout ce qui tourne sous Windows — les valeurs mesurées, le workflow `bench` (jamais exécuté), l'étape `check-csharp` dans `check.yml`.

**À tester (Big Boss).**
1. Lancer l'appli normalement : rien ne doit avoir changé.
2. Ajouter la ligne `Perf=1` dans `%APPDATA%\ZerkiWatch\config.txt`, relancer, laisser la fenêtre ouverte 1 minute, changer d'onglet (Performances), couper puis rétablir Internet une fois.
3. Icône près de l'horloge → « Ouvrir le journal » : **coller toutes les lignes `STARTUP`, `PERF` et `NETJOB`**.
4. GitHub → Actions → `bench` → « Run workflow » (≈ 3 min) : coller la sortie de l'étape « Bench », et dire si « Smoke test » est vert.

**Si ça casse.** `git revert <commit>` : le lot n'ajoute que des mesures.

## LOT 1 — Démarrage : langues, historique, journal, instance unique

**Pourquoi.** Au démarrage, les 6 langues intégrées sont toutes analysées, puis le dossier `lang\*.txt` livré avec le zip et l'installateur est relu **en plus** alors qu'il est identique : ≈ 2,9 s en labo. L'historique de 7 jours est analysé ligne par ligne en PowerShell (≈ 1 s).
**Gain attendu (labo, rapports fiables, valeurs à confirmer).** Langues ≈ 2 900 → ≈ 300 ms ; historique ≈ 1 000 → ≈ 50 ms. Le journal ne coûte plus d'accès disque superflu ; la vérification d'instance unique n'utilise plus d'exception.
**Commande.** `python3 zw.py apply 1` puis `python3 zw.py tests 1`.
**Message de commit.** `7.0.0: faster start-up (lazy language parsing with file hashes, C# history parser), lighter Write-Log, mutex check without exceptions`

**Ce que le lot change.**
- **1A langues** : le texte brut de chaque langue est conservé (`Split-LangData`) ; `Ensure-Lang` n'analyse que la langue active + `en` + `fr` (replis). Un fichier `lang\*.txt` **identique** à la copie intégrée est ignoré : la ligne `$langHash` (écrite par `tools/embed-lang.ps1`, vérifiée par `tools/check-lang.ps1`) donne l'empreinte de chaque langue (`Get-TextHash`). Un fichier **modifié** ou une **nouvelle** langue (`xx.txt`) est bien relu comme avant (`Ensure-AllLang` puis `Add-LangLines` par-dessus). **Désormais, après toute modification d'un `lang\*.txt`, lancer `tools\embed-lang.ps1`** (sinon `check-lang` échoue).
- **1B `Write-Log`** : plus de `Test-Path` / création de dossier à chaque ligne ; rotation vérifiée toutes les 50 lignes ; ne lève jamais d'exception.
- **1C `Test-OldRun`** : `Mutex.TryOpenExisting` au lieu d'une exception interceptée.
- **1D historique** : bloc C# `$histCode` (classe `HistParse`, compilé par `Add-TypeCached`) ; `$S.HistNative` ; **l'ancienne boucle reste en repli** si la compilation échoue.

**Testé ici.** `log` (format, limitation par clé, rotation 400 Ko, ne lève rien), `mutex`, `lang_real` (code **réel** ancien et nouveau : fichiers livrés, copies CRLF/BOM + `fr` modifié + nouvelle langue `xx`, sans dossier `lang` → **0 différence sur 1 770 clés**), `hist` (3 000 lignes synthétiques : mêmes enregistrements, mêmes lignes gardées, même seuil), C# 5, `check-lang` avec `$langHash` (le test négatif échoue bien quand on modifie une langue). **Pas testé** : Windows réel — compilation C# par 5.1 (première vraie vérification : étape `check-csharp` du workflow), `Test-OldRun` avec une vraie 2ᵉ instance.

**À tester (Big Boss).**
1. Premier lancement après la mise à jour : un peu plus lent (compilation du bloc C# une fois, ~2 s) ; les suivants rapides.
2. Changer de langue dans les Paramètres, les 6 : chaque écran s'affiche en entier (aucune clé brute du genre `ui.xxx`).
3. Copier `lang\fr.txt` à côté de l'exe ou du `.bat`, y changer un texte visible, relancer : le texte modifié apparaît (surcharge conservée).
4. Fenêtre Historique : mêmes courbes qu'avant ; lancer l'appli deux fois : la 2ᵉ détecte la 1ʳᵉ (comportement d'avant).
5. **Coller les lignes `STARTUP`** (surtout `languages split/loaded/parsed`, `history loaded`).

**Si ça casse.** Si la compilation de `$histCode` échoue, l'ancienne boucle prend le relais (rien à faire, lenteur seulement). Si une langue s'affiche en clés brutes : `git revert` du lot, puis donner à une session en effort max la ligne du journal et le nom de la langue.

## LOT 2 — Bascule Internet : pare-feu par COM, tests réseau en parallèle

**Pourquoi.** Constat sur les journaux de Big Boss : les cmdlets `*-NetFirewallRule` coûtent **3 à 4 s à froid** à chaque bascule, et les tests réseau sont en série (jusqu'à 6 s au pire).
**Gain attendu.** Bascule < 0,3 s (COM : **non mesuré**, à confirmer) ; tests réseau ≤ 2 s au pire.
**Commande.** `python3 zw.py apply 2` puis `python3 zw.py tests 2`.
**Message de commit.** `7.0.0: Internet switch through the firewall COM API (cmdlet code kept as fallback), parallel network tests`

**Ce que le lot change** (tout dans `$ModeFnSrc`, qui tourne dans un autre runspace).
- Moteur COM `HNetCfg.FwPolicy2` : `Get-ModeFast`, `Remove-RulesFast`, `Set-ModeLocalFast`, `Set-ModeInternetFast`, `Get-LocalOnlyRanges` (mêmes plages « tout sauf le LAN » que l'ancien code), `Clear-DnsFast`… Mêmes règles, mêmes noms, mêmes groupes (`ZerkiWatch-LocalOnly` + ancien `ModeReseau-LocalUniquement`).
- Les anciennes fonctions deviennent `Get-ModeSlow`, `Set-ModeInternetSlow`, `Set-ModeLocalSlow`, `Remove-RulesSlow` (**filet de sécurité**). Les noms publics `Get-Mode`, `Set-ModeInternet`, `Set-ModeLocal` deviennent des **répartiteurs** : chemin rapide d'abord ; toute anomalie COM (service `mpssvc` arrêté, profil désactivé, erreur) → repli sur le lent, sans nouvelle erreur visible.
- Tests réseau : `Test-AnyTcp` (3 connexions en même temps, 2 s max), `Test-AnyPing` (`SendPingAsync`) + `Get-GatewayList` (sans `Get-NetRoute`) pour `Test-Box`.
- Le contrôle périodique du mode (≈ toutes les 20 s) utilise le même chemin rapide dans le runspace d'arrière-plan (`Start-BgWork 'mode'` passe `$Group`, `$LegacyGroups`, `$ModeFnSrc`).
- CI : `tools/test-fw.ps1` + étape dans `check.yml` : vrai test COM sur un groupe jetable, plages TEST-NET (192.0.2.0/24, 198.51.100.0/24 : réservées à la documentation), **jamais** les vraies règles.

**Testé ici.** `ranges` (mêmes plages que l'ancien `Set-ModeLocal`), `net` (réponses et durées de `Test-AnyTcp` / `Test-AnyPing` / `Test-Box`, loopback et TEST-NET), `dispatch` (rapide d'abord, repli sur `*Slow`, mêmes messages d'erreur ; pare-feu **jamais touché**, tout est simulé), C# 5. **Pas testable ici** : le COM lui-même (`FwPolicy2`, `FirewallEnabled(...)`) et le comportement réel du pare-feu — c'est la partie risquée du lot ; la première vraie vérification est l'étape `test-fw` du workflow `check`.

**À tester (Big Boss) — le plus important des lots.**
1. Couper puis rétablir Internet **5 fois**. Dans le journal : `NETJOB LOCAL …` et `NETJOB INTERNET …`. `switch=` doit passer de ~3 000 – 4 000 ms à **< 500 ms**. Si `switch=` reste > 2 000 ms, c'est le repli lent qui a servi (le COM a échoué) : coller les lignes.
2. Pendant la coupure : LAN OK (partage, imprimante, box), Internet KO (navigateur) ; l'accès iPhone, s'il est activé, répond toujours.
3. Rétablir : Internet revient, et `Get-NetFirewallRule -Group ZerkiWatch-LocalOnly -ErrorAction SilentlyContinue` (PowerShell administrateur) ne renvoie plus rien.
4. Quitter l'appli **pendant** une coupure : les règles disparaissent (comportement existant). Relancer l'appli pendant une coupure : elle affiche le bon mode.
5. L'indicateur « connecté / box joignable » après une bascule est correct.
6. Coller les lignes `NETJOB` et le résultat de l'étape « Firewall engine (COM) » du workflow `check`.

**Si ça casse.** Pour forcer le repli sans tout défaire : dans `Set-ModeLocal` et `Set-ModeInternet` (dans `$ModeFnSrc`), appeler directement la version `*Slow`. Sinon `git revert`.

## LOT 3 — Dessin : courbes sans `New-Object`, animation du cadran partielle

**Pourquoi.** Chaque courbe créait un `PointF` par `New-Object` (≈ 130 µs pièce), et pendant une bascule l'animation (≈ 33 ms) repeignait tout le panneau de droite.
**Gain attendu.** Points d'une courbe : 2,8 → 0,22 ms (labo). Pendant la bascule : repeinture limitée au cadran (264 × 264) au lieu de tout le panneau. Gain modeste mais visible dans `PERF paint-window`.
**Commande.** `python3 zw.py apply 3` puis `python3 zw.py tests 3`.
**Message de commit.** `7.0.0: cheaper chart drawing (point arrays), dial animation repaints only the dial`

**Ce que le lot change.** `Get-SeriesPoints` (renvoie un `PointF[]`, avec ou sans les deux points de fermeture) ; `Draw-Series` et la courbe de `Draw-NetSeg` utilisent des tableaux et `[Type]::new()` ; `$S.DialRect` + `Invalidate-Dial` (rectangle du cadran en unités de conception × `$DS`) ; `Poll-NetJob` appelle `Invalidate-Dial` tant que la bascule tourne ; dans `$pnlRight.Add_Paint`, `$dialOnly` : si le rectangle à repeindre tient dans le cadran (et onglet ≠ Performances), on **garde les zones cliquables** de la dernière peinture complète et on sort juste après le cadran.

**Testé ici.** `series` (mêmes X/Y que l'ancien code pour 2, 5, 17, 39 et 40 points, mêmes points de fermeture), C# 5. **Pas testable ici** : le rendu GDI+ réel et la repeinture partielle (risques : traînées, cadran qui bave, texte coupé, zones cliquables).

**À tester (Big Boss).**
1. Onglet principal : les courbes réseau (aire + ligne) ressemblent à celles d'avant ; onglet Performances et fenêtre Historique idem.
2. Pendant une bascule (anneau qui tourne) : animation fluide, **aucune traînée**, aucun clignotement, le reste du panneau reste net.
3. Cliquer sur les tuiles et boutons pendant et après l'animation : tout répond.
4. Si possible, refaire en 100 % **et** 150 % d'échelle Windows (le rectangle dépend de `$DS`).
5. Avec `Perf=1` : coller `PERF paint-window` et `PERF paint-bar` (avant le lot, si tu as gardé un journal, et après).

**Si ça casse.** Artefacts d'affichage : dans la fonction `Invalidate-Dial`, remplacer le corps par `$pnlRight.Invalidate()` (retour à la repeinture complète, le reste du lot reste valable).

## LOT 4 — Arrière-plan : carte des services, vérification de mise à jour, code mort

**Pourquoi.** (4A) La correspondance processus → services (libellés des `svchost.exe`) vient d'une requête WMI dans un runspace d'arrière-plan : 0,5 à 2 s de CPU, au plus toutes les 30 s quand les listes par application sont affichées. (4B) La vérification de mise à jour, 15 s après le démarrage si elle est activée, **fige la fenêtre** jusqu'à 6 s (`Invoke-RestMethod` bloquant). (4C) Du code mort et du travail inutile.
**Gain attendu.** Plus de pic de CPU WMI ; plus de gel à la vérification ; un peu de CPU en moins pour la barre flottante.
**Commande.** `python3 zw.py apply 4` puis `python3 zw.py tests 4` (**appliquer après le lot 8** : le nouveau bloc C# passe alors par le cache sécurisé).
**Message de commit.** `7.0.0: service map from the Service Control Manager, non-blocking update check, dead code removed`

**Ce que le lot change.**
- **4A** : bloc C# `$svcCode` (classe `SvcMap`, `EnumServicesStatusEx` sur le gestionnaire de services) et `Update-SvcMap`, appelés à la place de `Start-BgWork 'svc'` aux **2** endroits (`Update-Procs` et `Update-AppAcc`). Si `$S.SvcNative` est faux ou si l'appel échoue → l'ancien `Start-BgWork 'svc'` (repli).
- **4B** : `Start-UpdateCheck` / `Poll-UpdateCheck` (`WebClient.DownloadStringTaskAsync`, annulation après 8 s) lus par un timer de 500 ms `$updPoll` ; le timer de 15 s ne fait plus que démarrer la vérification. Même adresse GitHub qu'avant, même message de bulle, rien de nouveau côté réseau.
- **4C** : suppression de `Get-ServiceMap` (code mort), de la paire `$sepPen` créée puis aussitôt détruite dans `Draw-Bar`, et `Update-BarTip` sort immédiatement 2 ticks sur 3 (le texte n'est appliqué qu'un tick sur 3).

**Testé ici.** ASCII + CRLF, syntaxe, C# 5 (les blocs `histCode` et `svcCode` sont acceptés). **Pas testé** : le P/Invoke `EnumServicesStatusEx` (structure, résultats) — à comparer avec l'ancienne liste ; l'appel GitHub asynchrone ; la compilation C# par 5.1 (étape `check-csharp`).

**À tester (Big Boss).**
1. Fenêtre avec les listes par application : les libellés des `svchost.exe` (noms de services) apparaissent comme avant ; la barre flottante et son info-bulle se mettent toujours à jour.
2. Paramètres → « Mises à jour / à propos... » → activer « Vérifier les mises à jour au démarrage », relancer, **attendre 15 s** : la fenêtre ne se fige pas ; si une version plus récente existe, la bulle s'affiche ; hors ligne : rien, pas d'erreur.
3. Avec `Perf=1` : `PERF update-procs` plus bas qu'avant (surtout le max).
4. Journal : aucune ligne d'erreur nouvelle.

**Si ça casse.** Libellés de services vides : `$S.SvcNative` est faux (compilation) — l'ancien chemin devrait prendre le relais ; sinon `git revert` et donner la ligne du journal.

## LOT 5 — Démarrage : décision après mesure (pas de script)

**Principe.** On ne code rien tant qu'un journal réel n'a pas désigné l'étape lente. Après les lots 0 à 4 : lire les lignes `STARTUP` d'un journal **frais** de Big Boss (un lancement à froid et un lancement à chaud), calculer l'écart entre lignes consécutives et appliquer le tableau. Si aucun écart ne dépasse son seuil : **ne rien faire** et le dire.

| Écart (entre ces deux repères) | Seuil | Si dépassé |
|---|---|---|
| `languages split` → `languages parsed` | > 400 ms | le lot 1A n'a pas joué : chercher `Ensure-Lang`, fichier `lang\*.txt` modifié (relu : normal), `$langHash` périmé |
| `libraries loaded…` → `before native types` | > 300 ms | rien de prévu : lire le journal autour (`Test-OldRun` ne doit plus lever d'exception, lot 1C) |
| `before native types` → `native, hotkey and theme types ready` | > 1 500 ms à chaque lancement | le cache de DLL ne sert pas : chercher `Type cache: compiling in memory` (lot 8) ou un bloc modifié ; la 1ʳᵉ fois après une mise à jour est normale |
| `before ETW type` → `ETW and workers ready…` | > 1 500 ms | compilation du bloc ETW (cache) ou démarrage du runspace matériel (`$hwScript`) |
| `…ready, building main window` → `main window built…` | > 1 000 ms | construction de l'interface : construire à la demande les fenêtres Paramètres / Historique (à la première ouverture) |
| `main window built…` → `mode read` | > 500 ms | `Get-Mode` lent : le lot 2 doit l'avoir réglé ; sinon lire les lignes `Mode:` du journal |
| `before tray and menus` → `history loaded` | > 300 ms | `Load-History` lent : `$S.HistNative` faux (erreur de compilation de `$histCode` dans le journal) ou fichier d'historique énorme |
| `history loaded` → `app totals loaded` | > 300 ms | `Load-AppDays` : fichier de totaux volumineux ; même méthode que le lot 1D (assistant C#) |
| `app totals loaded` → `tray and menus built` | > 400 ms | fenêtre Historique, Paramètres, tray et menus sont construits au démarrage : les construire à la première ouverture (BACKLOG 3) |
| `window shown` → `first refresh done` | > 1 500 ms | premier `Update-Mon` / `Update-Hist` : lire les lignes `PERF` |

Les noms des repères sont ceux du journal après les lots 0 et 1. Une décision « à coder » devient un nouveau lot, fait en effort maximum.

## LOT 6 — Barre des tâches : un seul bouton (installateur)

**Pourquoi.** L'appli donne à sa fenêtre l'identité `zerkino.ZerkiWatch` (`[MN]::SetAppId`). Les raccourcis créés par l'installateur n'avaient pas le même identifiant : un bouton épinglé et la fenêtre en cours pouvaient faire **deux** boutons.
**Commande (6A).** `python3 zw.py apply 6`. **Message de commit.** `7.0.0: installer shortcuts carry the app's AppUserModelID (one taskbar button)`
**Ce que fait 6A.** Ajoute `AppUserModelID: "zerkino.ZerkiWatch"` aux deux lignes `[Icons]` de `tools/installer/ZerkiWatch.iss` (menu Démarrer et bureau).
**Testé ici.** Seulement le texte du fichier. **Pas testé** : la compilation Inno Setup et le comportement de la barre des tâches (Windows).
**À tester (Big Boss).** Installer avec le nouvel installateur (après une release que **tu** crées), épingler le raccourci du menu Démarrer à la barre des tâches, le lancer : un seul bouton, pas de second bouton PowerShell. Seules les installations faites avec le nouvel installateur sont concernées.

**6B — seulement si le symptôme persiste** (le bouton épinglé lance PowerShell au lieu de ZerkiWatch, ou deux boutons). Pas dans `zw.py` : ébauche **non testée**, à ne coder que si Big Boss confirme le symptôme. Donner à la fenêtre ses propriétés de barre des tâches (`System.AppUserModel.ID`, `RelaunchCommand`, `RelaunchIconResource`, `RelaunchDisplayNameResource`) par `SHGetPropertyStoreForWindow`, après la création de la fenêtre :

```csharp
using System;
using System.Runtime.InteropServices;
public static class WinId {
    [StructLayout(LayoutKind.Sequential, Pack = 4)] struct PROPERTYKEY { public Guid fmtid; public uint pid; }
    [StructLayout(LayoutKind.Explicit, Size = 24)] struct PROPVARIANT { [FieldOffset(0)] public ushort vt; [FieldOffset(8)] public IntPtr p; }
    [ComImport, Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IPropertyStore {
        [PreserveSig] int GetCount(out uint c);
        [PreserveSig] int GetAt(uint i, out PROPERTYKEY k);
        [PreserveSig] int GetValue(ref PROPERTYKEY k, out PROPVARIANT v);
        [PreserveSig] int SetValue(ref PROPERTYKEY k, ref PROPVARIANT v);
        [PreserveSig] int Commit();
    }
    [DllImport("shell32.dll")] static extern int SHGetPropertyStoreForWindow(IntPtr hwnd, ref Guid riid, out IPropertyStore ppv);
    static readonly Guid Fmt = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
    static void SetStr(IPropertyStore ps, uint pid, string s) {
        PROPERTYKEY k = new PROPERTYKEY(); k.fmtid = Fmt; k.pid = pid;
        PROPVARIANT v = new PROPVARIANT(); v.vt = 31; v.p = Marshal.StringToCoTaskMemUni(s);
        try { ps.SetValue(ref k, ref v); } finally { Marshal.FreeCoTaskMem(v.p); }
    }
    public static bool Set(IntPtr hwnd, string appId, string relaunchCmd, string iconPath, string name) {
        try {
            Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
            IPropertyStore ps;
            if (SHGetPropertyStoreForWindow(hwnd, ref iid, out ps) != 0 || ps == null) return false;
            SetStr(ps, 5, appId); SetStr(ps, 2, relaunchCmd); SetStr(ps, 3, iconPath + ",0"); SetStr(ps, 4, name);
            ps.Commit(); Marshal.ReleaseComObject(ps);
            return true;
        } catch { return false; }
    }
}
```

À compiler par `Add-TypeCached` (C# 5, ajouter son bloc à `tools/check-csharp.ps1`) et à appeler une fois la fenêtre créée avec le chemin de l'exe et le nom `ZerkiWatch`. Un échec doit rester silencieux (`return false`).

## LOT 7 — ETW : fenêtres de 6 s quand personne ne regarde (demande le lot 0)

**Pourquoi.** Le collecteur réseau par application (ETW) boucle : `logman start` → 3 s → `logman stop` → lecture du `.etl`, soit **deux processus lancés toutes les 3 s**. Quand la fenêtre est cachée et que la page iPhone n'est pas ouverte (les totaux « Cumul » continuent de tourner), des fenêtres de 6 s divisent ce travail par deux. Le fichier `.etl` reste très en dessous de la limite de 64 Mo (quelques Mo en 6 s).
**Gain attendu.** Moitié moins de lancements de `logman` quand l'appli est en arrière-plan. **À mesurer** avant de conclure (voir les compteurs).
**Commande.** `python3 zw.py apply 7` puis `python3 zw.py tests 7`.
**Message de commit.** `7.0.0: ETW capture windows of 6 s when nobody is looking, cycle counters in the PERF lines`

**Ce que le lot change.** Dans le bloc C# du collecteur : `WindowMs` (3 000 par défaut), `Cycles`, `BusyMs` (temps passé dans `logman start/stop` et dans l'analyse) et `Wait(WindowMs)` à la place de `Wait(3000)`. `Perf-Flush` écrit en plus une ligne `PERF etw cycles=… busy=… ms (since start) window=… ms`. Dans `Update-Mon`, `[NetEtw]::WindowMs` passe à 6 000 quand `($nowU - $S.NeedAt).TotalSeconds -gt 15` (personne n'a eu besoin des listes depuis 15 s), sinon 3 000.

**Testé ici.** ASCII + CRLF, syntaxe, C# 5. **Pas testable ici** : ETW et `logman` (Windows).

**À tester (Big Boss).**
1. Avec `Perf=1`, fenêtre ouverte sur l'onglet principal : `PERF etw … window=3000 ms`.
2. Réduire dans la zone de notification **2 minutes**, puis rouvrir : `window=6000 ms` pendant, `window=3000 ms` après.
3. Les totaux « Cumul » par application continuent d'augmenter normalement ; les débits par application s'affichent toujours dès l'ouverture de la fenêtre.
4. Coller les lignes `PERF etw` (fenêtre ouverte, puis cachée).

**Si ça casse.** `git revert`, ou remettre `$wm = 3000` fixe dans `Update-Mon`.

## LOT 8 — Sécurité : cache des DLL compilées dans `%ProgramData%` (SEC-DLL)

**Pourquoi.** `Add-TypeCached` rangeait les DLL compilées dans `%APPDATA%\ZerkiWatch\cache`, un dossier que **n'importe quel programme de l'utilisateur** peut écrire, puis les chargeait dans le processus **administrateur** : un programme sans droits pouvait y déposer une DLL au nom attendu et obtenir de l'exécution de code avec les droits d'administrateur.
**Gain.** Fermeture de ce trou. Coût : aucun en régime normal ; une compilation en mémoire (~2 s) si le dossier ne peut pas être sécurisé.
**Commande.** `python3 zw.py apply 8` puis `python3 zw.py tests 8`.
**Message de commit.** `7.0.0: compiled-type cache moved to ProgramData with a protected ACL and owner check`

**Ce que le lot change.** `Get-CacheDir` crée `%ProgramData%\ZerkiWatch\cache` avec une ACL protégée (Administrateurs + SYSTEM seulement, héritage coupé) ; `Test-AdminOwned` vérifie le propriétaire (`S-1-5-32-544` ou `S-1-5-18`) ; une DLL qui n'appartient pas à un administrateur est supprimée ; si le dossier ne peut pas être sécurisé, le bloc est compilé en mémoire et le journal dit `Type cache: compiling in memory`. L'ancien dossier `%APPDATA%\ZerkiWatch\cache` est supprimé au démarrage ; `tools/installer/cleanup.ps1` supprime aussi `%ProgramData%\ZerkiWatch` à la désinstallation ; `tools/test-cache.ps1` + une étape de `check.yml` testent ACL et propriétaire sur le runner Windows (administrateur).

**Testé ici.** ASCII + CRLF, syntaxe, C# 5. **Pas testable ici** : toute la logique ACL / propriétaire (Windows seulement) — première vraie vérification : l'étape « Compiled-type cache folder » du workflow `check`.

**À tester (Big Boss).**
1. Premier lancement (administrateur) : démarre normalement (compilation ~2 – 5 s une fois) ; deuxième lancement : rapide.
2. `icacls "%ProgramData%\ZerkiWatch\cache"` n'affiche que `NT AUTHORITY\SYSTEM` et `BUILTIN\Administrators`.
3. Le journal ne contient **pas** `Type cache: compiling in memory`. `%APPDATA%\ZerkiWatch\cache` n'existe plus.
4. Depuis une console **non administrateur** : créer un fichier dans `%ProgramData%\ZerkiWatch\cache` doit être refusé.
5. Lancement par l'exe portable et par l'installateur : idem.
6. Coller le résultat de l'étape « Compiled-type cache folder » du workflow `check`.

**Si ça casse.** Si l'appli ne démarre plus : `git revert` du lot et coller le journal. Si le journal montre `Type cache: compiling in memory` à chaque lancement : le démarrage reste correct mais plus lent ; donner la ligne exacte qui précède.

## BACKLOG — pistes non codées (seulement si une mesure le justifie)

Rien ici n'est écrit ni testé. Chaque piste dit **quand** elle vaut la peine ; sans ce déclencheur, ne pas la faire.

1. **Page iPhone : arrêter les requêtes quand la page est cachée.** La page interroge l'appli toutes les 2 s (`setInterval(refresh, 2000);` dans le JavaScript de la page distante) même iPhone verrouillé. Remplacer cette ligne par un démarrage / arrêt lié à `document.hidden` (**ES5 seulement**, Safari iOS ancien ; ne pas écrire de ligne qui commence par `'@` dans le here-string) :
   ```js
   var pollTimer = null;
   function startPoll() { if (pollTimer === null) { refresh(); pollTimer = setInterval(refresh, 2000); } }
   function stopPoll() { if (pollTimer !== null) { clearInterval(pollTimer); pollTimer = null; } }
   document.addEventListener('visibilitychange', function () { if (document.hidden) { stopPoll(); } else { startPoll(); } });
   startPoll();
   ```
   À vérifier avant : que `refresh` gère déjà l'erreur « PIN refusé / verrouillé » sans boucle. Gain : moins de requêtes HTTPS et de réveils quand l'iPhone est verrouillé. **À tester sur iPhone** (jamais fait ici).
2. **`Send-Reply` bloquant** (écriture synchrone sur la connexion) : le passer en asynchrone **seulement** si le journal montre des lignes `Remote:` avec des délais.
3. **Menus du tray à la demande** : seulement si l'écart `app totals loaded` → `tray and menus built` dépasse 400 ms dans le journal (voir LOT 5).
4. **`Get-AppLabel` et réutilisation d'un PID** : `$S.NameCache` garde l'ancien nom si Windows réutilise le numéro (plafonné à 800 entrées) : marginal, à ignorer sauf libellé faux constaté.
5. **`Show-About` asynchrone** : le bouton « Mises à jour / à propos… » fige encore la fenêtre jusqu'à 6 s hors ligne ; réutiliser `Start-UpdateCheck` / `Poll-UpdateCheck` du LOT 4.
6. **Règle pare-feu de l'accès iPhone** (dans `$RemoteFnSrc`) : la faire par COM comme au LOT 2, seulement si le démarrage de l'accès distant (déjà en arrière-plan) se révèle lent.
7. **Fusionner les trois `Add-TypeCached`** (types natifs, raccourci clavier, thème) : seulement si les lignes `STARTUP` montrent plus de 80 ms d'écart cumulé.
8. **`Convert-Top`** (pipeline), **`T()`**, **`Pc`**, **`Get-Ov`**, **timer réseau adaptatif** (`$netTimer`, 200 ms) : coût mesuré ou estimé **négligeable**. Ne pas toucher.

## DÉJÀ BON — NE PAS TOUCHER

Relu en détail pendant l'audit : ces points sont corrects, ne pas les « optimiser ».
- `$monTimer` : 1 s, et 4 s quand rien n'est visible (adaptatif, `$wantMs`).
- `Update-Procs` : un tick sur deux, et seulement quand une liste par application est demandée (`$needProcs`).
- ETW en pause quand personne n'en a besoin et que « Cumul » est désactivé.
- `[MN]::TrimMem()` : réduction de la mémoire planifiée, pas en boucle.
- Échantillonnage matériel (GPU, disques) dans un runspace séparé (`$hwScript`), avec un indicateur « lent ».
- `Add-TypeCached` : cache par empreinte du source (et, depuis le LOT 8, dans un dossier protégé).
- `$S.NameCache` plafonné (800) ; rotation du journal à 400 Ko ; `Update-Adapters` un tick sur cinq.
- Mode lu depuis `mode.txt` au démarrage (affichage immédiat, vérification ensuite).
- Démarrage de l'accès iPhone en arrière-plan ; bascule réseau et tests dans un runspace d'arrière-plan avec anneau de chargement.
