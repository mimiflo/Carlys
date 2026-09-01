# ADR 0007 — Riverpod pour l'état et l'injection de dépendances Flutter

## Statut

Acceptée — 2026-08

## Contexte

L'application Flutter combine de l'état complexe : flux réactifs issus de Drift
(séance en cours, historique), état réseau et file de synchronisation
(ADR 0005), session utilisateur, préférences. L'architecture feature-first
(`lib/features/<feature>/{data,domain,presentation}`) exige un mécanisme
d'injection de dépendances qui permette de tester chaque couche isolément
(remplacer un repository par un faux, une base par une base en mémoire) et de
composer des états dérivés sans coupler les widgets aux implémentations.

## Décision

> **Mise à jour (10 août 2026)** — la génération de code n'a jamais servi :
> aucun provider n'a porté d'annotation `@riverpod`. `riverpod_annotation` et
> `riverpod_generator` ont été retirés des dépendances ; les providers sont
> écrits à la main. Le choix de Riverpod lui-même, décrit ci-dessous, reste
> entier.

**Riverpod** (`flutter_riverpod` + `riverpod_annotation`, avec génération de
code via `riverpod_generator`) est le mécanisme unique de gestion d'état et
d'injection de dépendances de l'application mobile.

## Raisons

- **Codegen typé** : les annotations génèrent des providers entièrement typés,
  vérifiés à la compilation — pas de lookup par chaîne ni de cast, et le lint
  Riverpod détecte les dépendances incorrectes.
- **Testabilité par override** : n'importe quel provider se remplace dans un
  `ProviderContainer` ou un `ProviderScope` de test (API simulée, Drift en
  mémoire) sans toucher au code de production — essentiel pour tester la file
  de synchronisation hors ligne.
- **Composition réactive** : les providers se dérivent les uns des autres
  (ex. état de séance = base Drift + connectivité + session) avec invalidation
  automatique et gestion native de l'asynchrone (`AsyncValue`).
- **Indépendance du widget tree** : contrairement à un DI porté par le
  `BuildContext`, la logique est accessible hors interface (démarrage, tâche de
  synchronisation).
- Alternatives écartées :
  - **Bloc** : discipline événement/état intéressante mais verbosité élevée
    pour beaucoup d'états simples, et l'injection de dépendances reste à
    résoudre à côté ; Riverpod couvre les deux besoins.
  - **Provider** : prédécesseur direct, lié au `BuildContext`, erreurs à
    l'exécution plutôt qu'à la compilation, composition limitée — Riverpod en
    est la correction assumée par le même auteur.
  - **GetX** : trop de magie implicite (service locator global, accès non
    typés), pratiques contraires à la testabilité et à la lisibilité
    recherchées.

## Avantages

- Un seul outil pour l'état éphémère, l'état applicatif et le DI — pas de
  moitié Provider, moitié service locator.
- Les streams Drift (ADR 0008) s'exposent naturellement en providers réactifs.
- Erreurs détectées à la compilation (types génériques, dépendances) plutôt
  qu'à l'exécution.
- Écosystème et documentation actifs, compatible avec GoRouter pour les
  redirections pilotées par l'état (session, onboarding).

## Inconvénients

- **Dépendance à `build_runner`** : toute modification d'un provider annoté
  exige `dart run build_runner build` — friction réelle au quotidien et en CI.
- Courbe d'apprentissage : `ref.watch` vs `ref.read` vs `ref.listen`,
  invalidation, `keepAlive`, familles de providers — des erreurs subtiles sont
  possibles (rebuilds excessifs, providers recréés par inadvertance).
- Le graphe de providers peut devenir difficile à visualiser s'il n'est pas
  discipliné par les frontières de features.

## Conséquences

- Chaque feature expose ses providers dans sa couche `presentation` (état
  d'écran) et `data` (repositories) ; les widgets ne consomment que des
  providers, jamais des singletons.
- Les tests utilisent systématiquement les overrides de `ProviderScope` — aucun
  mock global ni variable statique.
- Les fichiers générés (`*.g.dart`) accompagnent le code annoté ; la CI mobile
  (`mobile-ci.yml` : format bloquant, analyze, test) suppose une génération à
  jour.
- Tout ajout d'une seconde solution d'état (Bloc, GetX…) est proscrit sans
  nouvel ADR.
