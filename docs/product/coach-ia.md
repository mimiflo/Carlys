# Coach IA — conception

Écran conversationnel qui répond, adapte une séance, et rend une **action
exécutable** dans l'application. Ce document fixe le contrat avant d'écrire la
moindre ligne ; il vaut spécification pour la tranche verticale.

## Le principe : l'IA propose, l'application exécute

Le coach ne modifie **rien**. Il lit des données par des outils, et sa seule
sortie structurée est une **proposition de séance** que l'utilisateur accepte
explicitement. L'écriture passe ensuite par le chemin de création de séance qui
existe déjà — idempotent, hors ligne, rejouable.

```
message utilisateur
   → outils de LECTURE (séances, records, catalogue, modèles, mesures)
   → réponse en texte
   → éventuellement un appel à `propose_session`
        → VALIDÉ par le serveur contre le catalogue
        → stocké comme proposition rattachée au message
   → l'app affiche « Voir la séance »
   → l'utilisateur accepte → création de séance par la route EXISTANTE
```

Trois propriétés tombent de ce schéma, et ce sont elles qui rendent la
fonctionnalité défendable :

1. **Le coach ne peut pas inventer un chiffre** : il n'en connaît aucun qu'il
   n'ait lu par un outil.
2. **Le coach ne peut pas inventer un exercice** : chaque `exerciseId` proposé
   est vérifié contre le catalogue côté serveur ; une proposition qui en
   contient un inconnu est **rejetée**, pas corrigée en silence.
3. **Le coach ne peut rien casser** : aucun outil d'écriture, aucun accès
   Prisma, aucune route mutante. Le pire échec possible est une réponse inutile.

## Périmètre de la version 1

**Ce qu'il fait.** Répondre sur l'entraînement et la progression à partir des
données réelles ; adapter un modèle de séance existant à une contrainte
(« j'ai 25 minutes », « pas de barre aujourd'hui », « j'ai mal dormi ») ;
expliquer un record, une stagnation, une tendance de poids.

**Ce qu'il ne fait pas, et le dit.** Rien sur les apports alimentaires (aucun
journal), rien sur le sommeil ni la fréquence cardiaque (aucune donnée de
santé), aucun diagnostic de blessure ni conseil médical, aucun programme
hebdomadaire (le module `programs` n'existe pas encore). Ces limites sont
écrites dans le prompt système **et** testées.

**Ce qui n'est pas dans la tranche :** la génération de programme, la voix,
les notifications proactives.

## Modèle de données (Prisma)

Conventions du dépôt respectées : UUID générés sur l'appareil, `createdAt` /
`updatedAt`, suppression logique, noms dénormalisés là où l'historique doit
survivre au catalogue.

```prisma
enum CoachMessageRole { USER, ASSISTANT }

/// Fil de discussion. L'id vient de l'appareil : le premier message peut être
/// composé avant que le serveur n'ait jamais entendu parler du fil.
model CoachConversation {
  id        String   @id @db.Uuid
  userId    String   @db.Uuid
  /// Résumé court du fil, écrit par le coach au premier échange.
  title     String?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  deletedAt DateTime?

  user     User           @relation(fields: [userId], references: [id], onDelete: Cascade)
  messages CoachMessage[]

  @@index([userId, updatedAt(sort: Desc)])
}

model CoachMessage {
  id             String           @id @db.Uuid
  conversationId String           @db.Uuid
  role           CoachMessageRole
  content        String
  /// Jetons consommés par CE message (rôle ASSISTANT uniquement) —
  /// observabilité du coût, pas de la facturation.
  inputTokens    Int?
  outputTokens   Int?
  createdAt      DateTime         @default(now())

  conversation CoachConversation      @relation(fields: [conversationId], references: [id], onDelete: Cascade)
  proposal     CoachSessionProposal?

  @@index([conversationId, createdAt])
}

/// Séance proposée par le coach. Tant qu'elle n'est pas acceptée, ce n'est
/// qu'un document : elle ne compte NI dans l'historique, NI dans les stats,
/// NI dans les records.
model CoachSessionProposal {
  id        String  @id @db.Uuid
  messageId String  @unique @db.Uuid
  name      String
  /// Durée estimée annoncée à l'utilisateur, en minutes.
  estimatedMinutes Int
  /// Modèle dont la proposition est dérivée, s'il y en a un.
  sourceTemplateId String? @db.Uuid
  /// Séance réellement lancée depuis cette proposition, le cas échéant.
  /// Renseigné par l'app à l'acceptation ; sert à mesurer le taux d'usage.
  acceptedSessionId String? @db.Uuid
  createdAt DateTime @default(now())

  message  CoachMessage               @relation(fields: [messageId], references: [id], onDelete: Cascade)
  template WorkoutTemplate?           @relation(fields: [sourceTemplateId], references: [id], onDelete: SetNull)
  items    CoachSessionProposalItem[]
}

/// Série proposée — MÊME FORME que `WorkoutSessionPlanItem`, volontairement.
/// L'acceptation est alors une copie, pas une traduction.
model CoachSessionProposalItem {
  id         String @id @db.Uuid
  proposalId String @db.Uuid

  exercisePosition Int
  exerciseId       String         @db.Uuid
  /// Dénormalisé, comme partout ailleurs : la proposition reste lisible
  /// même si le catalogue évolue.
  exerciseName     String
  setPosition      Int
  kind             WorkoutSetKind @default(NORMAL)
  targetReps       Int?
  targetWeightKg   Decimal?       @db.Decimal(6, 2)
  restSeconds      Int?

  proposal CoachSessionProposal @relation(fields: [proposalId], references: [id], onDelete: Cascade)
  exercise Exercise             @relation(fields: [exerciseId], references: [id])

  @@unique([proposalId, exercisePosition, setPosition])
  @@index([proposalId])
}
```

`exerciseId` est ici **non nullable avec clé étrangère ferme** — contrairement à
`WorkoutSet`, où un exercice supprimé ne doit jamais effacer l'historique. Une
proposition n'est pas de l'historique : si l'exercice n'existe pas, la
proposition n'a aucune raison d'exister. C'est la base de données qui rend
l'invention impossible, pas seulement le code.

## Module API

Structure identique aux autres domaines : `presentation/http` → `application` →
`infrastructure`.

```
apps/api/src/modules/coach/
  coach.module.ts
  presentation/http/
    coach.controller.ts          # mince : aucune logique
    dto/coach.dto.ts             # class-validator, whitelist + forbidNonWhitelisted
  application/
    coach.service.ts             # orchestration d'un tour de conversation
    coach.prompt.ts              # prompt système + assemblage (ordre de cache)
    coach.tools.ts               # définitions + exécution des outils de lecture
    proposal.validator.ts        # rejette toute proposition non conforme
    coach.quota.ts               # compteur Redis + garde
  infrastructure/
    coach.repository.ts          # Prisma
    anthropic.client.ts          # implémentation de CoachModelPort
```

`coach.service.ts` dépasserait 300 lignes s'il portait tout : le prompt, les
outils, la validation et le quota sont donc quatre fichiers, chacun testable
seul.

### Le port du modèle

```ts
export interface CoachModelPort {
  reply(input: CoachTurnInput): Promise<CoachTurnOutput>;
}
```

Une seule frontière avec le fournisseur. Toute la logique métier se teste
contre un faux ; **aucun test n'appelle l'API réelle**, et un changement de
modèle ne touche qu'un fichier.

### Routes

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| `GET` | `/api/v1/coach/conversations` | Liste des fils |
| `POST` | `/api/v1/coach/conversations` | Création (UUID client, idempotent) |
| `GET` | `/api/v1/coach/conversations/:id` | Fil + messages + propositions |
| `POST` | `/api/v1/coach/conversations/:id/messages` | Envoi, renvoie la réponse |
| `POST` | `/api/v1/coach/proposals/:id/accepted` | Marque la proposition acceptée |

L'acceptation **ne crée pas** la séance : l'app la crée par la route de séance
existante, puis signale l'acceptation. Un seul chemin d'écriture pour les
séances, déjà idempotent et déjà testé.

Enveloppes standard (`{ data, meta, requestId }`). Codes d'erreur utilisés :
`FORBIDDEN` (droit absent), `RATE_LIMITED` (quota), `SERVICE_UNAVAILABLE`
(fournisseur indisponible ou coach désactivé).

## Les outils de lecture

Tous en lecture seule, tous branchés sur les services existants — aucun accès
Prisma direct depuis le module coach pour les domaines voisins.

| Outil | Sert à |
| --- | --- |
| `search_exercises` | Trouver un exercice du catalogue (muscle, matériel, difficulté) |
| `list_workout_templates` | Les modèles de l'utilisateur |
| `get_workout_template` | Le détail d'un modèle (exercices, séries, repos) |
| `get_recent_sessions` | Les N dernières séances terminées |
| `get_personal_records` | Les records recalculés à la clôture |
| `get_progress_overview` | Volume, assiduité, tendance sur une période |
| `get_body_weight_trend` | Mesures corporelles |
| `get_nutrition_targets` | Cibles du module métabolisme |
| `propose_session` | **Seul outil « d'écriture »** — n'écrit rien, produit une proposition |

Chaque description dit **quand** appeler l'outil, pas seulement ce qu'il fait :
c'est ce qui pèse le plus sur la qualité du déclenchement.

`propose_session` reçoit une liste d'items ; le serveur la passe à
`proposal.validator.ts` avant tout stockage. Une proposition est rejetée si un
`exerciseId` est inconnu, si les positions ne sont pas contiguës, si une charge
est absurde (> 500 kg, négative), ou si elle est vide. Un rejet n'est pas une
erreur utilisateur : le tour repart une fois avec le motif du rejet, puis
dégrade en réponse purement textuelle.

## Prompt et mise en cache

Ordre de rendu : outils → système → messages. Le point de césure de cache se
pose **sur le dernier bloc système**, donc après le prompt et les définitions
d'outils, et avant l'historique de la conversation.

Interdits absolus dans le préfixe : date du jour, identifiant de requête, nom
de l'utilisateur, toute donnée qui change d'un appel à l'autre. Ils vivent dans
le premier message utilisateur, après la césure. Un `new Date()` dans le prompt
système annulerait la totalité du bénéfice — c'est le piège classique, et il
est silencieux : rien n'échoue, la facture double.

Vérification : `usage.cache_read_input_tokens` doit être non nul dès le
deuxième tour. Un test d'assemblage vérifie qu'aucune donnée volatile
n'apparaît avant la césure.

## Modèle, latence, coût

`claude-opus-5` par défaut, configurable. Réflexion adaptative laissée active
(elle l'est par défaut) ; `effort` bas à moyen pour une conversation, plus haut
pour une adaptation de séance qui demande un vrai arbitrage.

**Ordre de grandeur** : un tour avec préfixe caché coûte environ **un à deux
centimes** — l'essentiel part dans la sortie. Un quota de 30 messages par jour
plafonne donc un utilisateur intensif autour de 50 centimes par jour, ce qui
doit être comparé au prix de l'abonnement avant d'ouvrir la vanne.

**Streaming.** Une réponse non diffusée fait attendre plusieurs secondes devant
un écran figé. Deux options assumées :

- **v1 sans streaming**, avec un état « le coach réfléchit » explicite — plus
  simple, aucune infrastructure SSE à introduire ;
- **v1 avec streaming** (SSE côté API, consommation Dio côté Flutter) — nettement
  meilleur ressenti, une complexité de plus dans une tranche déjà chargée.

**Recommandation : sans streaming d'abord**, avec l'indicateur d'attente soigné,
et le streaming en second temps une fois le reste stabilisé. C'est le seul point
de ce document où je choisis le confort de construction contre le confort
d'usage — à toi de trancher si tu préfères l'inverse.

## Droits, quota, garde-fous

- **Droit `ai_coaching`** : déjà présent dans `ENTITLEMENT_KEYS`, absent de
  `PREMIUM_ENTITLEMENT_KEYS`. L'activer suffit — aucune migration de contrat.
  Vérifié **côté serveur avant tout appel au modèle**, jamais côté client.
- **Quota** : compteur Redis `coach:quota:{userId}:{yyyy-mm-dd}`, plafond
  configurable, `RATE_LIMITED` au-delà. Le compteur s'incrémente **avant**
  l'appel : un échec du fournisseur ne doit pas offrir un tour gratuit à qui
  boucle.
- **Interrupteur global** : `COACH_ENABLED=false` coupe la fonctionnalité sans
  déploiement, en renvoyant `SERVICE_UNAVAILABLE`.
- **Refus du modèle** : un refus se traite comme un contenu, pas comme une
  panne — message clair à l'utilisateur, jamais une erreur 500.
- **Journalisation** : chaque tour trace `requestId`, utilisateur, jetons,
  outils appelés, proposition acceptée ou non. Jamais le contenu du message.

Nouvelles variables validées par Zod dans `env.schema.ts` :
`ANTHROPIC_API_KEY` (optionnelle — si absente, le module se déclare
indisponible au lieu d'empêcher le démarrage), `COACH_MODEL`,
`COACH_DAILY_MESSAGE_LIMIT`, `COACH_ENABLED`.

## Mobile

```
apps/mobile/lib/features/coaching/
  data/{datasources,dto,local,repositories}
  domain/{entities,repositories}
  presentation/{controllers,screens,widgets}
```

Écran `CoachScreen` : en-tête, liste inversée des messages, puces de
suggestion, composeur. Widgets : `CoachMessageBubble`, `CoachSuggestionChips`,
`CoachProposalCard`, `CoachComposer` — chacun sous 250 lignes.

**Hors ligne — écart assumé.** L'historique se lit hors connexion (stocké en
local comme le reste). Le composeur, lui, est **désactivé** avec un état
explicite : une question posée hors ligne recevrait sa réponse des heures plus
tard, ce qui n'est pas une conversation. C'est le seul écran de l'app qui
n'écrit pas hors ligne, et c'est délibéré.

**Les quatre états** sont obligatoires : chargement (`AppLoadingIndicator`),
erreur (`AppErrorState`), vide (`AppEmptyState` avec les suggestions de
départ), hors ligne (état dédié sur le composeur).

**Les puces de suggestion** se calculent depuis l'état réel — modèle de séance
disponible, record récent, poids stagnant — et jamais en dur. Sans données, une
seule puce générique.

**Mode démo.** Le dépôt en mémoire de `lib/demo/` doit servir une conversation
d'exemple, sinon l'APK de démonstration affiche un écran mort.

### Couleurs — une décision à prendre

La maquette montre des bulles utilisateur en dégradé violet → magenta, qui
correspond à `AppColors.signature`. Or ce dégradé est aujourd'hui **réservé aux
surfaces de marque** : sur la page de bienvenue il ne peint que deux éléments,
et `AppBrandButton` documente que deux boutons « principaux » de couleurs
différentes dans un même écran annulent la hiérarchie.

**Recommandation** : bulles utilisateur en `AppColors.primary` (un violet franc,
très proche de la maquette), bulles du coach sur `AppColors.darkSurface`, et le
bouton « Voir la séance » en `AppButton` accent — la couleur d'action de toute
l'application. Le dégradé de signature reste à la marque.

C'est un changement d'une ligne si tu préfères la maquette telle quelle ; il
faudra alors élargir explicitement la portée du jeton et le documenter, plutôt
que de le laisser dériver.

## Tests

**API — unitaires.** Le validateur rejette un `exerciseId` inconnu, des
positions non contiguës, une charge absurde, une proposition vide. La garde de
quota compte avant l'appel et bloque au plafond. L'assemblage du prompt ne
place aucune donnée volatile avant la césure de cache. Le port du modèle est un
faux ; aucun test ne sort du réseau.

**API — e2e.** `403` sans le droit `ai_coaching`, `429` au-delà du quota, `503`
coach désactivé, `200` avec proposition valide, et le cas où le modèle propose
un exercice inconnu — la réponse doit rester utilisable.

**Mobile.** Rendu des bulles, carte de proposition, lancement de séance depuis
« Voir la séance », état hors ligne du composeur, état vide avec suggestions.

## Découpage proposé

1. **Socle serveur** — schéma + migration, module, port du modèle, outils de
   lecture, validateur, quota, droit `ai_coaching`, tests unitaires et e2e.
   Livrable vérifiable sans une seule ligne de Flutter.
2. **Écran mobile** — dépôt, contrôleur, écran, widgets, quatre états, mode
   démo, tests widget.
3. **Finitions** — suggestions calculées depuis l'état réel, acceptation de
   proposition branchée sur la création de séance, documentation Swagger et
   `docs/`.

Le streaming, s'il est retenu, s'insère entre 2 et 3.

## Décisions ouvertes

1. **Streaming en v1 ou en v2 ?** Ma recommandation : v2.
2. **Bulles en `primary` ou dégradé de signature ?** Ma recommandation :
   `primary`.
3. **Quota quotidien** — 30 messages par jour est une valeur de départ, à caler
   sur le prix de l'abonnement.
4. **Point d'entrée** — carte sur l'accueil et lien depuis le débrief de séance,
   plutôt qu'un sixième onglet. À confirmer.
