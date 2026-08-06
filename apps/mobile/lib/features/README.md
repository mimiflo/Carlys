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

Règles :

- une petite fonctionnalité peut alléger cette structure, mais sépare
  toujours interface / logique / données ;
- aucun widget n'appelle l'API directement — toujours via contrôleur,
  use case et repository ;
- les widgets réutilisables entre fonctionnalités vivent dans
  `lib/design_system/components` (génériques) ou `lib/shared/widgets`
  (métier transverse).
