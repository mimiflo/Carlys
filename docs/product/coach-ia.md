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

**Ce qu'il ne fait pas, et le dit.** Rien sur le sommeil ni la fréquence
cardiaque (aucune donnée de santé n'est collectée), aucun diagnostic de
blessure ni conseil médical. Ces limites sont écrites dans le prompt système
**et** testées.

**Deux limites sont TOMBÉES depuis, et ce paragraphe les annonçait encore.**
L'alimentation en est sortie : le journal de repas existe, et le coach le lit
par `get_nutrition_targets` et `get_recent_meals` — il connaît donc les
objectifs caloriques et ce qui a été noté, et rien de plus, ce que le prompt
dit désormais à sa place (« un journal vide veut dire qu'il n'a rien noté,
pas qu'il n'a rien mangé »). Le programme hebdomadaire est
entré à son tour le 30 septembre 2026 : le coach en propose les réglages,
le générateur du module `programs` le construit (section « Programme proposé
par le coach »).

**Ce qui n'est pas dans la tranche :** la voix, les notifications
proactives. Le programme, lui, y est entré le 30 septembre 2026 — voir
« Programme proposé par le coach » ci-dessous.

### Programme proposé par le coach

**Le besoin** (demande du propriétaire, 30 septembre 2026) : le coach doit
pouvoir proposer un PROGRAMME, pas seulement une séance.

**Le partage des rôles, et pourquoi.** Le coach ne compose pas le programme :
il en choisit les RÉGLAGES — objectif, séances par semaine, durée d'une
séance — et c'est le générateur déterministe du module `programs`
(`PUT /programs/:id/generate`) qui le construit, avec les mêmes règles que
l'écran « Préparer mon programme ». Un modèle de 4 milliards de paramètres
qui écrirait trente séances inventerait des exercices et des volumes ; le
générateur, lui, est testé, respecte le matériel et le niveau, et explique
ses choix. L'IA propose, l'application exécute — ici plus que jamais.

**Côté serveur.**

- `get_training_profile` (lecture) : objectif, niveau, rythme, durée,
  matériel, et le programme actif s'il y en a un. Le coach le lit avant de
  proposer, pour ne pas proposer ce qui est déjà en place.
- `propose_program` : `{ goal, weeklySessions, sessionMinutes }`, bornes
  du contrat (`TRAINING_WEEKLY_SESSIONS_MIN/MAX`, `TRAINING_SESSION_MINUTES_MIN/MAX`).
  Contrairement à `propose_session`, c'est un outil ORDINAIRE, intercepté par
  le service pendant le tour : un réglage hors bornes revient au modèle comme
  une erreur qu'il corrige lui-même, au lieu de faire tomber la proposition
  en silence. La dernière proposition valide du tour est gardée.
- Elle s'archive avec la réplique (`CoachProgramProposal`, une par message),
  et `POST /coach/program-proposals/:id/accepted { programId }` note le
  programme qui en est né — la même mesure que pour les séances.

**Côté appli.** Une carte « Programme proposé » sous la réplique : objectif,
rythme, durée, et « Créer ce programme ». L'appui applique les trois réglages
au profil d'entraînement (les mêmes actions que l'écran de préparation),
engendre le programme, note l'acceptation, et ouvre le programme — qui naît
INACTIF, comme toujours : on le relit, puis on l'active. Un profil incomplet
(niveau ou matériel jamais renseignés) : le message du serveur s'affiche et
l'écran de préparation s'ouvre. Déjà acceptée, la carte dit « Voir le
programme » et y ramène, sans en créer un second.

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

  conversation    CoachConversation     @relation(fields: [conversationId], references: [id], onDelete: Cascade)
  proposal        CoachSessionProposal?
  programProposal CoachProgramProposal?

  @@index([conversationId, createdAt])
}

/// Programme proposé : ses RÉGLAGES, pas son contenu (voir « Programme
/// proposé par le coach »). Migration `20260930145758_coach_programme_propose`.
model CoachProgramProposal {
  id                String       @id @db.Uuid
  messageId         String       @unique @db.Uuid
  goal              TrainingGoal
  weeklySessions    Int
  sessionMinutes    Int
  acceptedProgramId String?      @db.Uuid
  createdAt         DateTime     @default(now())

  message CoachMessage @relation(fields: [messageId], references: [id], onDelete: Cascade)
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
    openai-compatible.client.ts  # CoachModelPort, API compatible OpenAI (Mistral…)
    anthropic.client.ts          # CoachModelPort, Anthropic
```

Le fournisseur est un **réglage** (`coachModelFor`, dans `coach.module.ts`) :
`COACH_API_BASE_URL` posée, le client compatible OpenAI ; absente, le client
Anthropic. Voir
[l'ADR 0010](../decisions/0010-coach-fournisseur-compatible-openai.md).

`coach.service.ts` dépasserait 300 lignes s'il portait tout : le prompt, les
outils, la validation et le quota sont donc quatre fichiers, chacun testable
seul.

Ce plafond n'est plus une consigne écrite : `max-lines` l'applique dans
`apps/api/eslint.config.mjs` (moins de 300 lignes pour `src/**/*.service.ts`,
moins de 200 pour `src/**/*.controller.ts`, soit `max: 299` et `max: 199`,
l'option étant inclusive ; blancs et commentaires compris, comme `wc -l`).
La restitution du quota sur panne du fournisseur a fait passer
`coach.service.ts` au-dessus : l'erreur `CoachQuotaExceededError` a rejoint
`coach.quota.ts`, où elle a sa place. Avec la ligne « Tour de coach
interrompu », le service est à 298 lignes : la prochaine fonctionnalité du
coach se découpe *avant* d'être écrite, pas après que le lint l'a refusée.
`app-config.service.ts` est à 299 lignes après l'ajout de `coachProvider` :
la prochaine variable d'environnement impose de le découper par domaine.

### Le port du modèle

```ts
export interface CoachModelPort {
  reply(input: CoachTurnInput): Promise<CoachTurnOutput>;
}
```

Une seule frontière avec le fournisseur. Toute la logique métier se teste
contre un faux ; **aucun test n'appelle l'API réelle** (les deux clients se
testent avec un `fetch` simulé), et changer de fournisseur est un réglage.
Les règles communes aux deux clients (6 tours d'outils, 2048 jetons de
sortie, échéance du tour entier — 50 s d'un bloc, 3 min en flux —, textes
de refus et d'abandon)
sont exportées par le port, jamais recopiées.

### Routes

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| `GET` | `/api/v1/coach/conversations` | Liste des fils |
| `POST` | `/api/v1/coach/conversations` | Création (UUID client, idempotent) |
| `GET` | `/api/v1/coach/conversations/:id` | Fil + messages + propositions |
| `POST` | `/api/v1/coach/conversations/:id/messages` | Envoi, renvoie la réponse ; rejouable (même identifiant, même contenu → même réponse, sans tour ni appel au modèle). Gardée pour les versions de l'appli d'avant le flux |
| `POST` | `/api/v1/coach/conversations/:id/messages/stream` | Même envoi, réponse en flux SSE : `delta` à chaque morceau, puis `done` (même `CoachReply`) ou `error` — voir l'ADR 0012 |
| `POST` | `/api/v1/coach/proposals/:id/accepted` | Marque la proposition acceptée |
| `POST` | `/api/v1/coach/program-proposals/:id/accepted` | Note le programme engendré depuis un programme proposé (204, n'écrit aucun programme) |

L'acceptation **ne crée pas** la séance : l'app la crée par la route de séance
existante, puis signale l'acceptation. Un seul chemin d'écriture pour les
séances, déjà idempotent et déjà testé.

Enveloppes standard (`{ data, meta, requestId }`). Codes d'erreur utilisés :
`FORBIDDEN` (droit absent), `RATE_LIMITED` (quota), `CONFLICT` (même
identifiant de message avec un autre contenu), `NOT_FOUND` (fil d'autrui, ou
identifiant déjà porté par un autre fil), `SERVICE_UNAVAILABLE` (fournisseur
indisponible ou coach désactivé). Un 429 du fournisseur, dont le quota est
GLOBAL, devient lui aussi `SERVICE_UNAVAILABLE`, jamais `RATE_LIMITED` : le
téléphone afficherait « ta limite du jour ».

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
| `get_nutrition_targets` | Cibles du module métabolisme (des objectifs, jamais le consommé) |
| `get_recent_meals` | Le journal alimentaire : repas notés sur les N derniers jours (1 par défaut, 7 au plus), en instants UTC — nom, moment de la journée (`null` s'il n'a pas été noté), totaux, `computed`, et pour un repas composé ses aliments en clair (« Poulet, filet, sans peau, cuit : 120 g ») ; pas le détail d'écran de chaque composant, qui coûterait des jetons sans rien apprendre au modèle (`coach-meal-view.ts`). JAMAIS la photo du repas, ni même le fait qu'il en ait une : la vue ne recopie pas `photo`, et `docs/legal/privacy.md` promet qu'elle n'est transmise à aucun prestataire |
| `propose_session` | **Seul outil « d'écriture »** — n'écrit rien, produit une proposition |

Chaque description dit **quand** appeler l'outil, pas seulement ce qu'il fait :
c'est ce qui pèse le plus sur la qualité du déclenchement.

`propose_session` reçoit une liste d'items ; le serveur la passe à
`proposal.validator.ts` avant tout stockage. Une proposition est rejetée si un
`exerciseId` est inconnu, si les positions ne sont pas contiguës, si une charge
est absurde (> 500 kg, négative), ou si elle est vide. Un rejet n'est pas une
erreur utilisateur : la réponse texte reste, sans séance, et le rejet est
journalisé (« Proposition du coach rejetée »).

## Prompt et mise en cache

Ordre de rendu : outils → système partagé (césure) → bloc par utilisateur →
messages. Le point de césure de cache se pose **sur le bloc système
partagé**, donc après le prompt et les définitions d'outils — identiques pour
tous les utilisateurs — et avant tout ce qui varie.

Interdits absolus dans le préfixe : date du jour, identifiant de requête, nom
de l'utilisateur, toute donnée qui change d'un appel à l'autre — ou d'un
utilisateur à l'autre. Ils vivent après la césure. Un `new Date()` dans le
prompt système annulerait la totalité du bénéfice — c'est le piège classique,
et il est silencieux : rien n'échoue, la facture double.

**La voix du Mentor** : le bloc système par utilisateur compose DEUX axes
(`mentorVoiceBriefing`) — le profil Carlys
(Constructeur/Challenger/Athlète/Stratège : l'ANGLE, qui est la personne)
et le style du Mentor (Bienveillant/Exigeant/Athlète/Philosophe : la VOIX,
comment lui parler). Deux fonctions pures des énumérations — jamais de
texte libre — jointes par une ligne vide : 4 briefings + 4, jamais 16
croisements. Le tout part en second bloc système, **après** la césure via
`CoachTurnInput.systemPerUser`. Les briefings orientent le ton, jamais les
chiffres — les chiffres viennent des outils. Un nom de profil OU de style
dans le préfixe partagé le fragmenterait en variantes de cache : un test
l'interdit explicitement pour les deux axes, et la composition rend la
chaîne vide (pas un saut de ligne orphelin) quand rien n'est choisi.
Voir [mentor.md](mentor.md) pour le personnage complet.

Vérification, chez Anthropic : `usage.cache_read_input_tokens` doit être
non nul dès le deuxième tour. Chez un fournisseur compatible OpenAI, il n'y a
pas de césure explicite : `cacheReadTokens` vaut ce qu'il déclare (souvent
0), ce n'est pas un préfixe cassé. La règle du préfixe stable reste gardée,
elle ne coûte rien ailleurs. Un test d'assemblage vérifie qu'aucune donnée volatile
n'apparaît avant la césure, et l'e2e vérifie que le préfixe reste identique
octet pour octet, briefing ou pas.

## Modèle, latence, coût

**Décision du 29 septembre 2026 : le coach tourne sur notre serveur**
([ADR 0011](../decisions/0011-coach-qwen3-sur-le-serveur.md)). Modèle
Qwen3-4B, variante instruct 2507 (`qwen3:4b-instruct-2507-q4_K_M`, sans « réflexion »),
servi par Ollama (service `ollama` de la pile, profil `ollama`), sans quota
ni facture, et sans que les messages quittent la machine. Réglage :
`CARLYS_OLLAMA_REPLICAS=1`, `COACH_API_BASE_URL=http://ollama:11434/v1`,
`COACH_MODEL=qwen3:4b-instruct-2507-q4_K_M` (pas à pas dans
[mise-en-route-serveur.md](../deployment/mise-en-route-serveur.md), « Coach
IA sur le serveur »). Mistral Free mode, retenu le 27 septembre, a refusé
toutes les demandes dès le lendemain. Mistral ou Anthropic restent possibles
(`COACH_MODEL` facultatif pour Anthropic, `claude-opus-5-5` par défaut), mais
**les textes légaux passent d'abord** : ils disent aujourd'hui qu'aucun
prestataire d'IA ne reçoit les messages, et `privacy.md` promet d'être mis
à jour AVANT que les messages partent chez un prestataire. Dans l'ordre : `privacy.md` (nommer Anthropic PBC, le remettre parmi les
traitements hors de l'Union européenne, des marqueurs pour sa conservation
et l'entraînement) et `terms.md`, redéploiement de l'admin, et seulement
ensuite retirer `COACH_API_BASE_URL` et poser `ANTHROPIC_API_KEY`. Chez
Anthropic, le client pose l'effort `medium` (le défaut de Claude Opus 5.5,
écrit pour qu'un changement de modèle ne le déplace pas en silence) et le
repli serveur sur refus (`fallbacks: "default"`) : un faux positif d'un
classifieur de sécurité — compléments, blessure — est repris par un autre
modèle dans le même appel au lieu de rendre « Je ne peux pas répondre ».
Rien de tel n'est envoyé au fournisseur compatible OpenAI. Chez Anthropic, la
réponse arrive d'un bloc (≈ 5 à 15 s), pas mot à mot : le client n'écrit pas
encore en flux.

**Ce que « sur le serveur » implique.** Plus de quota de fournisseur : la
limite, c'est le processeur. Une réponse à la fois (`OLLAMA_NUM_PARALLEL=1`),
le modèle gardé en mémoire, un contexte de 8 192 jetons ; la vitesse se
mesure au déploiement (guide, étape 5) et doit tenir dans l'échéance
ci-dessous, attente dans la file d'Ollama comprise : deux messages
simultanés, le second peut recevoir un 503. Le plafond par personne (`COACH_DAILY_MESSAGE_LIMIT`) protège
désormais la machine, plus une facture.

**Latence.** Une seule échéance couvre le tour entier (tentatives et
outils) : **3 minutes en flux** (`COACH_REQUEST_TIMEOUT_MS`, réglable), **50 s d'un
bloc** (`COACH_TURN_DEADLINE_MS`, sous les 60 s de nginx). En flux, les 60 s
de nginx ne comptent qu'entre deux octets, et il en passe toujours : le texte,
ou un battement (`: ping`, commentaire SSE que tout client ignore) toutes les
15 s pendant que le coach relit des séances sans rien écrire
(`sseKeepAlive`, `common/http/sse.ts`). Le premier battement ne part qu'après
15 s : un refus (quota, fil inconnu) garde son statut HTTP. Mesuré le
30 septembre 2026 sur le serveur, Qwen3-4B écrit ≈ 8 jetons/s : relire des
séances puis répondre y dépassait 50 s, et la réponse s'arrêtait net —
c'était le « il s'arrête » signalé. Le client compatible OpenAI réessaie deux
fois un 429 ou un 5xx (pauses de 1 puis 2 s) ; toute autre panne (réseau,
échéance, réponse illisible, génération interrompue avec
`finish_reason: error`, 4xx) donne un 503 dont le journal ne porte que le
statut, jamais le corps ni la clé. Côté mobile, l'envoi d'un message attend
ses en-têtes 65 s (`coachReplyTimeout`, `coach_repository_impl.dart`) — le
premier battement arrive bien avant ; les autres appels gardent les 20 s du
client partagé (`dio_client.dart`).

**Ce qui accélère une réponse sur processeur** (30 septembre 2026). Le
préfixe commun — consignes (≈ 1 080 jetons) et outils (≈ 1 660) — est gardé
en mémoire par Ollama d'une question à l'autre : il ne se paie qu'au
chargement du modèle. Ce qui se paie à CHAQUE tour d'outil, c'est ce que les
outils rendent. Les lectures passent donc par des vues
(`application/coach-views.ts`, comme `coach-meal-view.ts`) qui retirent les
identifiants de ligne, révisions et champs vides que le modèle ne fait que
relire : mesuré sur un jeu réaliste, 10 séances passent de ≈ 1 140 à ≈ 470
jetons, un modèle de 6 exercices × 4 séries de ≈ 1 730 à ≈ 710, 15 records de
≈ 1 040 à ≈ 780 (on y garde `exerciseId`, réutilisable dans une
proposition). Chronométré le même jour avec le vrai prompt et les vrais
outils (Qwen3-4B q4_K_M, Ollama 0.34.4, 4 cœurs sans GPU, deux passes
identiques) sur un tour qui relit 10 séances, les records et un modèle : la
lecture passe de 215 à 80 s et le tour de 275 à 148 s ; l'écriture accélère
aussi (2,3 → 3,2 jetons/s), parce qu'un contexte plus court coûte moins à
chaque jeton produit. Ces secondes sont celles d'une machine de test : sur
le serveur, seule la proportion se transpose. Le modèle est aussi PRÉCHARGÉ
au démarrage du service `ollama`
(`compose.yml`) : la première question après un redémarrage n'attend plus
le chargement des 2,5 Go.

**Ordre de grandeur, si Anthropic est réglé** : un tour avec préfixe caché
coûte environ **un à deux centimes**, l'essentiel part dans la sortie. Un
quota de 30 messages par jour plafonne donc un utilisateur intensif autour de
50 centimes par jour, à comparer au prix de l'abonnement.

**Streaming : fait** (septembre 2026, ADR 0012). La question s'affiche
aussitôt, une bulle « Réfléchit… » attend le premier mot, puis la réponse
s'écrit à mesure qu'Ollama la produit. Un renvoi de la même question pendant
qu'elle s'écrit est refusé (409) par un verrou Redis, au lieu d'être compté et
répondu deux fois.

## La passerelle : file, workers, annulation (ADR 0013)

Aucune route ne touche le modèle sans `CoachGateway` (l'« AIService ») :

```
mobile ─SSE─▶ CoachController ─▶ CoachService (porte, verrou, rejeu)
                                   └▶ CoachGateway.admit : taille, rythme/min,
                                      1 génération par personne, file pleine → 503 SERVICE_BUSY
                                   └▶ CoachTurnRunner : contexte, quota, question écrite
                                      └▶ CoachGateway.generate : attente du créneau (queued),
                                         CoachModelPort ─▶ CoachWorkerPool ─▶ Ollama 1…N
                                      └▶ réponse archivée, mémoire rafraîchie en fond
```

- **File partagée (Redis, `CoachGate`)** : créneaux en cours (bail de 60 s
  renouvelé, qui expire seul si un exemplaire meurt), attentes dans l'ordre
  d'arrivée, attentes muettes depuis 30 s retirées. Tous les exemplaires de
  l'API voient la même file.
- **En flux**, l'évènement `queued` (`{ ahead }`) dit combien de demandes
  passent avant, `started` que son tour est venu ; le mobile affiche « En
  attente ». Refus propre au-delà : file pleine, ou attente plus longue que
  `COACH_QUEUE_TIMEOUT_MS`. Sans flux (anciennes versions de l'appli),
  l'attente est plafonnée à 5 s : le tour doit tenir sous les 60 s de nginx.
- **Le quota se décompte APRÈS la file**, juste avant le modèle : un « très
  sollicité » ou une annulation en attente ne coûte rien. Un plafond du jour
  déjà atteint répond 429 AVANT d'entrer dans la file.
- **Annulation** : la connexion fermée (écran quitté, « Arrêter », réseau
  coupé) annule l'attente ou la génération ; le client abandonne l'appel au
  worker, qui arrête d'écrire. Rien de consommé : le message est rendu (trois
  fois par jour au plus, comme une panne). Revirement de l'ADR 0012, où le
  tour continuait pour s'archiver.
- **Workers (`CoachWorkerPool`)** : le moins occupé sert ; une panne réseau
  ou un 5xx l'écarte `COACH_WORKER_COOLDOWN_MS` et la tentative suivante part
  sur un autre. Ajouter une carte graphique : une adresse dans
  `COACH_WORKER_URLS`, et `COACH_MAX_CONCURRENT_REQUESTS` relevé d'autant. Le
  mobile n'en sait rien.
- **Mesures** : une ligne `CoachGeneration` par génération (instants,
  statut, jetons, worker — jamais le texte) ; les séries Prometheus
  `carlys_api_ai_*` sur `/metrics` ; l'état sur `/internal/ai/health` et
  `/internal/ai/metrics`, protégés comme `/metrics`.
- **Contexte (`CoachContextBuilder`)** : consignes (préfixe commun) → voix
  du mentor, profil d'entraînement en une ligne, mémoire résumée → messages
  pas encore résumés (`COACH_HISTORY_MESSAGES` au plus) → question. Le profil en une
  ligne épargne un tour d'outil aux questions courantes ; le détail (séances,
  records, repas) reste derrière les outils.
- **Mémoire (`CoachMemory`)** : quand les messages pas encore résumés
  dépassent la fenêtre (`COACH_HISTORY_MESSAGES`), un résumé (objectif,
  préférences, progression, décisions) fond les plus anciens dans
  `CoachConversation.summary` et n'en laisse que la moitié la plus récente
  (`memoryKeep`), par lots de 30 au plus (600 caractères par
  message, 6 000 en tout, 300 jetons de sortie, 2 min au plus). Écrit après
  une réponse, **seulement si personne n'attend**, et il **cède sa place**
  dès qu'une personne entre dans la file (contrôle toutes les 2 s). Nos
  workers seulement, jamais le repli cloud. Raté, la conversation est
  laissée en paix 10 min. Relu comme une DONNÉE entre balises `<memoire>`,
  jamais comme une consigne.
- **Cache** : Ollama ne relit pas le début d'un texte qu'il a déjà calculé
  (il le garde, et le restaure même après d'autres questions). Les consignes
  et les outils (≈ 2 560 jetons) sont des constantes, donc lus une fois pour
  tout le monde. L'historique **avance par paliers** au lieu de glisser : il
  part de la fin du résumé, et ce début ne bouge qu'avec lui, une fois tous
  les 5 tours. D'un tour à l'autre, le texte envoyé prolonge donc le
  précédent et seule la fin est relue. Mesuré le 1er octobre 2026 (4 cœurs,
  tours 12 à 20 d'une conversation) : 29 s de lecture par tour avec une
  fenêtre glissante, **7 s en moyenne** par paliers (5 s, et 15 s au tour
  où le résumé avance). Limite connue : le résumé cède sa place à toute
  personne qui entre dans la file ; dans une conversation où l'on répond
  plus vite qu'il ne s'écrit (jusqu'à 2 min sur processeur), il est remis
  au tour suivant, et la fenêtre glisse en attendant, comme avant. Et il ne
  coupe jamais entre une question et sa réponse.
  Piste écartée, mesurée le même jour : le résumé, avec ses propres
  consignes, ne chasse PAS le préfixe commun (la personne suivante a
  retrouvé 2 654 jetons sur 2 661 en cache) ; lui faire réutiliser les
  consignes du coach n'apportait rien.
  Les résultats d'outils passent par des vues allégées (`coach-views.ts`,
  `coach-meal-view.ts`) : 10 pesées, 783 jetons complètes, 223 allégées ;
  10 exercices du catalogue, 1 962 contre 582.
- **Ce que le modèle écrit n'est pas ce que le catalogue range** (constaté le
  1er octobre 2026 sur Qwen3-4B). Il cherchait « pecs », « pectoral », ou
  glissait le muscle dans les mots du nom : la recherche revenait vide, et
  le coach concluait « aucun exercice pour les pectoraux ».
  `coach-exercise-search.ts` traduit : slug, nom, accents, début de mot non
  ambigu, mots de salle (pecs, abdos, ischios) ; un mot de la recherche qui
  nomme un groupe ou un matériel en devient le filtre ; sans résultat, les
  mots du nom sont relâchés. Un nom inconnu revient au modèle AVEC la liste
  des valeurs, et il corrige au tour suivant. Si le nom tel quel ne donne
  rien, la recherche compare chaque mot sans accents et dans n'importe quel
  ordre (« developpe couche ») ; une recherche qui ne nomme qu'un groupe
  (« avant-bras ») rend le groupe entier ; les exercices dont c'est le
  muscle PRINCIPAL passent devant, 15 au plus (la plus grosse combinaison
  groupe + matériel du catalogue). `coach-catalog.spec.ts` balaie tout le
  catalogue (`catalog-data.ts`) à chaque test : chaque exercice par son nom
  (exact, minuscules, sans accents, partiel, mots inversés), par son groupe
  principal avec chacun de ses matériels, chaque groupe et matériel nommé
  comme on le dit. Avant correctif, 93 noms sur 190 étaient introuvables
  sans leurs accents.
- **L'annonce sans l'action.** Un petit modèle rend parfois la main sur une
  promesse : « Je cherche… Une minute. », « Je vais t'adapter une séance à
  partir de ton profil. », ou une séance écrite en texte, « j'ai fait une
  séance de base », sans la carte qui la rend jouable. Aucune liste de
  phrases ne tient seule (chaque essai réel en trouvait une nouvelle) ;
  deux étages, mesurés sur Qwen3-4B le 1er octobre 2026
  (`infrastructure/announced-action.ts`) :
  1. **Quand demander.** Une séance ou un programme DEMANDÉ par la personne
     (« Je veux une séance haut du corps ») et pas proposé, une séance
     donnée pour faite sans carte, ou une fin de message qui parle d'une
     suite (« je vais », « je m'occupe », « un instant »…, sur les deux
     dernières phrases). Jamais après une proposition, jamais sur une
     question posée en retour.
  2. **L'occasion d'agir.** Un message automatique, jamais montré ni
     archivé : un ORDRE de proposer (lire les identifiants, puis
     `propose_session` ou `propose_program`) dans les deux premiers cas,
     une question qui CITE la fin du message dans le troisième (« FIN » si
     la réponse est complète). C'est l'appel d'outil qui tranche, pas le
     texte. Deux fois par tour au plus ; la réponse déjà écrite reste en
     tête de la réplique.
  Sur sept promesses réelles et neuf réponses complètes, le premier étage
  retient les sept et aucune des neuf ; les trois demandes de séance du banc
  final finissent toutes sur une carte. Écartés après mesure : demander au
  modèle de juger sa propre réponse (il répondait « non » à sa promesse), et
  offrir l'occasion à toute réponse sans outil (il fouillait ses données et
  gâchait une explication complète). Elle part au worker qui a servi le
  début du tour : lui seul garde la conversation en cache.
- **Ses données, lues avant de répondre.** Le modèle appelait ses outils de
  lecture quand il y pensait, et inventait sinon (« Tu as déjà des records
  de soulevé de terre », « j'ai vu tes dernières séances », sans rien lire).
  Deux étages :
  1. **Lire d'abord** (`application/coach-prefetch.ts`). Quand la question
     porte sur ses données (« mon record », « est-ce que je progresse »,
     « j'ai maigri », « mes calories », « par où je commence »), le serveur
     lit les bonnes vues AVANT que le modèle n'écrive, et les lui présente
     comme des outils déjà appelés. Une question de savoir (« explique-moi
     la surcharge progressive ») ne lit rien et ne coûte rien.
  2. **Le filet.** Une réponse qui affirme avoir « vu » ses données, ou cite
     un chiffre à son sujet, sans aucune lecture dans le tour, reçoit l'ordre
     de lire puis de réécrire : la version corrigée REMPLACE la fausse.
  Mesuré sur Qwen3-4B le 2 octobre 2026 : record, progression, poids,
  protéines et dernières séances cités tels que l'appli les connaît, en un
  seul tour ; le filet ne retient aucune des neuf réponses complètes du
  banc et attrape les cinq inventions types.
- **Les noms du catalogue.** « Le deadlift », « le press de poitrine » : la
  consigne demande les noms du catalogue, et `coach-exercise-names.ts` les
  garantit pour les termes connus (« soulevé de terre », « développé
  couché »…), dans le flux comme dans la réponse archivée, sans jamais
  toucher un nom du catalogue (« Hip thrust », « Push Press »).
Sur l'appli, « Réfléchit… » reste
  sous le texte jusqu'à la fin du tour : entre deux recherches, la bulle ne
  semble plus finie. Les lectures par personne (profil, voix) coûtent quelques
  millisecondes contre des dizaines de secondes de génération : les mettre en
  cache ne se mesurerait pas, et aucune réponse n'est jamais mise en cache.
- **Capacité** : se mesure, ne s'estime pas. `carlysctl coach-bench <env>`
  (`scripts/server/README.md`) envoie des questions réelles, par le chemin du
  téléphone, palier par palier.

### Première mesure (30 septembre 2026)

Machine de développement, **4 cœurs de processeur, 16 Go, sans carte
graphique**, Qwen3-4B q4_K_M sous Ollama, `OLLAMA_NUM_PARALLEL=1`, réglages
par défaut (1 génération à la fois, file de 20, 120 s d'attente au plus).
Tous les comptes du banc posent la même question avec le même profil : le
préfixe calculé d'Ollama sert donc d'une personne à l'autre. C'est le
**meilleur cas** ; de vraies personnes relisent en plus leur bloc personnel.

| Simultanés | Réussies | « Très sollicité » | Erreurs | Réponses/min | 1er mot p50 / p95 | Réponse p50 / p95 |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 1 | 0 | 0 | 0,6 | 84,9 s / 84,9 s | 108,9 s / 108,9 s |
| 5 | 5 | 0 | 0 | 2,8 | 52,8 s / 82,4 s | 67,8 s / 105,8 s |
| 10 | 7 | 3 | 0 | 3,1 | 55,9 s / 115,3 s | 75,8 s / 133,5 s |
| 25 | 6 | 19 | 0 | 2,7 | 40,4 s / 113,7 s | 62,7 s / 131,8 s |
| 50 | 7 | 43 | 0 | 3,0 | 66,7 s / 118,3 s | 83,4 s / 140,7 s |
| 100 | 7 | 93 | 0 | 3,2 | 54,6 s / 112,9 s | 74,1 s / 130,4 s |

Ce qu'elle dit :

- **Le goulot est le processeur qui fait tourner le modèle** : Ollama à
  400 % (4 cœurs sur 4) pendant toute la mesure ; PostgreSQL 10 % au plus,
  Redis 4 %, l'API 2 % et 220 Mo ; 5,5 Go de mémoire sur 16.
- **La lecture de la question coûte plus que la réponse** : 2 698 jetons
  d'entrée (consignes, outils, profil) lus à 32 jetons/s, soit 85 s avant le
  premier mot quand rien n'est en cache ; ≈ 100 jetons écrits ensuite en
  ≈ 20 s. Préfixe en cache, un tour dure ≈ 20 s : **≈ 3 réponses par minute,
  quel que soit le nombre de personnes**.
- Au-delà de ≈ 7 personnes à la fois, la file tient 120 s puis répond
  « très sollicité » : aucune erreur, aucune attente sans fin, aucun
  plantage, jusqu'à 100 simultanées.
- Un démarrage à froid (modèle pas encore en mémoire) a pris plus de 3 min
  sur ce disque : le premier tour a dépassé l'échéance de 180 s.

## Droits, quota, garde-fous

- **Droit `ai_coaching`** : déjà présent dans `ENTITLEMENT_KEYS`, absent de
  `PREMIUM_ENTITLEMENT_KEYS`. L'activer suffit — aucune migration de contrat.
  Vérifié **côté serveur avant tout appel au modèle**, jamais côté client.
- **Quota** : compteur Redis `coach:quota:{userId}:{yyyy-mm-dd}`, plafond
  configurable, `RATE_LIMITED` au-delà. Le compteur s'incrémente **avant**
  l'appel, atomiquement : deux envois simultanés ne passent jamais tous deux
  sous le plafond. **Un fournisseur tombé (503) dès son premier appel rend
  le message** (`refundIfUnavailable`, décision du propriétaire du 27
  septembre 2026) : la personne n'a rien reçu, et rien n'a été consommé. Deux
  bornes : un tour qui tombe APRÈS un appel servi (tour d'outils) garde le
  décompte, ses jetons sont partis ; et trois restitutions au plus par
  personne et par jour (`COACH_REFUNDS_PER_DAY`, compteur
  `coach:refund:{userId}:{yyyy-mm-dd}`), sans quoi qui insiste pendant une
  panne, ou la provoque en saturant les limites partagées du Free mode,
  appellerait le fournisseur sans fin. Le message est rendu au jour où il a
  été compté, même si minuit passe entre-temps, et un envoi refusé au plafond
  rend aussi son incrément, sinon il avalerait sous concurrence un message
  rendu. Une panne de notre propre code (500) garde le décompte : elle ne se
  rejoue pas gratuitement.
- **Interrupteur global** : `COACH_ENABLED=false` coupe la fonctionnalité sans
  déploiement, en renvoyant `SERVICE_UNAVAILABLE`.
- **Refus du modèle** : un refus se traite comme un contenu, pas comme une
  panne — message clair à l'utilisateur, jamais une erreur 500. Seul le
  client Anthropic en reçoit (`stop_reason: refusal`) : Mistral n'émet ni
  `finish_reason: content_filter` ni champ `refusal` (enum de son OpenAPI :
  `stop`, `length`, `model_length`, `error`, `tool_calls`), le client
  compatible OpenAI n'en guette donc aucun.
- **Garde-fous santé du prompt**, pour tout fournisseur : renvoi vers un
  professionnel face à une douleur ou un symptôme ; aucun apport sous les
  planchers de l'application (1200 kcal femme, 1500 homme, lus dans
  `metabolism.calculator.ts`) ni perte de plus d'un kilo par semaine ;
  aucun conseil de régime face à des signes de trouble alimentaire ; rien sur
  les produits dopants ni les dosages de médicaments ; texte brut sans
  Markdown, que le téléphone affiche tel quel. Chaque consigne a son
  assertion dans `coach.prompt.spec.ts`.
- **Journalisation** : chaque tour trace `requestId`, utilisateur, jetons,
  outils appelés, proposition acceptée ou non. Un tour que le fournisseur
  interrompt écrit « Tour de coach interrompu » (avertissement) avec les
  jetons déjà consommés et le statut : sans elle, ces jetons ne
  figureraient nulle part. Jamais le contenu du message.

Variables validées par Zod dans `env.schema.ts`, toutes optionnelles : un
fournisseur incomplet rend le coach indisponible (503) au lieu d'empêcher le
démarrage.

| Variable | Rôle |
| --- | --- |
| `COACH_API_BASE_URL` | Posée : API compatible OpenAI (`http://ollama:11434/v1` sur le serveur, ou `https://api.mistral.ai/v1`). Absente : Anthropic |
| `COACH_API_KEY` | Clé de cette API. Absente pour un Ollama interne ; présente, jamais vide |
| `COACH_MODEL` | Exigé avec `COACH_API_BASE_URL` (`qwen3:4b-instruct-2507-q4_K_M` sur le serveur) ; sinon `claude-opus-5-5` |
| `CARLYS_OLLAMA_REPLICAS` | Serveur : 1 allume le service `ollama` (profil compose activé par `dc`) ; absent ou 0, le service n'existe pas |
| `ANTHROPIC_API_KEY` | Lue seulement sans `COACH_API_BASE_URL` |
| `COACH_DAILY_MESSAGE_LIMIT` | Plafond par personne et par jour (30) |
| `COACH_ENABLED` | Interrupteur global |
| `COACH_MAX_CONCURRENT_REQUESTS` | Générations simultanées, tous exemplaires de l'API confondus (1). Égale la somme des `OLLAMA_NUM_PARALLEL` des workers |
| `COACH_QUEUE_MAX_SIZE` | Attentes au-delà desquelles une demande est refusée tout de suite, 503 `SERVICE_BUSY` (20) |
| `COACH_QUEUE_TIMEOUT_MS` | Attente maximale dans la file (120 000) |
| `COACH_REQUEST_TIMEOUT_MS` | Échéance d'une génération en flux, file non comprise (180 000) |
| `COACH_MAX_OUTPUT_TOKENS` | Jetons de sortie par appel au modèle (2 048) |
| `COACH_MAX_CONCURRENT_PER_USER` | Générations simultanées pour une personne, file comprise (1) |
| `COACH_MESSAGES_PER_MINUTE` | Messages par personne et par minute, en plus du plafond du jour (6) |
| `COACH_MAX_MESSAGE_CHARS` | Taille d'un message ; le contrat en borne déjà 2 000 (2 000) |
| `COACH_HISTORY_MESSAGES` | Messages relus tels quels, au plus ; au-delà, la mémoire résumée absorbe les plus anciens et en garde la moitié (20) |
| `COACH_WORKER_URLS` | Adresses `…/v1` des workers, séparées par des virgules ; absente, le seul worker est `COACH_API_BASE_URL` |
| `COACH_WORKER_COOLDOWN_MS` | Mise à l'écart d'un worker en panne (30 000) |
| `COACH_CLOUD_FALLBACK` | Repli sur Anthropic quand aucun worker ne répond, seulement avec `ANTHROPIC_API_KEY` ; **éteint** par défaut (`false`) |

## État : le socle serveur est construit

Tout ce qui précède existe dans `apps/api/src/modules/coach/` : schéma et
migration, port du modèle, neuf outils de lecture, validateur, quota, dépôt,
contrôleur, deux clients de modèle (compatible OpenAI et Anthropic). Le droit `ai_coaching` est accordé par le plan
premium.

**Deux limites de l'environnement de développement, à connaître.**

*La migration a été écrite sans base.* Docker n'était pas disponible, donc
`prisma migrate dev` n'a pas pu tourner. Le SQL n'a pas pour autant été écrit à
la main : il a été obtenu par différence entre deux rendus complets
(`prisma migrate diff --from-empty` avant et après le changement de schéma),
puis vérifié par `prisma validate` et `prisma generate`. La CI rejoue le
contrôle de dérive contre un vrai PostgreSQL — c'est elle qui fait foi.

*Les tests e2e n'ont pas pu être exécutés ici*, pour la même raison : ils
demandent PostgreSQL et Redis. Ils sont écrits (`test/coach.e2e-spec.ts`,
sept scénarios : droit absent, réponse nominale, proposition validée, exercice
inventé, propriété du fil, plafond atteint, coach coupé) et la CI les exécute.
Les tests **unitaires**, eux, tournent : validateur, quota, préfixe de cache.

## Mobile

```
apps/mobile/lib/features/coaching/
  data/{dto,repositories}
  domain/{entities,repositories,services}
  presentation/{controllers,screens,widgets}
```

**Le coach vit dans le hub Training** *(réorganisation d'août 2026 — il a
d'abord été un sixième onglet, au centre de la barre)*. La barre basse est
repassée à cinq entrées (Accueil, Training, Progrès, Academy, Communauté) —
la Nutrition en ajoute une sixième en septembre 2026, ce qui ne change rien
pour le coach — et
le coach s'ouvre en un geste depuis la carte « Coach IA » du hub Training :
sa route `/coach` est une **route sœur de la branche Training**, la barre
reste donc visible et le retour ramène au hub.

L'ordre des branches du routeur EST celui de `appBottomBarItems` : la barre
rend un rang, la coquille ouvre la branche du même rang. Insérer un onglet au
milieu décale tout ce qui suit, et un décalage d'un cran ne se voit pas à la
lecture. `test/app/coach_tab_test.dart` tape chaque onglet et vérifie qu'il
ouvre bien le sien.

Deux écrans, deux rôles :

- `CoachPage` (`ConsumerStatefulWidget`) branche l'écran sur ses données et
  décide de tout : chargement, refus du serveur, envoi, lancement de la séance
  proposée ;
- `CoachScreen` reste **présentationnel** — il reçoit des messages et rend des
  bulles. C'est lui que capture `tool/screenshots/coach_test.dart` (quatre
  états) et que couvre `coach_screen_test.dart` ; le jeu d'exemple vit dans le
  harnais, jamais dans `lib/`.

Widgets : `CoachHeader`, `CoachMessageBubble`, `CoachSuggestions`,
`CoachProposalCard`, `CoachComposer`, `CoachDataNotice` et `CoachNotice`
(`widgets/coach_notices.dart`) — chacun sous 250 lignes, l'écran compris : les
deux lignes discrètes du coach ont quitté `coach_screen.dart` le jour où
l'ajout de la mention de traitement l'a poussé au-delà de la limite.

**Le coach dit bonjour, une fois par jour au plus** (1er octobre 2026). Un court
« Réfléchit… », puis une bulle au prénom (« Bonjour » de 5 h à 18 h,
« Bonsoir » ensuite), à la voix du Mentor choisie : à la première visite il
se présente et dit ce qu'il sait faire, au retour il reprend
(« On reprend où on s'était arrêtés ? »). Le texte est **écrit par
l'appli** (`domain/services/coach_greeting.dart`, fonction pure), jamais par
le modèle : sur le processeur du serveur, un bonjour généré coûterait de 20
à 90 s à chaque ouverture et prendrait la place de vraies questions dans la
file. Il n'est ni archivé ni envoyé au modèle. Il se pose à son rang dans le
fil (après les messages présents à l'ouverture) et y reste pendant la
visite ; un fil vide garde l'encart « Ton coach est là » au centre, avec le
bonjour dessous. Le jour du dernier bonjour est gardé sur l'appareil
(`CoachGreetingStore`, effacé au changement de compte) : rouvrir l'écran le
même jour ne le redit pas, et il ne se dit pas du tout quand on a déjà
écrit au coach aujourd'hui (`shouldGreet`). La question est tranchée une
fois par ouverture : un écran resté ouvert passé minuit ne dit pas bonjour
au milieu de la conversation. Pas de bonjour en lecture seule ni hors ligne : il
inviterait à une question que le coach ne recevrait pas. Moins
d'animations : le bonjour est là tout de suite. Captures `coach-02-vide` et
`coach-08-bonjour`.

**Les amorces lancent la conversation du jour, puis s'effacent**
(1er octobre 2026). Dès que la première question du jour part, et tant
qu'une question posée aujourd'hui (jour local) est dans le fil, la bande de
puces disparaît : elle revient le lendemain (`coachWroteToday`). La question
envoyée, elle, entre dans le fil dès l'appui, au-dessus de la réponse qui
s'écrit (depuis le 30 septembre 2026).

**L'en-tête et la barre de saisie tiennent les deux bords de l'écran.**
L'en-tête porte `AppBackButton`, la flèche commune du design system : elle
dépile la branche Training et s'efface seule s'il n'y a rien derrière. Les
états d'attente et d'erreur la portent aussi (`_CoachShell`), et ce n'est pas
un détail : un coach qui n'a pas pu s'ouvrir est précisément le moment où
l'on veut repartir.

La barre de saisie reste en bas, et passe au-dessus du clavier quand il
s'ouvre. Rien n'est calculé pour cela, et c'est ce qu'il ne faut pas défaire :
la coquille relève déjà le corps au-dessus du clavier et **retire** l'encart
du `MediaQuery` (`removeBottomInset`), pendant que le `SafeArea` de l'écran
porte la réserve de la barre d'onglets — sa hauteur clavier fermé, zéro
clavier ouvert puisque le clavier la recouvre. Ajouter cette réserve à la main
la comptait deux fois, et la barre de saisie flottait 84 px au-dessus du bas.
`coach_tab_test.dart` mesure les deux positions, dans la coquille et avec un
clavier simulé.

**Le fil n'est créé qu'au premier message.** Ouvrir l'onglet pour regarder ne
laisse derrière soi aucune conversation vide : l'identifiant est généré sur
l'appareil, gardé en local, et le fil naît côté serveur au moment où il a
quelque chose à contenir. Le même identifiant sert à rejouer l'envoi sans
créer de doublon — ni de second message de quota.

**Le droit vient du serveur, et de lui seul.** L'application ne calcule jamais
si l'utilisateur a `ai_coaching` : elle le LIT (`GET /entitlements`) et
appelle. Le serveur ne garde que deux gestes, ouvrir un fil et envoyer un
message (`403` sans le droit, `503` coach coupé) ; la LECTURE de ses propres
fils reste ouverte à leur auteur, abonné ou non, coach configuré ou non — les
CGU promettent que ce qui a été créé avec le Premium reste consultable. D'où
trois écrans :

- un historique existe mais le droit manque : le fil s'affiche **en lecture
  seule**, un panneau « Voir Premium » à la place du composeur ; un envoi
  refusé en `403` fait basculer dans ce mode ;
- ni historique ni droit : l'écran qui explique et mène à Premium ;
- droit inconnu (hors ligne) : l'écriture reste permise, l'envoi rapportera
  le vrai refus.

Un `429` devient une phrase au-dessus du composeur — et la question reste
dans le champ, prête à repartir demain. Un `503` à l'ouverture d'un premier
fil devient « le coach est en pause ». Aucun ne ressemble à une panne, parce
qu'aucun n'en est une.

**Accepter une proposition lance une vraie séance.** `CoachSessionLauncher`
écrit la séance ET son plan dans **une seule** transaction locale, en
réutilisant `WorkoutSessionWriter` et `SessionPlanLocalDataSource` — le chemin
exact de `startFromTemplate`. Aucun appel réseau : lancer fonctionne hors
ligne. La note au serveur (`/coach/proposals/:id/accepted`) part ensuite et son
échec est **volontairement avalé** : la séance existe, elle est en file de
synchronisation, c'est une statistique qui manque, pas un entraînement perdu.

La liste est **inversée** : la conversation s'ancre en bas, là où l'on écrit et
là où arrive la réponse. Une histoire courte flottant en haut d'un écran vide
est le défaut le plus visible d'un premier jet de messagerie.

**Les jours sont datés** (30 septembre 2026, à la demande du propriétaire :
revenir le lendemain et comparer). Un séparateur « Aujourd’hui », « Hier »
ou « 28/09/2026 » se pose au-dessus du premier message de chaque journée,
en heure locale, depuis le `createdAt` que l'API rend déjà pour chaque
message (`widgets/coach_thread_view.dart`). Un message sans date n'invente
pas de jour.

**Hors ligne — écart assumé.** Le composeur est **désactivé** avec un état
explicite : une question posée hors ligne recevrait sa réponse des heures plus
tard, ce qui n'est pas une conversation. C'est le seul écran de l'app qui
n'écrit pas hors ligne, et c'est délibéré. Le dépôt du coach est donc, seul de
toute l'application, **direct sur l'API** : ni Drift, ni file de
synchronisation — une copie de lecture mise à part (ci-dessous).

**L'historique se relit hors connexion** (30 septembre 2026). Le dépôt garde
le dernier fil relu, tel que l'API l'a rendu, puis chaque échange terminé
(`data/coach_thread_cache.dart`). Sans réseau à l'ouverture, le contrôleur
affiche cette copie, composeur hors ligne ; « Réessayer » relit alors le
serveur, qui fait foi. Rien de gardé : l'état hors ligne d'avant.

Une clé de préférences et non une table Drift : un seul fil, relu en bloc,
jamais interrogé — une table aurait coûté une migration de schéma pour rien.
Elle appartient au compte (`LocalAccountPurge.accountOwnedPreferenceKeys`) :
poids, repas et douleurs ne survivent pas à la déconnexion, et la
politique de confidentialité le dit. Une copie illisible, ou qu'on n'a pas
pu écrire, se journalise et ne fait jamais échouer la conversation en
ligne.

**Les quatre états** sont obligatoires : chargement (`AppLoadingIndicator`),
erreur (`AppErrorState`), vide (`AppEmptyState` avec les suggestions de
départ), hors ligne (état dédié sur le composeur).

**La conversation dit d'où vient la réponse.** `CoachDataNotice` pose une
ligne sobre en tête du fil, au-dessus du premier message : « Tes données
d'entraînement citées ici restent sur les serveurs de Carlys : c'est là que
le coach produit sa réponse. » (Elle parlait d'un prestataire externe tant
que le coach tournait chez Mistral ou Anthropic ; ADR 0011.) Elle n'est ni une alerte ni un consentement à recueillir
— l'usage du coach relève du contrat, et la politique de confidentialité le
détaille déjà. Elle est là parce qu'un fait pareil doit se lire au moment où
l'on écrit, pas seulement dans un document que personne n'ouvre. Techniquement
c'est un rang de plus dans la liste inversée, donc le DERNIER : la mention
remonte avec l'histoire au lieu de coller à l'écran, et ne s'affiche qu'une
fois quel que soit le nombre de messages.

**Les puces de suggestion** se calculent depuis l'état réel — modèle de séance
disponible, record récent, poids qui bouge — et jamais en dur. Sans données,
une seule puce générique. La règle vit dans `domain/services/coach_suggestions.dart`
et ne prend qu'un `CoachContext` de valeurs simples : elle se teste seule, et
`coaching` ne dépend pas de la forme interne de `progress` ou
`workout_template`. Deux garde-fous mesurés : un record de plus de trois
semaines n'invite plus à « continuer » mais à débloquer, et une variation de
poids sous 400 g est du bruit de balance — elle ne dit rien.

### Couleurs — tranché : le violet de Carlys

La maquette montre des bulles utilisateur en dégradé violet → magenta, qui
correspond à `AppColors.signature`. Or ce dégradé est aujourd'hui **réservé aux
surfaces de marque** : sur la page de bienvenue il ne peint que deux éléments,
et `AppBrandButton` documente que deux boutons « principaux » de couleurs
différentes dans un même écran annulent la hiérarchie.

**Recommandation** : bulles utilisateur en `AppColors.primary` (un violet franc,
très proche de la maquette), bulles du coach sur `AppColors.darkSurface`, et le
bouton « Voir la séance » en `AppButton` accent — la couleur d'action de toute
l'application. Le dégradé de signature reste à la marque.

**Tranché le 30 septembre 2026 par le propriétaire : les bulles suivent le
thème de Carlys.** C'est ce que peint `coach_message_bubble.dart`
(`AppColors.primary` pour tes messages, `darkSurface` pour ceux du coach) ;
le dégradé de signature reste réservé à la marque (CLAUDE.md, point 9).

## Tests

**API — unitaires.** Le validateur rejette un `exerciseId` inconnu, des
positions non contiguës, une charge absurde, une proposition vide. La garde de
quota compte avant l'appel, bloque au plafond et rend le message sur un 503
survenu avant toute consommation, trois fois par jour au plus, course et
passage de minuit compris. Chaque client porte les jetons déjà consommés
dans son 503, et garde UNE échéance pour tout le tour (tentatives, tours
d'outils, pauses : prouvé par mutation). L'assemblage du prompt ne
place aucune donnée volatile avant la césure de cache. Le port du modèle est un
faux ; aucun test ne sort du réseau.

**API — e2e.** `403` sans le droit `ai_coaching` pour ouvrir un fil ou
écrire, mais `200` pour relire ses fils sans lui, `429` au-delà du quota, `503`
coach désactivé à l'écriture (la lecture, elle, répond), `503` fournisseur tombé sans
message décompté (puis le renvoi qui termine le tour), `200` avec proposition valide, et le cas où le modèle propose
un exercice inconnu — la réponse doit rester utilisable.

**Mobile.** Rendu des bulles, carte de proposition, lancement de séance depuis
« Voir la séance », état hors ligne du composeur, état vide avec suggestions.

## Découpage proposé

1. **Socle serveur** — schéma + migration, module, port du modèle, outils de
   lecture, validateur, quota, droit `ai_coaching`, tests unitaires et e2e.
   Livrable vérifiable sans une seule ligne de Flutter.
2. ~~**Écran mobile**~~ — **fait** : dépôt, contrôleur, onglet, quatre états,
   tests widget (le mode démo, construit à cette étape, a été retiré depuis). Les puces de suggestion sont calculées depuis
   l'état réel dès cette étape (elles n'ont pas d'endpoint : la règle vit sur
   l'appareil, dans `CoachContext`).
3. **Finitions** — suggestions calculées depuis l'état réel, acceptation de
   proposition branchée sur la création de séance, documentation Swagger et
   `docs/`.

Le streaming est venu ensuite (ADR 0012).

## Décisions ouvertes

1. ~~**Streaming en v1 ou en v2 ?**~~ — tranché en septembre 2026 : fait,
   voir l'ADR 0012.
2. ~~**Bulles en `primary` ou dégradé de signature ?**~~ — tranché le
   30 septembre 2026 : le violet de Carlys (`primary`), voir « Couleurs ».
3. ~~**Quota quotidien**~~ — tranché le 30 septembre 2026 : **30 messages par
   jour** et par personne, pour l'abonnement qui ouvre le coach (droit
   `ai_coaching`, plan premium). C'est la valeur par défaut de
   `COACH_DAILY_MESSAGE_LIMIT` et celle des trois `.env.example`.
4. ~~**Point d'entrée**~~ — tranché une première fois comme sixième onglet au
   centre de la barre, puis **re-tranché en août 2026** avec la réorganisation
   en onglets : le coach s'ouvre depuis la carte « Coach IA » du hub
   Training (route sœur de la branche, barre visible). La carte sur l'accueil
   et le lien depuis le débrief de séance restent possibles en complément.
