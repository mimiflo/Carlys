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
    │                    #   par la règle de CLAUDE.md. `exercises` est la
    │                    #   première fonctionnalité à les y ranger ; les
    │                    #   autres ont encore les leurs dans `controllers/`
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

Elles sont **nombreuses**, et c'est assumé. Mesure du **27 septembre 2026**,
faite en résolvant les URI d'import de tous les `.dart` de `lib/features/` —
les `package:carlys_mobile/…` **et** les chemins relatifs, qu'un `grep` naïf
manque (méthode sous « Remesurer ») :

> **214 imports franchissent une frontière de fonctionnalité, répartis sur
> 68 arêtes entre les 21 fonctionnalités.**

(La mesure du 7 septembre en comptait 137 sur 46 arêtes : les chiffres qui
suivent périment vite, seule la méthode fait foi.)

Une colonne « dépend de : — » serait fausse pour presque tout le monde. Ce
qui se vérifie, en revanche, c'est le **sens des couches**.

### La règle qui tient

**Aucune couche `domain` n'importe la `presentation` ni la `data` d'une autre
fonctionnalité.** Zéro exception sur les 214 imports. Répartition mesurée :

| Franchissement                     | Imports |
| ---------------------------------- | ------: |
| `presentation` → `presentation`    |     116 |
| `presentation` → `domain`          |      60 |
| `domain` → `domain`                |      20 |
| `data` → `domain`                  |       9 |
| `data` → `data`                    |       5 |
| `presentation` → `data`            |       4 |
| `domain` → `data` ou `presentation`|   **0** |

C'est l'invariant à préserver quand on ajoute une fonctionnalité : **un
`domain` ne connaît que des `domain`.** Il rend le métier testable seul et
empêche une entité de dépendre d'un écran.

Les neuf franchissements `presentation → data` et `data → data` sont, eux,
des **coutures nommées** (liste plus bas) : assumées une par une, pas
accidentelles. Toute nouvelle entrée dans cette liste se discute.

### Qui importe qui

| Fonctionnalité     | Importe (nombre d'imports)                                                                                                                                                                                  | Total |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----: |
| `profile`          | `workout_program` (12), `authentication` (6), `community` (3), `progression` (3), `carlys_profile` (2), `notifications` (2), `progress` (2), `settings` (2), `subscription` (2), `dashboard`, `mentor`, `nutrition` |    37 |
| `dashboard`        | `workout_session` (8), `nutrition` (5), `progress` (4), `progression` (4), `carlys_profile` (3), `community` (3), `academy` (2), `mentor` (2), `authentication`, `notifications`, `onboarding`, `workout_template` |    35 |
| `workout_template` | `workout_session` (21)                                                                                                                                                                                      |    21 |
| `onboarding`       | `carlys_profile` (6), `workout_program` (6), `nutrition` (5), `authentication` (3)                                                                                                                          |    20 |
| `workout_history`  | `workout_session` (13), `progress` (3)                                                                                                                                                                      |    16 |
| `progression`      | `progress` (5), `workout_session` (5), `academy` (3), `authentication` (2)                                                                                                                                  |    15 |
| `coaching`         | `workout_session` (4), `carlys_profile` (2), `progress` (2), `workout_template` (2), `subscription`                                                                                                         |    11 |
| `workout_program`  | `workout_session` (4), `authentication` (2), `exercises` (2), `workout_template` (2), `onboarding`                                                                                                          |    11 |
| `academy`          | `progression` (5), `community` (2), `exercises`                                                                                                                                                             |     8 |
| `authentication`   | `carlys_profile` (2), `mentor` (2), `workout_program` (2), `notifications`, `onboarding`                                                                                                                    |     8 |
| `exercises`        | `progress` (4), `workout_session` (3)                                                                                                                                                                       |     7 |
| `workout_session`  | `workout_template` (4), `exercises` (2), `progress` (2)                                                                                                                                                     |     8 |
| `mentor`           | `progression` (3), `academy`, `authentication`                                                                                                                                                              |     5 |
| `progress`         | `progression` (3), `authentication`                                                                                                                                                                         |     4 |
| `subscription`     | `onboarding` (3)                                                                                                                                                                                            |     3 |
| `carlys_profile`   | `authentication` (2)                                                                                                                                                                                        |     2 |
| `community`        | `authentication`                                                                                                                                                                                            |     1 |
| `notifications`    | `authentication`                                                                                                                                                                                            |     1 |
| `training`         | `workout_session`                                                                                                                                                                                           |     1 |

Deux fonctionnalités n'importent **aucune** autre : `nutrition` et
`settings`. Ce sont les seules feuilles. `community` et `notifications` ont
cessé de l'être : leurs caches liés au compte s'appuient sur
`authentication/…/account_bound_cache.dart`.

Dans l'autre sens, `workout_session` est la plaque tournante : **59 imports
reçus de 8 fonctionnalités**. Toucher `Workout`, `WorkoutSessionWriter` ou
`workoutControllers` se paie donc loin de `workout_session`.
`authentication` est la plus largement importée (10 fonctionnalités) : son
`auth_controller` et `account_bound_cache` bornent tout ce qui dépend du
compte ouvert.

### Les cycles, et pourquoi ils existent

Ce ne sont pas des erreurs à corriger en urgence, mais ils se connaissent :
casser l'un des deux sens sans le savoir casse l'autre.

| Cycle                                   | Imports | Ce qui le crée                                                                                                                                                                  |
| --------------------------------------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `workout_template` ⇄ `workout_session`   | 21 / 4  | Le modèle écrit une **vraie** séance (`WorkoutSessionWriter`) ; la séance relit son plan (`sessionGuidance`, `SessionPlanLocalDataSource`)                                        |
| `progression` ⇄ `progress`               | 5 / 3   | `reward_controllers` et `milestone_push` lisent les records et poussent le journal des récompenses ; `progress_screen` et `timeline_row` affichent sceaux et paliers              |
| `academy` ⇄ `progression`                | 3 / 5   | les récompenses lisent l'avancement de l'Academy ; la carte d'avancement de l'Academy dessine les sceaux                                                                        |
| `exercises` ⇄ `workout_session`          | 3 / 2   | `exercise_action_bar` (catalogue) ouvre la saisie d'une série ; `exercise_picker_sheet` (séance) lit le catalogue                                                                |
| `onboarding` ⇄ `workout_program`         | 6 / 1   | le premier lancement pose l'objectif d'entraînement ; la feuille d'objectif réutilise les choix du premier lancement                                                            |
| `carlys_profile` ⇄ `authentication`      | 2 / 2   | `AuthUser` porte `carlysProfile` (`domain` → `domain`, le sens sain) ; les contrôleurs du profil rafraîchissent l'utilisateur après un choix                                     |
| `mentor` ⇄ `authentication`              | 1 / 2   | `AuthUser` porte `mentorStyle` ; le contrôleur du Mentor rafraîchit l'utilisateur                                                                                               |
| `workout_program` ⇄ `authentication`     | 2 / 2   | `AuthUser` porte `trainingGoal` ; l'objectif et le profil d'entraînement suivent le compte ouvert                                                                               |
| `onboarding` ⇄ `authentication`          | 3 / 1   | le premier lancement et l'écran de démarrage lisent l'état de session ; l'en-tête d'authentification réutilise la signature de marque                                          |
| `notifications` ⇄ `authentication`       | 1 / 1   | `auth_controller` démarre et oublie l'enregistrement push ; les préférences de notification sont un cache lié au compte                                                         |

### Les neuf coutures nommées

`presentation` → `data` — un contrôleur câble une implémentation concrète
d'une autre fonctionnalité :

- `academy/…/academy_controllers.dart` → `community/data/repositories/community_repository_impl.dart`
- `coaching/…/coach_controllers.dart` → `subscription/data/repositories/subscription_repository_impl.dart` (le coach lit le droit `ai_coaching` décidé par le serveur, pour passer un ancien abonné en lecture seule)
- `dashboard/…/form_reading_providers.dart` → `progress/data/repositories/progress_repository_impl.dart`
- `workout_template/…/workout_template_controllers.dart` → `workout_session/data/repositories/workout_repository_impl.dart`

`data` → `data` — deux fonctionnalités écrivent dans **la même transaction
Drift**, ou une donnée pousse vers le dépôt d'une autre, parce que dupliquer
l'écriture serait pire :

- `coaching/…/coach_session_launcher.dart` → `workout_session/data/local/workout_session_writer.dart`
- `coaching/…/coach_session_launcher.dart` → `workout_template/data/datasources/session_plan_local_data_source.dart`
- `progression/data/milestone_push.dart` → `progress/data/repositories/progress_repository_impl.dart`
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
  (confidentialité décidée **côté serveur**) ; doublure en mémoire dans
  `test/support/` — contrat dans
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
(`package:carlys_mobile/x` → `lib/x`, sinon chemin relatif au fichier), et ne
garder que les cibles dont le premier segment sous `features/` diffère de
celui de la source. Les chemins relatifs portent l'essentiel des arêtes : un
`grep` sur `package:carlys_mobile/features/` en manque la quasi-totalité. La
liste des coutures se relit ainsi : une cible sous `<autre>/data/` depuis une
source sous `presentation/` ou `data/`.

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
