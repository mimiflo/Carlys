# Architecture — application mobile Flutter

L'application mobile (`apps/mobile`) est le client principal de Carlys :
iOS et Android d'abord, desktop préparé. Elle suit une architecture
**feature-first inspirée de Clean Architecture, sans complexité inutile** :
les frontières interface / logique / données sont strictes, mais on n'ajoute
ni couche ni abstraction qui ne paie pas immédiatement. Ce document décrit
l'état réel à l'Étape 1 (fondation) et les cibles explicitement planifiées.

L'app est volontairement **hors du workspace pnpm** : outillage Flutter
(`flutter pub get`, `build_runner`) et CI dédiée (`.github/workflows/mobile-ci.yml` :
`dart format` bloquant, `flutter analyze`, `flutter test`).

## Arborescence de `lib/`

Structure réelle (les dossiers marqués `∅` existent mais sont encore vides —
ils matérialisent l'emplacement des briques à venir) :

```
lib/
├── main.dart                     # Délègue tout à bootstrap()
├── app/                          # Assemblage de l'application
│   ├── bootstrap.dart            # runZonedGuarded, capture d'erreurs, ProviderScope
│   ├── app.dart                  # CarlysApp : MaterialApp.router, thèmes, locales fr/en
│   ├── environment/
│   │   └── app_environment.dart  # AppEnvironment (--dart-define) + appEnvironmentProvider
│   ├── observers/
│   │   └── app_provider_observer.dart  # Journalisation Riverpod (debug)
│   └── router/
│       ├── app_router.dart       # appRouterProvider (GoRouter)
│       └── app_routes.dart       # Chemins nommés
├── core/                         # Briques transverses, sans logique métier
│   ├── api/          ∅           # Client API Dio + interceptors (Étape 2)
│   ├── auth/         ∅           # Session, tokens (Étape 2)
│   ├── database/     ∅           # Drift/SQLite (Étape 4)
│   ├── errors/                   # AppException (hiérarchie scellée)
│   ├── logging/                  # AppLogger (dart:developer ; Sentry s'y branchera)
│   ├── network/      ∅           # Connectivité (connectivity_plus)
│   ├── permissions/  ∅           # Permissions plateforme
│   ├── security/     ∅           # flutter_secure_storage (Étape 2)
│   ├── synchronization/ ∅        # File de synchronisation (Étape 4)
│   ├── utilities/    ∅
│   └── validators/   ∅
├── design_system/                # Source unique des valeurs visuelles
│   ├── design_system.dart        # Barrel : seul import autorisé depuis les écrans
│   ├── colors/ · typography/ · spacing/ · radius/ · shadows/ · motion/ · icons/
│   ├── theme/                    # AppTheme (clair/sombre/OLED), AppColorSchemes, AppBreakpoints
│   └── components/               # AppButton, AppLoadingIndicator, AppErrorState, AppEmptyState
├── features/                     # Fonctionnalités en tranches verticales
│   ├── README.md                 # Structure data/domain/presentation détaillée
│   ├── onboarding/presentation/screens/splash_screen.dart
│   ├── dashboard/presentation/screens/home_screen.dart
│   ├── workout_template/         # Modèles de séance (prescriptif) → workout_session
│   └── authentication/ · exercises/ · workout_session/ · workout_builder/
│       · workout_history/ · programs/ · progress/ · body_metrics/ · profile/
│       · settings/ · subscriptions/ · notifications/ · coaching/ · health/
│       · nutrition/ · social/    ∅  (réservés, remplis par tranche)
└── shared/                       # Transverse métier (≠ design system générique)
    ├── models/       ∅
    ├── providers/    ∅
    └── widgets/      ∅
```

## Couches et structure d'une fonctionnalité

Chaque fonctionnalité importante suit la structure documentée dans
`lib/features/README.md` :

```
feature/
├── data/
│   ├── datasources/     # API distante (Dio) et base locale (Drift)
│   ├── dto/             # Objets de transfert (json_serializable)
│   ├── mappers/         # DTO/Drift ⇄ entités du domaine
│   └── repositories/    # Implémentations des contrats du domaine
├── domain/
│   ├── entities/        # Objets métier immuables (Freezed)
│   ├── repositories/    # Contrats abstraits
│   ├── services/        # Logique métier pure
│   └── usecases/        # Cas d'usage orchestrant les repositories
└── presentation/
    ├── controllers/     # Contrôleurs Riverpod (état des écrans)
    ├── providers/       # Providers de la fonctionnalité
    ├── screens/         # Écrans
    └── widgets/         # Widgets propres à la fonctionnalité
```

Les dépendances vont dans un seul sens : `presentation → domain ← data`.
Le domaine ne connaît ni Flutter, ni Dio, ni Drift. Une petite fonctionnalité
peut alléger cette structure (pas de use case pour un simple passe-plat),
mais sépare toujours interface / logique / données.

### Règles non négociables

- **Aucun widget n'appelle l'API directement.** Toujours widget → contrôleur
  Riverpod → use case / repository → datasource. Idem pour la base locale.
- **Aucune valeur visuelle en dur.** Couleurs, espacements, rayons, durées,
  icônes : uniquement via le design system (`design_system.dart`). Les écrans
  n'importent jamais un fichier interne du design system ni `Icons.*`.
- **Erreurs converties en frontière.** Les repositories convertissent les
  exceptions brutes (Dio, Drift, plateforme) en `AppException`
  (`core/errors/app_exception.dart` : `NetworkException`, `ServerException`,
  `StorageException`, `UnauthorizedException`, `ValidationException`,
  `UnknownException`). La présentation ne manipule que ces types et choisit
  le texte utilisateur localisé.
- **`const` partout où c'est possible** (imposé par l'analyseur strict —
  `analysis_options.yaml` : strict-casts, strict-inference, strict-raw-types).
- **Reconstructions maîtrisées** : providers granulaires, `select` pour
  n'écouter qu'un fragment d'état, widgets découpés petit, jamais de
  `ref.watch` d'un gros état dans un widget racine.
- **Listes paginées** : toute liste venant de l'API respecte la pagination
  du serveur (20 par défaut, 100 max — `packages/shared-config`) avec
  chargement incrémental côté UI ; jamais de « tout charger ».
- **Aucun secret dans les logs** (`AppLogger` : règle documentée dans le code).

## État et injection de dépendances — Riverpod

- `flutter_riverpod` + `riverpod_annotation` sont en place ;
  `riverpod_generator` et `build_runner` sont installés. La **génération de
  code (annotations `@riverpod`) sera activée dès les premiers contrôleurs**
  (Étape 2) — à l'Étape 1, les rares providers sont déclarés manuellement.
- **`appEnvironmentProvider` est surchargé au bootstrap** via
  `overrideWithValue` avec la configuration lue des `--dart-define`. Sa
  déclaration lève `UnimplementedError` s'il est lu sans override : impossible
  d'utiliser un environnement implicite. Les tests utilisent le même mécanisme
  (`test/app/app_test.dart`).
- Riverpod sert aussi de **conteneur d'injection** : les repositories,
  datasources et clients (Dio, Drift) seront exposés comme providers,
  remplaçables en test par des overrides — pas de framework DI supplémentaire.
- `AppProviderObserver` journalise les mises à jour de providers en debug et
  les échecs en toutes circonstances.
- `bootstrap()` (`lib/app/bootstrap.dart`) encadre tout dans
  `runZonedGuarded`, installe `FlutterError.onError` et loggue les erreurs non
  interceptées ; Sentry s'y branchera avec son DSN par environnement (cible,
  pas de dépendance morte en attendant).

## Navigation — GoRouter

Le routeur est exposé par `appRouterProvider` (`lib/app/router/app_router.dart`)
et consommé par `MaterialApp.router`. Les chemins vivent dans `AppRoutes`.

Deux familles de routes : la **coquille à cinq onglets**
(`StatefulShellRoute.indexedStack`, barre basse visible) et le **plein écran**
(hors coquille), pour tout ce qui demande de la concentration ou une sortie
explicite.

Les cinq onglets — Accueil, Training, Progrès, Academy, Communauté — sont des
**hubs** : une branche peut porter plusieurs routes racines, et un `push` vers
une route sœur de la même branche garde la barre basse visible (le retour
ramène au hub). C'est ainsi que les anciens onglets ont été rangés : la
bibliothèque d'exercices et le Coach IA vivent dans la branche Training, la
nutrition dans la branche Academy, et le profil s'ouvre depuis l'avatar de
l'accueil (plein écran).

| Chemin                  | Nom               | Écran                              |
| ----------------------- | ----------------- | ---------------------------------- |
| `/`                     | `splash`          | `SplashScreen`                     |
| `/login` · `/register` · `/forgot-password` | —  | Authentification    |
| `/home`                 | `home`            | Accueil (onglet)                   |
| `/training`             | `training`        | Hub Training (onglet)              |
| `/exercises`            | `exercises`       | Bibliothèque (branche Training)    |
| `/exercises/:idOrSlug`  | `exercise-detail` | Fiche d'exercice (plein écran)     |
| `/coach`                | `coach`           | Coach IA (branche Training)        |
| `/progress`             | `progress`        | Progression (onglet)               |
| `/academy`              | `academy`         | Academy (onglet)                   |
| `/nutrition`            | `nutrition`       | Nutrition (branche Academy)        |
| `/community`            | `community`       | Communauté (onglet)                |
| `/profile`              | `profile`         | Profil & réglages (plein écran, via l'avatar de l'accueil) |
| `/workout`              | `active-workout`  | Séance active (plein écran)        |
| `/templates`            | `templates`       | Mes modèles de séance (plein écran)|
| `/templates/:templateId`| `template-editor` | Éditeur de modèle (plein écran)    |
| `/programs`             | `programs`        | Programmes multi-semaines (plein écran) |
| `/programs/:programId`  | `program-detail`  | Calendrier d'un programme (plein écran) |
| `/history`              | `history`         | Historique (plein écran)           |
| `/history/:sessionId`   | `workout-detail`  | Détail d'une séance                |
| `/bienvenue`            | `welcome`         | Page de marque, première ouverture |
| `/sessions` · `/subscription` · `/settings` · `/onboarding` | — | Plein écran |

Il n'existe **pas** de route `/templates/new` : créer un modèle, c'est
générer un UUID sur l'appareil puis ouvrir `/templates/<uuid>`. C'est la
traduction directe du principe « identifiants générés hors ligne », et ça
évite la collision de chemins entre `new` et `:templateId`.

### Parcours de première ouverture

Au tout premier lancement, l'application n'ouvre pas l'accueil : elle
déroule un tunnel en quatre temps, entièrement piloté par la **redirection**
du routeur (aucun `push` impératif dispersé dans les écrans).

| Étape          | Écran                      | Sortie                                     |
| -------------- | -------------------------- | ------------------------------------------ |
| `welcome`      | `/bienvenue`               | Le bouton, et lui seul                     |
| `onboarding`   | `/onboarding`              | Répondre ou « Passer » ; « J'ai déjà un compte » mène à `/login` |
| `account`      | `/register` (ou `/login`)  | Session ouverte                            |
| `subscription` | `/subscription`            | Premium, ou repli explicite en version gratuite |
| `done`         | —                          | Comportement normal (session → accueil)    |

- La page de marque ne demande **rien** : ni compte, ni « passer », ni
  échappatoire vers la connexion. On dit qui est Carlys avant de poser la
  première question. Son contenu est décrit dans
  [`docs/product/design-conformity.md`](../product/design-conformity.md).
- L'étape atteinte est persistée dans SharedPreferences
  (`FirstRunStore.stepKey` = `parcours.premiere_ouverture.etape`) : la
  réouverture reprend au bon endroit et le tunnel ne se rejoue **jamais**
  une fois terminé.
- Les réponses d'onboarding sont collectées avant que le compte n'existe :
  elles sont conservées localement
  (`parcours.premiere_ouverture.reponses`) puis reportées sur le profil
  métabolique dès qu'une session est ouverte (`FirstRunController`).
- L'étape effective croise l'étape stockée et l'état de session
  (`FirstRunStep.resolved`) : une session déjà ouverte satisfait l'étape
  « compte » — c'est ce qui permet au **mode démo**, dont le dépôt d'auth
  est toujours connecté, de présenter le tunnel puis de laisser entrer.
- L'écran d'abonnement sert de temps d'arrêt : pendant le tunnel il n'a pas
  de croix de fermeture, met en avant les **droits réels** renvoyés par le
  serveur (aucun tarif : l'API n'en expose pas) et propose explicitement de
  continuer en version gratuite en cas de refus.

Couverture : `test/features/onboarding/first_run_journey_test.dart` et
`test/features/demo/demo_mode_test.dart`.

Cibles planifiées (branchées tranche par tranche) :

- **Navigation principale à cinq destinations** — Accueil, Entraînement,
  Programmes, Progression, Profil — via une shell route ; les icônes
  sémantiques existent déjà (`AppIcons.home`, `workout`, `programs`,
  `progress`, `profile`).
- **Accès rapide à la séance active** (Étape 4) : une séance en cours reste
  joignable en un geste depuis toute l'app (mini-barre persistante).
- **Route de restauration de séance interrompue** (Étape 4) : au démarrage,
  si une séance active existe en base locale, une redirection (`redirect`
  GoRouter) propose de la reprendre — l'emplacement est déjà commenté dans
  `app_router.dart`.
- **Gardes d'authentification** (Étape 2) : redirection vers le flux de
  connexion pour les routes protégées.
- **Navigation adaptative** selon `AppBreakpoints` : barre inférieure en
  `compact`, rail de navigation en `medium`/`expanded`, panneau latéral en
  `large`/`xlarge` — même arbre de routes, seul l'habillage change.

## Design system

`packages/design-tokens/src/tokens.json` est la **source de vérité
multiplateforme** (primaire `#9B30FF`, accent `#FF7A45`, espacements 4→64,
radius, typo, ombres, motion, breakpoints). Le design system Flutter
(`lib/design_system/`) reflète ces valeurs à la main ; un générateur de code
pourra automatiser la synchronisation plus tard (cible).

Fondations actuelles :

| Classe            | Rôle                                                                 |
| ----------------- | -------------------------------------------------------------------- |
| `AppColors`       | Palette (marque, neutres, sémantiques, surfaces clair/sombre/OLED)   |
| `AppTypography`   | Échelle typographique ; fonte système tant que les fontes ne sont pas embarquées dans `assets/fonts` |
| `AppSpacing`      | Espacements `xxs` 4 → `xxxl` 64                                       |
| `AppRadius`       | Rayons 4 → 24 + `full`                                                |
| `AppShadows`      | Ombres sm/md/lg                                                       |
| `AppMotion`       | Durées (100→600 ms) et courbes ; `AppMotion.resolve`                  |
| `AppIcons`        | Icônes sémantiques métier — jamais `Icons.*` dans les écrans          |
| `AppBreakpoints`  | Window size classes M3 (`WindowSize` + extension `context.windowSize`) |
| `AppTheme`        | `light()`, `dark()`, `oledDark()` construits depuis les tokens        |

Thèmes : clair et sombre sont branchés (`themeMode: ThemeMode.system` dans
`CarlysApp`). La variante **OLED (fond noir pur)** existe (`AppTheme.oledDark()`)
et deviendra un choix utilisateur avec la fonctionnalité `settings` (cible).

**Réduction des animations** : toute animation décorative passe par
`AppMotion.resolve(context, duration)`, qui renvoie `Duration.zero` quand le
système demande la réduction des animations (`MediaQuery.disableAnimationsOf`).
Le splash l'applique déjà à son délai de transition.

Composants actuels : `AppButton` (variantes primary/secondary/ghost/destructive,
trois tailles, état de chargement anti-double-soumission, `isExpanded`,
`Semantics` intégré), `AppLoadingIndicator` (libellé accessible),
`AppErrorState` (icône, titre, message, réessai), `AppEmptyState`.

**Feuilles modales** : toute feuille passe par `showAppSheet`
(`design_system/components/app_sheet.dart`) — jamais `showModalBottomSheet`
directement. Le composant garantit ce que chaque feuille réinventait ou
oubliait : navigateur racine (jamais sous la bottom bar flottante), remontée
au-dessus du clavier, et contenu qui s'arrête **au-dessus de la barre système
du téléphone** (SafeArea bas) — le bouton de validation reste atteignable sur
les appareils à navigation 3 boutons comme à geste. Deux styles :
`AppSheetStyle.form` (surface standard, angles `lg`) et `AppSheetStyle.picker`
(surface alternative, angles `cardMain`). Garanti par
`test/design_system/app_sheet_test.dart`, qui simule barre système et clavier.

Composants cibles (créés avec la tranche qui en a besoin) :

| Composant              | Rôle                                                | Étape |
| ---------------------- | --------------------------------------------------- | ----- |
| `AppTextField`         | Champ de saisie standard (validation, erreurs)      | 2     |
| `AppCard`              | Conteneur surface standard                          | 3     |
| `ResponsiveScaffold`   | Scaffold adaptatif (barre/rail/panneau)             | 3–4   |
| `WorkoutCard`          | Carte de séance                                     | 4     |
| `SetInputRow`          | Saisie d'une série (répétitions, charge)            | 4     |
| `RestTimer`            | Minuteur de repos                                   | 4     |
| `MetricCard`           | Indicateur chiffré (progression)                    | 5     |
| `MuscleMap`            | Corps humain interactif (Rive) — **non réalisé**    | 5     |
| `SubscriptionPaywall`  | Écran d'abonnement                                  | 6     |

## Animations

Deux niveaux, tous deux soumis à `AppMotion.resolve` :

1. **Standard Flutter** — transitions implicites/explicites avec les durées et
   courbes d'`AppMotion` uniquement. C'est le niveau par défaut pour tout
   feedback d'interface.
2. **Avancé Rive** — **prévu, pas encore en place** : ni la dépendance
   `package:rive` ni le dossier `assets/rive/` n'existent aujourd'hui. Ce
   niveau est réservé aux moments à forte valeur (illustrations d'onboarding,
   corps humain interactif, célébrations de records).

Les deux scènes animées réellement livrées — le cœur de l'accueil et l'hélice
d'ADN de la nutrition — ne relèvent d'aucun des deux : elles sont rendues par
le moteur 3D logiciel de `design_system/scenes/`, sommet par sommet.

Règles : les animations ne bloquent jamais l'UI ni une action utilisateur
(elles accompagnent, elles ne conditionnent pas) ; elles sont désactivables
(réduction d'animations système respectée) ; les fichiers Rive sont préchargés
hors du fil critique d'affichage. Les dossiers `assets/` existent mais ne sont
déclarés dans `pubspec.yaml` que lorsqu'ils contiennent de vrais fichiers.

## Offline-first

Principe (mise en œuvre à l'Étape 4) : **Drift/SQLite est la source de données
immédiate** — chaque lecture et chaque écriture passent d'abord par la base
locale, l'UI ne dépend jamais du réseau pour afficher ou enregistrer une
séance. Une **file de synchronisation idempotente** (`core/synchronization/`)
rejoue ensuite les écritures vers l'API quand la connectivité le permet
(`connectivity_plus`). Le protocole complet (identifiants `uuid` générés
côté client, idempotence, résolution de conflits) est spécifié dans
[docs/synchronization/offline-first.md](../synchronization/offline-first.md).

## Modèles de séance (`features/workout_template`)

Un **modèle de séance** est un document *prescriptif* réutilisable : un nom,
des lignes d'exercice, et pour chacune des séries prévues (répétitions, charge,
repos). Le lancer crée une **séance** ordinaire — un fait — pré-remplie par le
programme. Contrat complet :
[docs/product/workout-templates.md](../product/workout-templates.md).

Parcours : accueil ou profil → `/templates` → éditeur `/templates/:id` →
« Lancer » → `/workout` → « Terminer » → `/history/:sessionId`.

| Écran / brique                        | Rôle                                                        |
| ------------------------------------- | ----------------------------------------------------------- |
| `TemplatesScreen`                     | Liste locale, temps réel ; état vide, pastille de synchronisation par modèle |
| `TemplateEditorScreen` + `TemplateEditorForm`, `TemplateExerciseTile`, `PlannedSetRow`, `TemplateEditorBottomBar` | Composition : nom, notes, durée, exercices réordonnables, séries prévues au pas-à-pas |
| `TemplateEditorController` (`TemplateDraft`) | Brouillon **en mémoire** ; l'écriture Drift et la mise en file n'ont lieu qu'à « Enregistrer » |
| `guidanceFor(SessionPlan)` (`session_guidance.dart`) | Fonction pure : traduit le plan en consigne d'écran (sur-titre, cible, compteurs) |
| `RecordPlannedSet`                    | Valide une série : appariement au plan → écriture → item honoré |

Points structurants :

- **Les exercices viennent du catalogue existant** (`showExercisePickerSheet`
  de `workout_session`, option « exercice libre » comprise) : composer un
  modèle et saisir une série se font au même endroit.
- **Le lancement est entièrement local** : séance, plan aplati et opération
  `session.create` dans une seule transaction SQLite, aucun appel réseau.
- **La déviation n'est jamais une erreur.** Le pas-à-pas est amorcé sur la
  cible, mais l'utilisateur valide ce qu'il a réellement fait ; la série
  enregistre le réalisé et conserve la cible affichée (`plannedReps` /
  `plannedWeightKg`), ce qui rend l'écart consultable pour toujours dans
  `/history/:sessionId`.
- **Sens de dépendance** : `workout_template → workout_session`, jamais
  l'inverse. Le seul point de contact dans l'autre sens est l'orchestrateur
  `ActiveWorkoutBody`, qui lit `sessionPlanProvider` et le traduit en valeurs
  simples ; ni le domaine, ni les données, ni les widgets de `workout_session`
  ne connaissent les modèles, et sans plan l'écran de séance se comporte
  exactement comme avant.

## Réseau

- **Dio** est le client HTTP (`core/api/`, vide à l'Étape 1), configuré depuis
  `AppEnvironment` : `apiBaseUrl` sans version, `apiV1Url` (= `…/api/v1`) pour
  les routes métier.
- Interceptors cibles (Étape 2) : propagation d'un `x-request-id`
  (`packages/shared-config`), en-tête `Authorization: Bearer`, **renouvellement
  automatique du token d'accès** sur 401 via le refresh token rotatif — une
  seule requête de rafraîchissement en vol, les autres requêtes attendent puis
  rejouent ; en cas d'échec, déconnexion propre.
- Les datasources désérialisent les **enveloppes de réponse** de l'API
  (`{ data, meta, requestId }` / `{ error: { code, message, details, requestId } }`,
  contrats définis dans `packages/api-contracts`) et convertissent les erreurs
  en `AppException` — le code d'erreur serveur pilote le type d'exception.

## Sécurité locale

- Les secrets (tokens de session, Étape 2) vivent exclusivement dans
  **`flutter_secure_storage`** (Keychain iOS / Keystore Android), via
  `core/security/`. Jamais dans SharedPreferences, un fichier ou la base Drift.
- Drift contient des données métier, pas des secrets.
- Aucun token ni secret dans les logs (`AppLogger`) ; les erreurs remontées à
  Sentry (cible) seront filtrées de la même façon.

## Adaptatif et préparation desktop

L'app vise Windows/macOS à terme : **on ne portera pas un écran de téléphone
étiré**, on compose des layouts par classe de taille.

- `WindowSize` (`compact` < 600 < `medium` < 840 < `expanded` < 1200 <
  `large` < 1600 ≤ `xlarge`) est disponible partout via `context.windowSize`.
- Cibles : `ResponsiveScaffold` (barre inférieure / rail / panneau latéral),
  layouts maître-détail en `expanded` et plus (liste d'exercices + détail,
  progression + graphique), largeurs de contenu bornées.
- `scripts/bootstrap_mobile.sh` ne génère aujourd'hui que `android/` et
  `ios/` ; les plateformes desktop seront ajoutées à `flutter create` quand
  la cible sera activée.

## Accessibilité

- **Labels sémantiques** systématiques : `AppButton.semanticLabel`,
  `semanticsLabel` sur `AppLoadingIndicator` et sur les icônes signifiantes
  (déjà en place sur le splash).
- **Tailles de texte dynamiques** : les styles d'`AppTypography` passent par
  `TextTheme`, donc respectent le facteur d'échelle système ; les layouts
  doivent survivre aux grandes tailles (pas de hauteur fixe sur du texte).
- **Zones sûres** : `SafeArea` sur tous les écrans (splash et accueil le font
  déjà).
- **Clavier** : les formulaires gèrent focus, `textInputAction` et défilement
  du champ actif (règle appliquée dès `AppTextField`, Étape 2).
- Cibles de toucher ≥ 48 px (imposé par les thèmes de boutons dans `AppTheme`)
  et réduction d'animations (voir plus haut).

## Tests

En place à l'Étape 1 (exécutés par la CI mobile) :

- `test/app/app_test.dart` — widget test du démarrage complet : `CarlysApp`
  sous `ProviderScope` avec `appEnvironmentProvider` surchargé, splash puis
  navigation vers l'accueil ;
- `test/design_system/app_button_test.dart` — comportement d'`AppButton`
  (tap, désactivation, chargement).

Modèles de séance (interface) :

- `test/features/workout_template/templates_flow_test.dart` — état vide,
  composition d'un modèle depuis le catalogue, enregistrement, puis lancement
  d'une séance pré-remplie ;
- `test/features/workout_template/active_workout_plan_test.dart` — objectif
  affiché (« série 2 sur 4 · 8 reps à 60 kg »), validation d'une série avec
  déviation, saut d'une série, et **non-régression de la séance libre**.

Stratégie cible, par tranche :

| Niveau                  | Portée                                                        |
| ----------------------- | ------------------------------------------------------------- |
| Unitaires domaine       | Entités, services, use cases — purs, sans Flutter             |
| Contrôleurs Riverpod    | `ProviderContainer` + overrides de repositories factices      |
| Widget tests            | Écrans et composants du design system                         |
| Golden tests (cible)    | Composants clés en clair/sombre, plusieurs tailles de texte   |
| Intégration (`integration_test/`) | Scénarios offline/synchronisation : séance enregistrée hors ligne, rejouée à la reconnexion (Étape 4) |

## Plateformes, environnement d'exécution et commandes

Les dossiers de plateformes (`android/`, `ios/`) ne sont **pas versionnés** :
ils se génèrent localement via `./scripts/bootstrap_mobile.sh`, qui exécute
`flutter create --org com.carlys --project-name carlys_mobile
--platforms android,ios .`, puis `flutter pub get` et `flutter analyze`.

La configuration d'exécution est injectée **uniquement par `--dart-define`**
(`lib/app/environment/app_environment.dart`) — aucun fichier d'environnement
embarqué :

| Dart-define           | Valeurs                                   | Défaut                  |
| --------------------- | ----------------------------------------- | ----------------------- |
| `CARLYS_FLAVOR`       | `development` \| `staging` \| `production` (alignés sur les environnements serveur) | `development` |
| `CARLYS_API_BASE_URL` | Base de l'API sans préfixe de version     | `http://localhost:3000` |

```bash
cd apps/mobile
flutter run \
  --dart-define=CARLYS_FLAVOR=development \
  --dart-define=CARLYS_API_BASE_URL=http://localhost:3000

# Génération de code (Riverpod, Freezed, Drift, JSON) — dès qu'elle sera utilisée :
dart run build_runner build

# Builds de distribution (mêmes --dart-define, valeurs de l'environnement visé)
flutter build apk
flutter build appbundle
flutter build ios
```

Firebase Cloud Messaging et Sentry seront ajoutés **avec leur configuration
réelle** (`google-services.json`, DSN) — pas de dépendance morte tant que la
configuration n'existe pas.

## Photos d'exercices

Les illustrations du catalogue ne sont **pas embarquées** dans l'application :
elles sont déposées depuis le back-office et servies par le stockage objet
([ADR 0009](../decisions/0009-use-object-storage-for-media.md)). L'API rend
`imageUrl` sur le résumé d'exercice ; `null` — le cas de la plupart des
mouvements — est un état NORMAL, pas une erreur.

`core/media/` porte les deux pièces :

- `RemoteImageCache` garde les octets en mémoire puis sur le disque. Le cache
  est écrit à la main plutôt qu'emprunté à une bibliothèque parce qu'**une URL
  de média ne change jamais de contenu** : la clé porte l'identifiant du média
  et le serveur répond `immutable`, remplacer une photo revient à en déposer
  une autre. Un cache sans invalidation tient en quelques dizaines de lignes ;
  une dépendance apporterait un mécanisme d'expiration inutile ici. Le nom du
  fichier local est le dernier segment de l'URL, passé au tamis — une URL
  forgée ne peut pas écrire hors du dossier de cache.
- `RemoteImage` affiche la photo, et **le même repli pendant le chargement et
  en cas d'échec** : hors ligne, une illustration manquante ne troue pas la
  page et n'affiche aucun message. C'est un ornement, pas une donnée.

Les deux endroits qui en dépendent — la vignette de la carte et l'en-tête de
la fiche — gardent exactement la même forme avec ou sans photo.

Les images du catalogue sont **détourées** (WebP à canal alpha) : la figure
seule, sans fond. Deux conséquences dans l'interface :

- l'affichage se fait en **`BoxFit.contain`, jamais `cover`** — rogner une
  figure détourée lui couperait les bras et les barres ;
- l'écran fournit le fond. La vignette pose un puits radial sombre
  (`neutral900 → neutral950`) et la fiche garde son dégradé en socle, sinon la
  figure flotterait sur le vide.

Le liseré teinté de la vignette reste réservé à la **pastille de marque**, le
repli affiché quand aucune photo n'est rattachée : autour d'une photo il ferait
un néon coloré. Une photo n'a droit qu'au filet neutre.

