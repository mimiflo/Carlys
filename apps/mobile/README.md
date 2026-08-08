# carlys_mobile

Application Flutter de Carlys (iOS & Android, desktop préparé).

Voir le [README racine](../../README.md) et
[docs/architecture/mobile.md](../../docs/architecture/mobile.md).

## Première installation

Les dossiers de plateformes (`android/`, `ios/`) ne sont pas versionnés à
l'Étape 1 — ils se génèrent localement :

```bash
cd apps/mobile
flutter create --org com.carlys --project-name carlys_mobile --platforms android,ios .
flutter pub get
```

Ou depuis la racine : `./scripts/bootstrap_mobile.sh`.

## Commandes

```bash
flutter pub get
flutter analyze
flutter test
flutter run \
  --dart-define=CARLYS_FLAVOR=development \
  --dart-define=CARLYS_API_BASE_URL=http://localhost:3000

# Génération de code (Freezed, Riverpod, Drift, JSON) — dès qu'elle sera utilisée :
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs

# Builds de distribution
flutter build apk
flutter build appbundle
flutter build ios
```

## Mode démo (sans serveur)

Le flavor `demo` fait tourner l'application entièrement hors ligne :
session déjà ouverte, catalogue/progression/nutrition servis par les dépôts
en mémoire de `lib/demo/` (exception documentée à la règle « pas de données
codées en dur » — jamais chargés dans les autres flavors). Les séances
restent réelles (Drift local), seule la synchronisation est désactivée.

```bash
flutter run --dart-define=CARLYS_FLAVOR=demo
```

Au premier lancement, la démo présente le parcours de première ouverture
(onboarding, puis proposition Premium et repli gratuit) avant de laisser
entrer : la session démo étant déjà ouverte, l'étape de création de compte
est considérée comme satisfaite. Le parcours ne se rejoue pas ensuite —
pour le revoir, désinstalle l'APK (les préférences locales sont effacées).

Le workflow `demo-apk` (`.github/workflows/demo-apk.yml`, déclenchement
manuel) construit cet APK et le publie sur la release `demo-latest`.

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
fond `#06060C`, chiffres en JetBrains Mono tabulaire, lime réservé à UNE
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
