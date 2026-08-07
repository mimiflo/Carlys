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
