# ADR 0001 — Flutter pour l'application mobile

## Statut

Acceptée — 2026-08

## Contexte

Carlys est avant tout une application mobile de fitness : suivi de séances en
salle, historique, progression, programmes. Elle doit être disponible sur iOS
**et** Android dès le lancement, avec une identité visuelle forte (design system
dédié, animations soignées, mode sombre/OLED) et un usage intensif hors ligne
(voir ADR 0005). L'équipe est réduite : maintenir deux bases de code natives
(Swift + Kotlin) n'est pas soutenable. À moyen terme, des déclinaisons desktop
et web sont envisagées.

## Décision

L'application mobile (`apps/mobile`) est développée avec **Flutter** (Dart,
SDK ^3.6.0), en architecture feature-first (`lib/features/<feature>/{data,domain,presentation}`),
hors du workspace pnpm — c'est un écosystème volontairement séparé, avec sa
propre CI (`mobile-ci.yml`).

## Raisons

- **Une seule base de code** pour iOS et Android, avec un rendu strictement
  identique sur les deux plateformes (moteur de rendu propre, pas de ponts vers
  les widgets natifs).
- **Contrôle total du pixel** : le design system Carlys (`lib/design_system` :
  AppColors, AppTypography, AppTheme clair/sombre/OLED…) reflète fidèlement
  `packages/design-tokens/src/tokens.json` sans dépendre des composants système.
- **Animations** : support de première classe de **Rive** (dépendance `rive`
  déjà en place) et pipeline d'animation performant, essentiel pour une app
  fitness engageante.
- **Extension future** : Flutter cible aussi desktop et web depuis le même code,
  ce qui garde ces options ouvertes sans réécriture.
- Alternatives écartées :
  - **React Native** : aurait mutualisé TypeScript avec l'API/admin, mais le
    rendu repose sur les composants natifs (divergences visuelles iOS/Android),
    le pont natif complique les modules bas niveau (SQLite, tâches de fond), et
    la fidélité d'animation type Rive y est moins bien servie.
  - **Natif Swift + Kotlin** : la meilleure intégration plateforme, mais double
    le coût de développement et de maintenance de chaque fonctionnalité — 
    rédhibitoire pour une petite équipe livrant en tranches verticales.

## Avantages

- Vélocité : chaque fonctionnalité est écrite une fois pour deux plateformes.
- Cohérence visuelle exacte avec les design tokens, sur tous les appareils.
- Écosystème mature pour nos besoins : Riverpod (ADR 0007), Drift (ADR 0008),
  GoRouter, Dio, Freezed, `flutter_secure_storage`, `fl_chart`.
- Outillage solide : hot reload, `flutter analyze`, tests widget, format
  bloquant en CI.

## Inconvénients

- **Dart** s'ajoute à TypeScript : deux langages, deux chaînes d'outillage, pas
  de partage direct de code ni de types avec `packages/api-contracts` (les
  contrats d'API doivent être maintenus en miroir côté Dart).
- Les intégrations très spécifiques à une plateforme (HealthKit, Health Connect,
  widgets d'écran d'accueil, Live Activities) passent par des plugins ou du code
  natif par canal, avec un léger surcoût.
- Taille de binaire supérieure à un équivalent natif minimal.
- Dépendance à la feuille de route de Google pour le SDK.

## Conséquences

- Les dossiers `android/` et `ios/` sont générés par `scripts/bootstrap_mobile.sh`
  (`flutter create`) et l'environnement est injecté via `--dart-define`
  (`CARLYS_FLAVOR`, `CARLYS_API_BASE_URL`).
- La génération de code (Riverpod, Freezed, json_serializable, Drift) devient un
  passage obligé : `dart run build_runner build --delete-conflicting-outputs`.
- FCM et Sentry ne seront ajoutés qu'avec leur configuration réelle (pas de
  dépendance morte), conformément au `pubspec.yaml`.
- Tout partage de logique avec le backend passe par le contrat HTTP documenté,
  jamais par du code partagé.
