# Fonctionnalités (feature-first)

Chaque fonctionnalité importante suit cette structure :

```
feature/
├── data/
│   ├── datasources/     # API distante (Dio) et base locale (Drift)
│   ├── dto/             # Objets de transfert (json_serializable)
│   ├── mappers/         # DTO/Drift ⇄ entités du domaine
│   └── repositories/    # Implémentations des contrats du domaine
│
├── domain/
│   ├── entities/        # Objets métier immuables (Freezed)
│   ├── repositories/    # Contrats abstraits
│   ├── services/        # Logique métier pure
│   └── usecases/        # Cas d'usage orchestrant les repositories
│
└── presentation/
    ├── controllers/     # Contrôleurs Riverpod (état des écrans)
    ├── providers/       # Providers de la fonctionnalité
    ├── screens/         # Écrans
    └── widgets/         # Widgets propres à la fonctionnalité
```

## Dépendances entre fonctionnalités

| Fonctionnalité     | Dépend de         | Détail                                                          |
| ------------------ | ----------------- | --------------------------------------------------------------- |
| `workout_session`  | —                 | Séances **réalisées** offline-first (Drift → file de sync → API) |
| `workout_template` | `workout_session` | Modèles de séance **prescriptifs** : composer, enregistrer, puis lancer une vraie séance pré-remplie |
| `coaching`         | `workout_session`, `workout_template`, `progress` | Le coach lit l'état réel (modèles, records, poids) pour ses amorces, et lance la séance qu'il propose |

`workout_template` réutilise les entités `SetKind` / `LocalSyncState`, les
écritures de séance (`WorkoutSessionWriter`) et le sélecteur d'exercice
(`showExercisePickerSheet`) de `workout_session`.

`coaching` suit la même règle, dans le même sens : `CoachSessionLauncher`
réutilise `WorkoutSessionWriter` et `SessionPlanLocalDataSource` pour écrire la
séance et son plan dans une seule transaction — exactement le chemin de
`startFromTemplate`. Aucune des trois fonctionnalités amont ne connaît le
coach. Ses amorces de conversation, elles, ne dépendent d'aucune entité
extérieure : `CoachContext` ne porte que des valeurs simples, et la règle se
teste seule.

Dans l'autre sens, le contact est réduit à **un seul point** :
l'orchestrateur `ActiveWorkoutBody` lit `sessionPlanProvider` et le traduit
en valeurs simples (`guidanceFor`) avant de les passer à ses widgets. Ni le
domaine, ni les données, ni les widgets de `workout_session` ne connaissent
les modèles : ils reçoivent un sur-titre, des cibles et des compteurs. Sans
plan, l'écran de séance se comporte **exactement** comme avant.

Le contrat complet est dans
[`docs/product/workout-templates.md`](../../../../docs/product/workout-templates.md).

Règles :

- une petite fonctionnalité peut alléger cette structure, mais sépare
  toujours interface / logique / données ;
- aucun widget n'appelle l'API directement — toujours via contrôleur,
  use case et repository ;
- les widgets réutilisables entre fonctionnalités vivent dans
  `lib/design_system/components` (génériques) ou `lib/shared/widgets`
  (métier transverse).
