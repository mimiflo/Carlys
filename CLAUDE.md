# CLAUDE.md — Règles de développement Carlys

## Le projet en cinq lignes

Carlys est une plateforme fitness SaaS : application mobile Flutter (offline-first),
API NestJS 11 (monolithe modulaire, Prisma 6 + PostgreSQL 17, Redis) et tableau de bord
admin Next.js 16, organisés en monorepo pnpm (`apps/*`, `packages/*` ; `apps/mobile`
est volontairement hors workspace JS). Le développement avance par **tranches verticales** :
chaque étape livre une fonctionnalité complète (base de données → API → mobile → admin → tests → docs),
jamais une couche horizontale isolée.

| Étape | Contenu | Statut |
| ----- | ------- | ------ |
| 1 | Fondation (monorepo, design system, infra, CI, observabilité) | **Faite** |
| 2 | Authentification (JWT access court + refresh rotatif hashé, Argon2id, sessions par appareil, détection de réutilisation) | **Faite** |
| 3 | Exercices (catalogue, seed 30+ exercices, cache Redis) | **Faite** |
| 4 | Séances (offline-first Drift + file de synchronisation idempotente) | **Faite** |
| 5 | Progression (records recalculés à la clôture, stats par période, mesures corporelles idempotentes) | **Faite** |
| 6 | Abonnements (entitlements côté serveur, RevenueCat possible, Stripe web, webhooks idempotents signés) | **Faite** |
| 7 | Administration (comptes admin séparés, RBAC par permissions, audit) | **Faite** |

## Commandes essentielles

Depuis la racine du dépôt :

```bash
pnpm install            # dépendances JS (workspace pnpm)
pnpm dev                # API (3000) + admin (3001) en parallèle
pnpm dev:api            # API seule
pnpm dev:admin          # admin seul
docker compose up -d    # infra locale : postgres, redis, mailpit, minio
docker compose down     # arrêt de l'infra

pnpm prisma:generate    # client Prisma
pnpm prisma:migrate     # prisma migrate dev (apps/api)
pnpm prisma:seed        # seed (apps/api)
```

**Vérification obligatoire avant tout commit** (TypeScript) :

```bash
pnpm build && pnpm format:check && pnpm lint && pnpm typecheck && pnpm test
# ou, équivalent en une commande :
./scripts/check.sh      # (le raccourci `pnpm check` existe aussi)
```

**Flutter** (`apps/mobile`, hors workspace pnpm) :

```bash
flutter pub get
dart run build_runner build   # Drift uniquement
flutter analyze         # bloquant, comme en CI
flutter test
./scripts/check_mobile.sh   # surensemble de la CI Flutter : jamais moins, parfois plus
flutter run --dart-define=CARLYS_FLAVOR=development --dart-define=CARLYS_API_BASE_URL=http://localhost:3000
```

Les dossiers `android/` et `ios/` ne sont pas versionnés : ils se génèrent via
`./scripts/bootstrap_mobile.sh`. La CI (`.github/workflows/`) rejoue ces mêmes
vérifications : ne pousse jamais un commit qui ne passe pas localement.

## Graphe de code (Graphify)

Le dépôt se cartographie en graphe de connaissances interrogeable
(paquet PyPI `graphifyy`, CLI `graphify`) — extraction 100 % locale par
tree-sitter, aucun appel LLM, rien ne quitte la machine.

**Aucune commande à taper en session web** : le hook
`.claude/hooks/session-start.sh` installe le CLI, enregistre le skill
`/graphify` et (re)construit le graphe à l'ouverture de chaque session
Claude Code sur le web. Sur un poste local, l'installation reste manuelle
et facultative :

```bash
uv tool install "graphifyy[sql]"   # ou : pipx install "graphifyy[sql]"
graphify install                   # enregistre le skill /graphify (une fois par machine)
graphify update .                  # (re)construit graphify-out/ — à refaire après gros changements
```

`graphify-out/` est **engendré, jamais versionné** (comme `android/` et les
`.g.dart`). Pour une question d'architecture ou de dépendances, interroger le
graphe AVANT de parcourir les fichiers coûte beaucoup moins de tokens :

```bash
graphify query "<question>" --budget 2000   # BFS sur le graphe
graphify god-nodes                          # les plaques tournantes du code
graphify affected "<symbole>"               # qui casse si ce nœud change
graphify explain "<nœud>"                   # un nœud et ses voisins
graphify path "A" "B"                       # le chemin le plus court entre deux nœuds
```

**Le graphe est dense côté TypeScript, plat côté Dart.** Mesuré le 16 septembre
2026 sur `graphify-out/graph.json` (13 014 nœuds, 21 035 arêtes) :

| | nœuds | relations extraites |
| --- | --- | --- |
| `apps/api`, `apps/admin`, `packages` (TS) | 2 365 | `references` 1651, `contains` 1240, `imports` 1160, `imports_from` 1063, **`calls` 824**, `method` 712 |
| `apps/mobile` (Dart) | 7 039 | `defines` 6418, `imports` 3429, `references` 1829, `inherits` 527, `navigates` 63 — et **`calls` : 0** |

Conséquences, à connaître avant d'interpréter une réponse :

- **`affected "<symbole>"` sur du Dart est un FAUX NÉGATIF, jamais une preuve
  d'absence.** Sans arête `calls` et sans nœud `_callable` côté Dart (0 sur
  7 039), `affected "AppExplainable"` rend « No affected nodes found » alors que
  quatre fichiers en dépendent. Même chose pour `path` entre deux nœuds Dart.
- **Une arête `imports` Dart vise la chaîne d'import BRUTE, pas le fichier
  résolu.** Un même fichier porte donc plusieurs nœuds alias : le vrai
  (`source_file` renseigné) plus un alias `package:carlys_mobile/…` et un par
  chemin relatif distinct. Les dépendances inverses d'un fichier Dart se lisent
  en faisant l'**union des alias** :

  ```bash
  graphify affected "package:carlys_mobile/<chemin>/<fichier>.dart" --relation imports --depth 1
  graphify affected "../../<chemin relatif>/<fichier>.dart"          --relation imports --depth 1
  ```

- **`god-nodes` est un classement de l'API, pas du dépôt.** Le vrai pivot mobile,
  `design_system/design_system.dart` (258 importeurs, soit 210 des 459 fichiers de
  `lib/`), n'y figure pas. Et son rang 7, `_Body` (47 arêtes), est une **collision
  de normalisation** : 45 de ses arêtes sont les décorateurs `@Body()` de 21
  contrôleurs NestJS, rattachés à une classe Dart privée homonyme
  (`exercise_progression_screen.dart:55`) utilisée une seule fois.

**Le graphe SUGGÈRE, la source PROUVE.** Il cadre la question et donne le rayon
de casse côté TS ; toute conclusion se vérifie ensuite par lecture du fichier, et
une divergence se tranche toujours en faveur de la source.

**Fraîcheur.** Le hook ne rejoue `graphify update .` qu'à l'OUVERTURE de la
session : le graphe se périme dès le premier commit de la session. Le vérifier
coûte une commande, et `GRAPH_REPORT.md` porte aussi la réponse en tête :

```bash
test "$(git rev-parse HEAD)" = "$(python3 -c "import json;print(json.load(open('graphify-out/graph.json'))['built_at_commit'])")" \
  && echo "graphe à jour" || graphify update .
```

## Règles générales (spécification produit — à respecter intégralement)

**Interdits :**

- Ne **jamais** créer une fonctionnalité sans comprendre son domaine.
- Ne **jamais** mettre toute la logique dans un seul fichier.
- Ne **jamais** créer de fichier géant.
- Ne **jamais** dupliquer une logique existante — chercher et réutiliser d'abord.
- Ne **jamais** coder en dur une valeur visuelle (couleur, espacement, rayon, ombre,
  durée d'animation) dans une page Flutter : le design system (`lib/design_system/`)
  est obligatoire.
- Ne **jamais** faire d'appel API directement depuis un widget Flutter — toujours via
  contrôleur → use case → repository.
- Ne **jamais** accéder à Prisma depuis un contrôleur NestJS — l'accès aux données
  passe par les services/repositories du module.
- Ne **jamais** mettre de logique métier dans les contrôleurs HTTP.
- Ne **jamais** commiter un secret dans le dépôt (les `.env.example` ne contiennent
  que des valeurs factices ; TruffleHog tourne en CI).
- Ne **jamais** ignorer une erreur TypeScript ou Dart sans justification écrite.
- Ne **jamais** supprimer un test pour faire passer une fonctionnalité.
- Ne **jamais** inventer une dépendance si une solution standard existe déjà.
- Ne **jamais** ajouter une bibliothèque sans expliquer son utilité.
- Ne **jamais** créer de microservice sans nécessité réelle — l'API est un monolithe
  modulaire.

**Obligations :**

- Toujours privilégier la lisibilité et la maintenabilité.
- Toujours utiliser des types stricts (TS strict + `noUncheckedIndexedAccess` ;
  pas de `any` injustifié, pas de `dynamic` injustifié en Dart).
- Toujours traiter les erreurs (jamais de `catch` vide, jamais d'échec silencieux).
- Toujours valider les entrées (class-validator `whitelist` + `forbidNonWhitelisted`
  côté API ; Zod côté admin et config).
- Toujours écrire les migrations Prisma (jamais de dérive de schéma ; la CI détecte
  les migrations manquantes).
- Toujours mettre à jour la documentation impactée (`docs/`, README concernés).
- Toujours exécuter formatter + lint + analyse + tests après toute modification.

## Tailles de fichiers

Découper proprement (extraction de widgets, services, use cases, modules) dès qu'un
seuil est dépassé — jamais de contournement :

| Type de fichier | Limite |
| --------------- | ------ |
| Widget Flutter | < 250 lignes |
| Contrôleur Riverpod (`controllers/`) et providers dérivés (`providers/`) | < 250 lignes — même couche de présentation qu'un widget, donc même budget. Un seul Notifier par fichier ; les providers purement dérivés se rangent hors de `controllers/` |
| Service | < 300 lignes |
| Contrôleur HTTP (NestJS) | < 200 lignes |
| Use case | < 200 lignes |
| Repository (implémentation d'un contrat du domaine) | pas de plafond de fichier, sa longueur suit le nombre de méthodes du contrat ; en revanche **aucune méthode ne dépasse 40 lignes**, et toute logique dépassant la couture vit dans un collaborateur extrait |
| Modèle | ciblé sur une seule responsabilité |
| Module NestJS | un module par domaine métier |

**Pourquoi ces deux lignes** (arbitrage de septembre 2026, mesuré avant d'être écrit) :

- **Repository — borner la méthode, pas le fichier.** Un plafond de fichier classe
  ensemble des cas opposés : `community_repository_impl.dart` (287 lignes) est une
  façade Dio de 22 `@override` d'une dizaine de lignes sur un contrat de 93 ;
  `workout_template_repository_impl.dart` (378) délègue déjà à six collaborateurs
  extraits ; `workout_repository_impl.dart` (376) était le seul des trois
  réellement dense. Un seuil à 300 acquitterait le plus risqué des trois dès
  qu'il tomberait à 299 lignes, et condamnerait les deux autres sans rien
  améliorer. (Ces trois nombres périment ; la commande qui les rend est plus
  bas, avec celle des méthodes.)

  La règle a fini par payer, quatre fois : `addSet` (59) et `_closeWorkout` (45)
  sont partis dans `WorkoutSessionWriter`, qui sert désormais les deux chemins
  d'écriture d'une série ; `metabolismReport` (46) dans
  `data/mappers/metabolism_mappers.dart`, en fonctions pures ; et
  `watchHistory` (45), une fois sa jointure agrégée séparée de la lecture du
  flux. Aucune méthode de repository ne dépasse plus 40 lignes. Un plafond de
  FICHIER n'aurait rien suggéré de tel — il aurait même RÉCOMPENSÉ le
  contraire, puisque l'extraction ajoute des lignes au fichier.
- **Contrôleur Riverpod — 250, comme un widget.** Aucun ne dépasse 164 lignes de code
  hors imports, commentaires et lignes vides : `coach_controllers` 249 lignes dont 163
  de code, `dashboard_controllers` 241 dont 164, `auth_controller` 244 dont 126 (35 %
  du fichier est de la documentation), `exercise_library_controller` 201 dont 145. Le
  seuil de 200 n'est franchi que par les commentaires : l'appliquer reviendrait à taxer
  la documentation. Un Notifier est de la présentation, pas un service — il a donc le
  budget du widget.

**Les écarts se comptent, ils ne se recopient pas.** Une liste d'écarts écrite en
dur périme au premier commit, et une règle posée à côté d'une dette fausse vaut
moins qu'une règle sans dette annoncée. Ces deux commandes rendent l'état réel ;
elles font foi contre toute liste, celle-ci comprise.

```bash
# Méthodes de repository au-dessus de 40 lignes — de la signature (annotation
# exclue) à l'accolade fermante. La mise en forme est celle de `dart format`,
# donc les membres sont à deux espaces d'indentation : c'est ce que le compte
# d'accolades ci-dessous suit.
awk 'FNR==1{s=0;d=0} /^  @/{next} !s && /^  [A-Za-z_]/{s=FNR;d=0}
     s{ d += gsub(/\{/,"{") - gsub(/\}/,"}")
        if (d==0 && /;$/) s=0
        else if (d==0 && /\}$/) {
          if (FNR-s+1 > 40) printf "%4d  %s:%d\n", FNR-s+1, FILENAME, s
          s=0 } }' \
  apps/mobile/lib/features/*/data/repositories/*_repository_impl.dart

# Fichiers de `controllers/` qui ne portent pas EXACTEMENT un Notifier :
# `2` et plus violent « un seul par fichier », `0` désigne un fichier de
# providers dérivés à ranger dans `presentation/providers/`.
grep -c 'extends [A-Za-z]*Notifier' \
  apps/mobile/lib/features/*/presentation/controllers/*.dart | grep -v ':1$'
```

Ce qu'elles rendaient le 15 septembre 2026, pour donner l'ordre de grandeur —
**relancer plutôt que croire** : AUCUNE méthode de repository au-dessus de 40
lignes ; **plus
aucun** fichier de `controllers/` portant plusieurs Notifier — le dernier,
`account_controllers.dart`, a été scindé en trois ; et **vingt-deux** qui n'en
portent aucun, `dashboard_controllers.dart` parmi eux. Ce dernier écart reste
entier : ce sont des providers dérivés à ranger dans `presentation/providers/`,
un dossier qui EXISTE désormais — `exercises` y a rangé les siens, et
`check_mobile_file_sizes.sh` lui applique le même seuil qu'à `controllers/`.

## Qualité exigée par fonctionnalité

Chaque fonctionnalité livrée comprend :

- **Tests** adaptés à sa nature : unitaires (logique), widget (UI Flutter),
  intégration, e2e (API — supertest ; le projet Jest `sans-infra` passe sans
  PostgreSQL ni Redis :
  `pnpm --filter @carlys/api test:e2e -- --selectProjects sans-infra`).
- **Gestion des états** : erreur, chargement, vide, hors-ligne (composants
  `AppErrorState`, `AppLoadingIndicator`, `AppEmptyState` côté mobile).
- **Accessibilité** : sémantique, contrastes, respect de la réduction d'animations
  système (`AppMotion` la gère déjà).
- **Logs utiles** : Pino structuré côté API, toujours corrélés au `requestId`.
- **Documentation** : Swagger (`/api/docs`, hors production) pour les endpoints,
  `docs/` et README pour l'architecture.

## Conventions spécifiques au dépôt

- **Enveloppes de réponse API** (définies dans `packages/api-contracts`) : succès
  `{ data, meta, requestId }`, erreur `{ error: { code, message, details, requestId } }`.
  Toute nouvelle route les respecte ; versioning URI `/api/v1`.
- **Tokens design** : `packages/design-tokens/src/tokens.json` est la **source de
  vérité** (primaire `#9B30FF`, accent `#FF7A45`, espacements, radius, typo, ombres,
  motion, breakpoints). Toute évolution s'y fait d'abord, puis se répercute dans le
  design system Flutter (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`,
  `AppShadows`, `AppMotion`, `AppBreakpoints`) et côté admin.
- **Identifiants** : UUID générables hors ligne (package `uuid` côté mobile) — jamais
  d'identifiant dépendant du serveur pour des entités créées hors connexion.
- **Dates** : stockées et échangées en **UTC** ; l'affichage est localisé côté client.
- **Structure Flutter feature-first** : `lib/features/<feature>/{data,domain,presentation}` —
  règles détaillées dans `apps/mobile/lib/features/README.md`.
- **Structure NestJS** : modules par domaine sous `src/modules/`, pragmatiques
  (contrôleur mince → service → accès données) ; transversal dans `src/common/`,
  config validée par Zod dans `src/config/env.schema.ts` (le serveur refuse de
  démarrer si une variable essentielle manque).
- **Offline-first** (Étape 4) : file de synchronisation idempotente, Drift en local —
  voir `docs/synchronization/offline-first.md`.
- **Entitlements** (Étape 6) : décidés **côté serveur uniquement**, jamais côté client.
- **Pas de faux backend ni de données codées en dur** : les mocks n'existent que
  dans les tests, isolés et remplaçables.
- **Migrations en production** : `prisma migrate deploy` avant bascule du trafic,
  jamais au démarrage du conteneur.
- Ne **jamais** déclarer une fonctionnalité terminée sans avoir réellement exécuté
  ses tests (et les avoir vus passer).

## Check-list de fin de tâche

1. Le code respecte les règles générales et les limites de taille ci-dessus.
2. Aucune valeur visuelle en dur, aucun secret, aucune dépendance injustifiée ajoutée.
3. Migrations Prisma écrites si le schéma a changé.
4. Tests écrits/adaptés et exécutés : `pnpm test` (+ `pnpm --filter @carlys/api test:e2e`
   si l'API est touchée), `flutter test` si le mobile est touché.
5. `./scripts/check.sh` passe (build, format, lint, typecheck, tests) ;
   `./scripts/check_mobile.sh` passe pour le mobile — il rejoue **toutes** les
   commandes de `mobile-ci.yml` dans le même ordre, `dart format
   --set-exit-if-changed` compris, que `flutter analyze && flutter test` ne
   couvre PAS. Il en fait parfois **plus** : des contrôles propres au dépôt que
   la CI n'a pas. C'est un surensemble, jamais un sous-ensemble — un vert ici
   vaut donc pour la CI, l'inverse n'est pas vrai. Ce qu'il contient
   exactement, son en-tête le dit ; ne pas le paraphraser ici.
6. Documentation mise à jour (`docs/`, README, Swagger le cas échéant).
7. États erreur/chargement/vide/hors-ligne couverts, accessibilité vérifiée,
   logs corrélés au `requestId`.
8. **Toute modification d'interface mobile part avec ses captures** :
   `apps/mobile/tool/screenshots/` (harnais `--update-goldens`), régénérées,
   **regardées une à une** avant le commit, puis montrées à l'utilisateur.
   Ce que la relecture juge : la densité (pas d'écran à moitié vide — poser
   du contenu plausible derrière une feuille), et l'identité Carlys (dégradé
   de signature, tokens du design system) — un écran gris de lignes nues
   n'est pas fini, même s'il fonctionne.
