# carlys_mobile

Application Flutter de Carlys (iOS & Android, desktop préparé).

Voir le [README racine](../../README.md) et
[docs/architecture/mobile.md](../../docs/architecture/mobile.md).

## Première installation

Les dossiers de plateformes (`android/`, `ios/`) ne sont pas versionnés — ils
se génèrent localement, depuis la racine du dépôt :

```bash
./scripts/bootstrap_mobile.sh
```

**Ne pas appeler `flutter create` à la main.** Sur un projet existant, il
écrase `pubspec.lock` : sans `--no-pub` il enchaîne un `pub get` qui résout
tout à neuf (28 paquets déplacés ici par rapport au lock du dépôt, dont un
saut de version majeure) ; avec `--no-pub` il laisse à la place le lock du
gabarit. Il recrée aussi `test/widget_test.dart`, qui référence un `MyApp`
inexistant dans ce projet. `scripts/mobile_platforms.sh` — appelé par le
bootstrap **et** par la CI `mobile-recette` — fait la création et répare ces deux
effets de bord : il ne **laisse** derrière lui que les dossiers de plateformes,
`pubspec.lock` étant restauré à l'identique (contenu et droits) et le test du
gabarit retiré :

```bash
./scripts/mobile_platforms.sh android,ios   # android/ et ios/ seuls
```

## Configuration d'exécution (`--dart-define`)

| Variable | Défaut | À quoi elle sert |
| --- | --- | --- |
| `CARLYS_FLAVOR` | `development` | `development`, `staging` ou `production`. |
| `CARLYS_API_BASE_URL` | `http://localhost:3000` | Base de l'API, **sans** le préfixe `/api/v1`. Depuis un émulateur Android, la machine hôte est `10.0.2.2`, jamais `localhost`. |
| `CARLYS_PUBLIC_WEB_BASE_URL` | `http://localhost:3001` | Base de l'application **web publique** (le Next.js d'`apps/admin`), qui sert `/privacy` et `/terms` — les deux pages ouvertes par la section « Légal » des réglages et par la phrase de consentement de l'inscription. C'est la même adresse que le `PUBLIC_APP_URL` du serveur, celle que portent les liens des e-mails : jamais celle de l'API. En `staging` et `production`, le lancement **échoue** si elle est restée au défaut ou pointe en local : livrer deux liens légaux morts est un motif de refus de soumission. |
| `CARLYS_FIREBASE_*` | — | Options push (`API_KEY`, `APP_ID`, `SENDER_ID`, `PROJECT_ID`). Les quatre ensemble ou aucune : sans elles le push est simplement inactif. Voir `config/firebase.example.json`. |

## Commandes

```bash
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=CARLYS_FLAVOR=development \
  --dart-define=CARLYS_API_BASE_URL=http://localhost:3000 \
  --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=http://localhost:3001

# Génération de code — Drift uniquement (un seul fichier engendré) :
dart run build_runner build
dart run build_runner watch

# Builds de distribution
flutter build apk
flutter build appbundle
flutter build ios
```

## Le mode démo a été retiré

Un flavor `demo` (hors ligne, données intégrées, 16 Mo d'images embarquées)
a existé jusqu'en septembre 2026 : il faisait visiter l'interface sans
serveur. Il a été retiré quand la vraie application de recette est devenue
installable en un lien (release `beta`, voir
`docs/deployment/builds-mobiles.md` §3.4) : montrer l'application, c'est
désormais montrer la vraie, branchée sur le serveur de recette — et l'APK a
maigri d'autant. Ses dépôts en mémoire n'ont pas disparu : ils vivent dans
`test/support/` (`in_memory_*.dart`), où ils servent de doublures aux tests
et à la galerie de captures.

## Structure

- `lib/app/` — bootstrap, environnement, routeur, observers ;
- `lib/core/` — briques transverses (api, auth, database, erreurs, logs, sync…) ;
- `lib/design_system/` — tokens, thèmes et composants réutilisables
  (source de vérité : `packages/design-tokens`) ;
- `lib/features/` — fonctionnalités en tranches verticales
  (voir `lib/features/README.md`) ;
- `lib/shared/` — modèles, providers et widgets transverses.

## Modèles de séance

Un **modèle de séance** est une séance type enregistrée : un nom, des
exercices, et pour chacun des séries prévues (répétitions, charge, repos).
On le compose une fois, on le relance en un geste.

- **Y accéder** : depuis l'accueil (« Lancer un modèle », sous le bouton de
  démarrage — c'est là qu'un entraînement commence) ou depuis
  Profil → Entraînement → « Mes modèles de séance ».
- **Composer** : `/templates` → « Nouveau ». Les exercices viennent du
  catalogue (option « exercice libre » comprise) ; chaque série se règle au
  pas-à-pas, se duplique et se réordonne. Le brouillon reste en mémoire
  jusqu'à « Enregistrer » — quitter sans enregistrer demande confirmation.
- **Lancer** : « Lancer » crée une vraie séance pré-remplie, **entièrement
  hors ligne** (séance + plan + mise en file dans une seule transaction
  locale), puis ouvre l'écran de séance active.
- **Dérouler** : l'écran affiche l'objectif de la série en cours
  (« série 2 sur 4 · 8 reps à 60 kg »), amorce le pas-à-pas sur cette cible
  et laisse saisir ce qui a été **réellement** fait. Faire moins que prévu
  n'est ni une erreur ni un blocage : la série est enregistrée telle quelle
  et l'objectif reste consultable dans l'historique.
- **Terminer** : le résumé de clôture constate l'avancement (« 9 séries sur
  12 prévues »), puis la séance rejoint l'historique.

Une séance libre (démarrée sans modèle) garde exactement son comportement.
Contrat détaillé :
[docs/product/workout-templates.md](../../docs/product/workout-templates.md).

## Parcours de première ouverture

Au tout premier lancement, l'application déroule un tunnel avant l'accueil :
onboarding (profil métabolique) → création de compte → proposition Premium
avec repli gratuit explicite. L'étape atteinte est persistée
(`FirstRunStore`, SharedPreferences), le tunnel ne se rejoue jamais une fois
terminé, et tout l'enchaînement passe par la redirection de `go_router`.
Détails : [docs/architecture/mobile.md](../../docs/architecture/mobile.md).

## Refonte « premium dark-first »

L'interface suit le handoff Claude Design (10 écrans, tokens, scènes 3D) :
fond `#08050E`, chiffres en JetBrains Mono tabulaire, orange réservé à UNE
action par écran, violet purement atmosphérique. Les scènes 3D (cœur
battant cardioïde, hélice ADN) sont des `CustomPainter`/`drawVertices`
sans dépendance externe — maillage généré à l'`initState`, buffers
réécrits par frame, pose statique si la réduction d'animations système
est active.

## Captures d'écran

Une galerie d'écrans (données factices, rendu par le moteur de test) se
génère à la demande :

```bash
flutter test tool/screenshots --update-goldens
# → PNG dans apps/mobile/tool/screenshots/goldens/ (ignorés par git)
```
