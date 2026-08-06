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

## Structure

- `lib/app/` — bootstrap, environnement, routeur, observers ;
- `lib/core/` — briques transverses (api, auth, database, erreurs, logs, sync…) ;
- `lib/design_system/` — tokens, thèmes et composants réutilisables
  (source de vérité : `packages/design-tokens`) ;
- `lib/features/` — fonctionnalités en tranches verticales
  (voir `lib/features/README.md`) ;
- `lib/shared/` — modèles, providers et widgets transverses.
