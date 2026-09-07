# Fonctionnalités (feature-first)

Chaque fonctionnalité importante suit cette structure. C'est un **plan de
rangement**, pas un inventaire : la mieux fournie n'en occupe que dix dossiers
sur quinze, et le commentaire dit, pour ceux qui prêtent à confusion, ce qu'on
y trouve **aujourd'hui**.

```
feature/
├── data/
│   ├── datasources/     # API distante (Dio) et base locale (Drift)
│   ├── dto/             # Objets de transfert (sérialisation écrite à la main)
│   ├── local/           # Écritures Drift partagées entre fonctionnalités,
│   │                    #   transaction comprise (`workout_session`)
│   ├── mappers/         # DTO/Drift ⇄ entités du domaine
│   ├── repositories/    # Implémentations des contrats du domaine
│   └── services/        # Adaptateurs d'un SDK tiers (`notifications`)
│
├── domain/
│   ├── entities/        # Objets métier immuables (classes à champs `final`)
│   ├── repositories/    # Contrats abstraits
│   ├── services/        # Logique métier pure
│   └── usecases/        # Cas d'usage orchestrant les repositories
│
└── presentation/
    ├── controllers/     # UN Notifier Riverpod par fichier, et rien d'autre
    ├── providers/       # Providers dérivés (Provider, FutureProvider…) qui
    │                    #   ne portent aucun état : la destination prévue
    │                    #   par la règle de CLAUDE.md. N'existe ENCORE dans
    │                    #   aucune fonctionnalité — les fichiers concernés
    │                    #   sont pour l'instant dans `controllers/`
    ├── screens/         # Écrans
    ├── utils/           # Calculs purs de l'écran, sans Riverpod : agrégats,
    │                    #   formatage, seuils (`workout_history`, `progress`)
    └── widgets/         # Widgets propres à la fonctionnalité
```

`controllers/` contre `providers/` — la couture est celle de l'**état**. Un
`Notifier` détient un état et le fait évoluer : il va dans `controllers/`,
seul dans son fichier. Un provider qui ne fait que **lire d'autres providers
et calculer** ne détient rien : il va dans `providers/`. Un calcul qui n'a
même pas besoin de `ref` n'est pas un provider du tout — c'est une fonction,
et sa place est `utils/`.

## Dépendances entre fonctionnalités

Elles sont **nombreuses**, et c'est assumé. Mesure du 7 septembre 2026, faite
en résolvant les URI d'import de tous les `.dart` de `lib/features/` — les
`package:carlys/…` **et** les chemins relatifs, qu'un `grep` naïf manque :

> **137 imports franchissent une frontière de fonctionnalité, répartis sur
> 46 arêtes entre les 20 fonctionnalités qui portent du code.**

Six dossiers ne contiennent encore qu'un `.gitkeep` et n'apparaissent donc
nulle part ci-dessous : `body_metrics`, `health`, `programs`, `social`,
`subscriptions`, `workout_builder`.

Une colonne « dépend de : — » serait fausse pour presque tout le monde. Ce
qui se vérifie, en revanche, c'est le **sens des couches**.

### La règle qui tient

**Aucune couche `domain` n'importe la `presentation` ni la `data` d'une autre
fonctionnalité.** Zéro exception sur les 137 imports. Répartition mesurée :

| Franchissement                     | Imports |
| ---------------------------------- | ------: |
| `presentation` → `presentation`    |      71 |
| `presentation` → `domain`          |      41 |
| `domain` → `domain`                |      12 |
| `data` → `domain`                  |       5 |
| `presentation` → `data`            |       4 |
| `data` → `data`                    |       4 |
| `domain` → `data` ou `presentation`|   **0** |

C'est l'invariant à préserver quand on ajoute une fonctionnalité : **un
`domain` ne connaît que des `domain`.** Il rend le métier testable seul et
empêche une entité de dépendre d'un écran.

Les huit franchissements `presentation → data` et `data → data` sont, eux,
des **coutures nommées** (liste plus bas) : assumées une par une, pas
accidentelles. Toute nouvelle entrée dans cette liste se discute.

### Qui importe qui

| Fonctionnalité     | Importe (nombre d'imports)                                                                                                                                       | Total |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----: |
| `dashboard`        | `workout_session` (7), `nutrition` (4), `carlys_profile` (3), `progression` (3), `academy` (2), `community` (2), `progress` (2), `authentication`, `notifications`, `onboarding`, `workout_template` |    27 |
| `workout_template` | `workout_session` (18)                                                                                                                                             |    18 |
| `profile`          | `authentication` (5), `progress` (3), `notifications` (2), `settings` (2), `subscription` (2), `carlys_profile`, `nutrition`, `progression`                          |    17 |
| `onboarding`       | `carlys_profile` (6), `nutrition` (5), `authentication` (3)                                                                                                        |    14 |
| `workout_history`  | `workout_session` (10), `progress` (3)                                                                                                                             |    13 |
| `coaching`         | `workout_session` (4), `carlys_profile` (2), `progress` (2), `workout_template` (2)                                                                                |    10 |
| `progression`      | `workout_session` (5), `academy` (2), `progress` (2), `authentication`                                                                                              |    10 |
| `exercises`        | `progress` (4), `workout_session` (3)                                                                                                                              |     7 |
| `workout_session`  | `workout_template` (4), `exercises` (3)                                                                                                                            |     7 |
| `authentication`   | `carlys_profile` (2), `notifications`                                                                                                                              |     3 |
| `subscription`     | `onboarding` (3)                                                                                                                                                   |     3 |
| `academy`          | `community`, `exercises`                                                                                                                                            |     2 |
| `carlys_profile`   | `authentication` (2)                                                                                                                                                |     2 |
| `progress`         | `progression` (2)                                                                                                                                                   |     2 |
| `training`         | `workout_session`                                                                                                                                                   |     1 |
| `workout_program`  | `workout_template`                                                                                                                                                  |     1 |

Quatre fonctionnalités n'importent **aucune** autre : `community`,
`nutrition`, `notifications`, `settings`. Ce sont les seules feuilles.

Dans l'autre sens, `workout_session` est la plaque tournante : **48 imports
reçus de 7 fonctionnalités**. Toucher `Workout`, `WorkoutSessionWriter` ou
`workoutControllers` se paie donc loin de `workout_session`.

### Quatre cycles, et pourquoi ils existent

Ce ne sont pas des erreurs à corriger en urgence, mais ils se connaissent :
casser l'un des deux sens sans le savoir casse l'autre.

| Cycle                                 | Imports | Ce qui le crée                                                                                                                                                                            |
| ------------------------------------- | ------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workout_template` ⇄ `workout_session` | 18 / 4  | Le modèle écrit une **vraie** séance (`WorkoutSessionWriter`) ; la séance relit son plan (`sessionGuidance`, `SessionPlanLocalDataSource`)                                                  |
| `exercises` ⇄ `workout_session`        | 3 / 3   | `exercise_picker_sheet` (séance) lit le catalogue ; `exercise_action_bar` (catalogue) ouvre la saisie d'une série                                                                            |
| `progression` ⇄ `progress`             | 2 / 2   | `progress_screen` affiche les cartes de paliers et de sceaux ; `reward_controllers` lit les records pour décider d'un sceau                                                                  |
| `carlys_profile` ⇄ `authentication`    | 2 / 2   | `AuthUser` porte `carlysProfile` (`domain` → `domain`, le sens sain) ; les contrôleurs du profil rafraîchissent l'utilisateur après un choix                                                 |

### Les huit coutures nommées

`presentation` → `data` — un contrôleur câble une implémentation concrète
d'une autre fonctionnalité :

- `dashboard/…/dashboard_controllers.dart` → `progress/data/repositories/progress_repository_impl.dart`
- `profile/…/profile_controllers.dart` → `progress/data/repositories/progress_repository_impl.dart`
- `workout_session/…/exercise_picker_sheet.dart` → `exercises/data/repositories/exercises_repository_impl.dart`
- `workout_template/…/workout_template_controllers.dart` → `workout_session/data/repositories/workout_repository_impl.dart`

`data` → `data` — deux fonctionnalités écrivent dans **la même transaction
Drift**, parce que dupliquer l'écriture serait pire :

- `coaching/…/coach_session_launcher.dart` → `workout_session/data/local/workout_session_writer.dart`
- `coaching/…/coach_session_launcher.dart` → `workout_template/data/datasources/session_plan_local_data_source.dart`
- `workout_session/…/workout_session_downloader.dart` → `workout_template/data/datasources/session_plan_local_data_source.dart`
- `workout_template/…/workout_template_repository_impl.dart` → `workout_session/data/local/workout_session_writer.dart`

### Ce que sont ces fonctionnalités

- `workout_session` : séances **réalisées**, offline-first (Drift → file de
  sync → API).
- `workout_template` : modèles **prescriptifs** — composer, enregistrer, puis
  lancer une vraie séance pré-remplie. Réutilise les entités `SetKind` /
  `LocalSyncState`, les écritures (`WorkoutSessionWriter`) et le sélecteur
  d'exercice (`showExercisePickerSheet`) de `workout_session`.
- `workout_program` : programmes multi-semaines, le calendrier (quand) relié
  aux modèles (quoi). Une seule écriture — PUT de l'état complet, id né sur
  l'appareil.
- `coaching` : le coach lit l'état réel (modèles, records, poids, identité
  Carlys) pour ses amorces, et lance la séance qu'il propose.
  `CoachSessionLauncher` réutilise `WorkoutSessionWriter` et
  `SessionPlanLocalDataSource` pour écrire la séance et son plan dans une
  seule transaction — exactement le chemin de `startFromTemplate`. Aucune
  fonctionnalité amont ne connaît le coach. Ses amorces, elles, ne dépendent
  d'aucune entité extérieure : `CoachContext` ne porte que des valeurs
  simples, et la règle se teste seule.
- `training` : hub de l'onglet Training — reprise de la séance active, portes
  vers modèles, exercices, coach et historique.
- `academy` : contenu **éditorial** embarqué (leçons + questions,
  `assets/academy/pack.json`), donc hors ligne ; la nutrition s'ouvre depuis
  ce hub. Emprunte une carte de groupe musculaire à `exercises` et le
  contrôleur de communauté pour ses défis.
- `community` : amis (demandes par e-mail, non énumérables), encouragements,
  défis collectifs, partage de progression. Servie par `/api/v1/community`
  (confidentialité décidée **côté serveur**) ; dépôt de démonstration dans
  `lib/demo/` — contrat dans
  [`docs/product/community.md`](../../../../docs/product/community.md).

### Le plan de séance, côté `workout_session`

Le contact retour de `workout_session` vers `workout_template` tient en
**trois fichiers**, et il faut les connaître avant de toucher au plan :

- `presentation/widgets/active_workout_body.dart` — l'orchestrateur lit
  `sessionPlanProvider` et le traduit en valeurs simples (`guidanceFor`)
  avant de les passer à ses widgets ;
- `presentation/widgets/active_workout_choices.dart` — même traduction pour
  les choix de l'écran ;
- `data/repositories/workout_session_downloader.dart` — le rapatriement écrit
  **aussi le plan**, dans la table de `workout_template` : la couche données
  de `workout_session` connaît donc `SessionPlanLocalDataSource`. Le
  franchissement est assumé et documenté dans le fichier lui-même ; il est
  symétrique de celui du sens inverse.

En revanche le **domaine** de `workout_session` ignore complètement les
modèles, et ses widgets de saisie ne reçoivent qu'un sur-titre, des cibles et
des compteurs. Sans plan, l'écran de séance se comporte **exactement** comme
avant.

Le contrat complet est dans
[`docs/product/workout-templates.md`](../../../../docs/product/workout-templates.md).

### Remesurer

Ce tableau vieillit. Pour le refaire : parcourir tous les `.dart` de
`lib/features/`, extraire les `import`/`export`/`part`, résoudre chaque URI
(`package:carlys/x` → `lib/x`, sinon chemin relatif au fichier), et ne garder
que les cibles dont le premier segment sous `features/` diffère de celui de
la source. Les chemins relatifs portent l'essentiel des arêtes : un `grep`
sur `package:carlys/features/` en manque la quasi-totalité.

## Règles

- une petite fonctionnalité peut alléger cette structure, mais sépare
  toujours interface / logique / données ;
- aucun widget n'appelle l'API directement — toujours via contrôleur,
  use case et repository ;
- les widgets réutilisables entre fonctionnalités vivent dans
  `lib/design_system/components` (génériques) ou `lib/shared/widgets`
  (métier transverse) ;
- un `domain` n'importe jamais la `data` ni la `presentation` d'une autre
  fonctionnalité — c'est la seule dépendance interdite, et elle est
  aujourd'hui respectée partout.
