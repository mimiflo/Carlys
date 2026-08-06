# Décisions d'architecture (ADR)

Ce dossier contient les **Architecture Decision Records** (ADR) de Carlys : chaque
décision structurante y est consignée avec son contexte, les alternatives étudiées
et les conséquences assumées. Les ADR servent trois objectifs :

- **Mémoire du projet** — comprendre *pourquoi* un choix a été fait, pas seulement
  *ce qui* a été choisi, même des années plus tard.
- **Embarquement** — un nouveau contributeur lit les ADR et connaît les fondations
  du projet sans avoir à interroger l'équipe.
- **Discipline** — remettre en cause une décision passe par un nouvel ADR qui
  remplace l'ancien, jamais par une dérive silencieuse du code.

Une décision acceptée n'est pas gravée dans le marbre : elle est **valable tant
qu'aucun ADR ultérieur ne la remplace**.

## Format

Chaque ADR est un fichier Markdown numéroté (`NNNN-titre-court.md`) qui suit
exactement ce gabarit :

```markdown
# ADR NNNN — Titre de la décision

## Statut
Acceptée — AAAA-MM

## Contexte
## Décision
## Raisons
## Avantages
## Inconvénients
## Conséquences
```

Les statuts possibles sont : `Proposée`, `Acceptée`, `Dépréciée` (avec un lien
vers l'ADR qui la remplace).

## Index des décisions

| ADR | Titre | Statut |
| --- | --- | --- |
| [0001](0001-use-flutter.md) | Flutter pour l'application mobile | Acceptée — 2026-08 |
| [0002](0002-use-nestjs.md) | NestJS pour l'API backend | Acceptée — 2026-08 |
| [0003](0003-use-postgresql.md) | PostgreSQL comme base de données principale | Acceptée — 2026-08 |
| [0004](0004-use-modular-monolith.md) | Monolithe modulaire plutôt que microservices | Acceptée — 2026-08 |
| [0005](0005-use-offline-first.md) | Architecture offline-first pour le mobile | Acceptée — 2026-08 |
| [0006](0006-use-entitlements.md) | Entitlements côté serveur pour les abonnements | Acceptée — 2026-08 |
| [0007](0007-use-riverpod.md) | Riverpod pour l'état et l'injection de dépendances Flutter | Acceptée — 2026-08 |
| [0008](0008-use-drift.md) | Drift (SQLite) pour la persistance locale mobile | Acceptée — 2026-08 |

## Ajouter un ADR

1. Copier le gabarit ci-dessus dans `docs/decisions/NNNN-titre-court.md`, en
   prenant le **prochain numéro libre** (numérotation continue, jamais réutilisée).
2. Rédiger le contexte **avant** la décision : le problème doit être compréhensible
   sans connaître la solution retenue.
3. Lister honnêtement les alternatives écartées et les inconvénients du choix —
   un ADR sans inconvénient est un ADR incomplet.
4. Ouvrir une pull request ; l'ADR passe en statut `Acceptée` une fois la PR
   fusionnée, avec le mois de la décision.
5. Ajouter la ligne correspondante dans l'index de ce README.
6. Si l'ADR remplace une décision existante, passer l'ancien ADR en `Dépréciée`
   avec un lien vers le nouveau — ne jamais supprimer ni réécrire un ADR accepté.
