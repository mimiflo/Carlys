# Monter son poste de développement

De zéro à l'application qui tourne sur un émulateur Android, dans VS Code.

Le [README](../../README.md) donne l'installation du monorepo ; ce document
va plus loin sur ce qui n'est pas évident : la chaîne Android, les trois
façons de lancer l'application, et les pièges qui coûtent une soirée.

## 1. Ce qu'il faut installer

| Outil | Version | Pourquoi |
| ----- | ------- | -------- |
| Node.js | ≥ 22 | API et admin |
| pnpm | 10 | `corepack enable` suffit |
| Docker Desktop | récent | PostgreSQL, Redis, Mailpit, MinIO |
| Flutter SDK | stable, Dart ≥ 3.6 | l'application mobile |
| Android Studio | récent | **le SDK et l'émulateur**, même si on code dans VS Code |
| VS Code | récent | l'éditeur |

Android Studio n'est pas un éditeur concurrent ici : on l'installe pour le
**SDK Android**, le **gestionnaire d'appareils virtuels** et les **outils de
build**. On code dans VS Code, on ne rouvre Android Studio que pour créer ou
démarrer un émulateur.

## 2. La chaîne Android, une fois pour toutes

Dans Android Studio, ouvrir **Settings → Languages & Frameworks → Android
SDK** et cocher :

- **Android SDK Platform** (la plus récente installée par défaut) ;
- **Android SDK Command-line Tools** — sans elles, `flutter doctor` refuse de
  valider la licence ;
- **Android SDK Build-Tools** et **Android Emulator**.

Puis, dans un terminal :

```bash
flutter doctor           # dresse la liste de ce qui manque
flutter doctor --android-licenses   # accepter toutes les licences
```

`flutter doctor` doit finir avec une coche verte sur « Android toolchain ».
Tout le reste peut attendre : la coche « Chrome » ou « Xcode » n'empêche pas
de développer pour Android.

### Créer un émulateur

Android Studio → **Device Manager** → **Create Virtual Device**.

- Modèle : **Pixel 7** ou **Pixel 8** — le design est réglé pour un écran de
  393 × 852 points, ces modèles en sont proches.
- Image système : une **API 34 ou 35**, variante *Google APIs*.
- Une fois créé, le démarrer une première fois depuis Android Studio, puis
  le laisser tourner : VS Code le verra dans son sélecteur d'appareil.

En ligne de commande, sans ouvrir Android Studio :

```bash
flutter emulators                    # liste les émulateurs
flutter emulators --launch <id>      # en démarre un
flutter devices                      # vérifie qu'il est vu
```

## 3. Le dépôt

```bash
git clone https://github.com/mimiflo/Carlys.git
cd Carlys
./scripts/setup.sh          # .env, dépendances, Docker, client Prisma
./scripts/bootstrap_mobile.sh   # engendre android/ et ios/, puis pub get
```

`android/` et `ios/` **ne sont pas versionnés** : ils se régénèrent. Toute
retouche faite à la main dedans sera perdue au prochain bootstrap — l'identité
de l'application (nom, icône, permissions, réseau de debug) vit dans
`scripts/android_branding.sh`, que le bootstrap appelle.

Ouvrir le dossier dans VS Code : il proposera les extensions du dépôt
(`.vscode/extensions.json`). Accepter.

## 4. Trois façons de lancer, dans cet ordre

### a. Le mode démo — commence par là

```bash
cd apps/mobile
flutter run --dart-define=CARLYS_FLAVOR=demo
```

Aucun serveur, aucune base : l'application tourne sur des données intégrées.
C'est le test qui prouve que la chaîne Flutter + Android est bonne, **avant**
d'ajouter l'API dans l'équation. Si ça marche, le poste est monté.

Ce mode ne figure volontairement PAS dans les menus de lancement des IDE :
ils ne proposent que la version connectée à l'API, celle qu'on développe et
qu'on livre. La démo garde son utilité ailleurs — tests, galerie de
captures, APK de démonstration.

### b. Avec l'API locale, sur émulateur

```bash
docker compose up -d       # postgres, redis, mailpit, minio
pnpm prisma:migrate        # applique les migrations
pnpm prisma:seed           # exercices, leçons, jeu de départ
pnpm dev:api               # API sur le port 3000
```

Puis, dans un second terminal :

```bash
cd apps/mobile
flutter run \
  --dart-define=CARLYS_FLAVOR=development \
  --dart-define=CARLYS_API_BASE_URL=http://10.0.2.2:3000
```

**`10.0.2.2`, jamais `localhost`.** Depuis un émulateur Android, `localhost`
désigne l'émulateur lui-même : l'API tourne sur la machine hôte, que
l'émulateur joint par l'alias `10.0.2.2`. C'est l'erreur numéro un, et elle
se manifeste par un simple « connexion refusée » qui n'explique rien.

Dans VS Code : `F5` puis **« Carlys »** — l'unique entrée du menu, qui
démarre l'API et l'application ensemble, déjà câblées sur `10.0.2.2`.

### c. Sur un vrai téléphone

Activer les **options pour développeurs** puis le **débogage USB** sur le
téléphone, le brancher, accepter l'autorisation qui s'affiche, vérifier avec
`flutter devices`.

Le téléphone ne connaît ni `localhost` ni `10.0.2.2` : il faut l'**IP du
poste sur le réseau local**, les deux appareils étant sur le même Wi-Fi.

```bash
ipconfig getifaddr en0     # macOS
ip -4 addr show | grep inet  # Linux
ipconfig                    # Windows
```

```bash
flutter run \
  --dart-define=CARLYS_FLAVOR=development \
  --dart-define=CARLYS_API_BASE_URL=http://192.168.1.10:3000
```

Le pare-feu du poste doit laisser entrer le port 3000.

## 5. Les pièges qui coûtent une soirée

**HTTP en clair.** Au-delà d'API 28, Android refuse le trafic non chiffré :
une API locale en `http://` est rejetée avec *« CLEARTEXT communication not
permitted by network security policy »*. `scripts/android_branding.sh` écrit
donc une dérogation dans le jeu de sources `debug/` — elle n'entre jamais
dans une release. Si l'erreur apparaît quand même, c'est que `android/` a été
engendré sans passer par le script : relancer `./scripts/bootstrap_mobile.sh`.

**Le code engendré par Drift.** Il n'est pas versionné : sur un clone frais il
n'existe pas, et `app_database.dart` le déclare en `part`. `bootstrap_mobile.sh`
le produit désormais lui-même ; il reste à le refaire à la main après **toute
modification d'une table locale** :

```bash
cd apps/mobile
dart run build_runner build
```

Sans ça, l'analyse tombe sur deux cents erreurs — `undefined_identifier` sur
chaque table — dont la cause tient en une ligne, la première, qui parle d'un
`part` non engendré.

**Le premier build Gradle est long.** Cinq à dix minutes, le temps de
télécharger la chaîne. Les suivants durent quelques secondes. Ne pas
l'interrompre en croyant à un blocage.

**L'appareil sélectionné, pas celui qu'on croit.** Un lancement ne choisit
jamais l'appareil : c'est le **sélecteur en bas à droite** de VS Code qui
décide. S'il est resté sur `Windows` ou `Edge`, le build part sur une cible
de bureau et échoue sur *« No Windows desktop project configured »* — le
projet ne déclare que `android` et `ios`.

C'est pour ça que `F5` prépare le terrain d'abord (tâche « Préparer
Carlys », `scripts/dev_up.sh`) : un appareil Android prêt avant le build,
et VS Code le choisit de lui-même.

Ce script fait tout le préalable, **et seulement ce qui manque** :

| Étape | Sautée si… |
| --- | --- |
| Remise à niveau du poste | le dépôt n'a pas bougé depuis la dernière fois |
| `docker compose up -d` + attente de PostgreSQL | les conteneurs tournent déjà |
| Migrations | `prisma migrate status` n'en signale aucune en attente |
| Émulateur | un appareil Android répond déjà |

Quand tout est debout, il coûte quelques secondes. Et il ne bloque jamais :
Docker éteint, pas d'AVD, base injoignable — il explique et laisse le
lancement suivre son cours.

Pour viser un autre appareil virtuel :

```bash
CARLYS_AVD=Pixel_7 bash scripts/dev_up.sh
```

**Le port 3000 déjà pris.** L'API refuse de démarrer sans dire par qui :
`lsof -i :3000` (macOS, Linux) ou `netstat -ano | findstr :3000` (Windows).

**`bash` sous Windows n'est pas celui qu'on croit.** PowerShell résout
`bash` vers `C:\Windows\System32\bash.exe` — celui de **WSL**. Sans
distribution Linux installée, il échoue sur *« execvpe(/bin/bash) failed:
No such file or directory »*, une erreur qui n'a rien à voir avec le script
appelé. C'est pourquoi la tâche de préparation passe par
`scripts/dev_up.cmd`, qui va chercher le bash de Git nommément. Même piège
si tu lances un `./scripts/*.sh` toi-même depuis PowerShell : utilise
**Git Bash**.

**Les vérifications avant de commiter.** La CI rejoue exactement ces deux
commandes, dans cet ordre :

```bash
./scripts/check.sh          # TypeScript : build, format, lint, types, tests
./scripts/check_mobile.sh   # Flutter : format, analyse, tests
```

`flutter analyze && flutter test` ne suffit pas : `check_mobile.sh` ajoute
`dart format --set-exit-if-changed`, que la CI applique aussi.

## 6. Le poste se remet à niveau tout seul

`./scripts/setup.sh` installe des hooks git (`scripts/githooks/`, activés
par `core.hooksPath` — donc **local à ton clone**, rien n'est imposé à qui
ne lance pas le script). Après chaque `git pull`, changement de branche ou
rebase, `scripts/after_update.sh` regarde ce qui a bougé et ne relance que
ce qu'il faut :

| Ce qui a changé dans le dépôt | Ce qui se relance |
| --- | --- |
| `package.json`, `pnpm-lock.yaml` | `pnpm install` |
| `packages/**` | build des packages partagés |
| `schema.prisma` | `prisma generate` |
| `prisma/migrations/**` | `prisma migrate` |
| `apps/mobile/pubspec.yaml` | `flutter pub get` |
| `apps/mobile/lib/core/database/**` | `build_runner` |

Le cas le plus sournois est le deuxième : l'API et l'admin consomment les
packages partagés **compilés**. Un pull qui les modifie sans rebuild donne
des `has no exported member` qui n'orientent vers rien.

Le script ne bloque JAMAIS : une base éteinte affiche un avertissement et
la mise à jour se termine quand même. À lancer à la main au besoin :

```bash
pnpm refresh
```

## 7. Travailler au quotidien dans VS Code

- **`r`** dans le terminal de `flutter run` — rechargement à chaud, l'état de
  l'application est conservé. Dans VS Code, l'éclair de la barre de débogage.
- **`R`** — redémarrage à chaud, l'état est perdu : nécessaire après un
  changement de `main()`, de provider global ou de thème.
- **`flutter run` ne recompile pas les assets** ajoutés au `pubspec.yaml` :
  arrêter et relancer.
- L'**inspecteur de widgets** (Flutter DevTools, bouton dans la barre de
  débogage) est le seul moyen honnête de comprendre un débordement de mise en
  page — plus rapide que de lire les contraintes à la main.

## 8. Le graphe de code (Graphify)

Pour poser des questions au dépôt au lieu de le parcourir — et pour que
l'assistant IA dépense ses tokens sur le problème plutôt que sur la lecture
de fichiers.

**En session Claude Code sur le web, il n'y a rien à faire** : le hook
`.claude/hooks/session-start.sh` installe le CLI et reconstruit le graphe à
l'ouverture de la session. Ce qui suit ne concerne qu'un poste local, et
reste facultatif :

```bash
# Une fois par machine (Python requis ; sous Windows : pip install pipx d'abord)
pipx install "graphifyy[sql]"    # ou : uv tool install "graphifyy[sql]"
graphify install                 # enregistre le skill /graphify de l'assistant

# Dans le dépôt, après tout gros changement
graphify update .                # extraction locale tree-sitter, ~1 min, aucun LLM
```

Le résultat vit dans `graphify-out/` (ignoré par git, 100 % reconstructible).
Ensuite : `graphify query "…"`, `graphify god-nodes`, `graphify affected "…"` —
ou taper `/graphify` dans l'assistant.

## 9. Ce que la galerie de captures peut faire pour toi

```bash
cd apps/mobile
flutter test tool/screenshots --update-goldens
```

Elle engendre les PNG de tous les écrans dans
`apps/mobile/tool/screenshots/goldens/` (ignorés par git). C'est plus rapide
que de naviguer dans l'émulateur pour juger un écran, et ça évite de croire
un rendu sur parole. Elle ne tourne **jamais** en CI : les rendus varient
d'une version de moteur à l'autre.
