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
| `get_nutrition_targets` | Cibles du module métabolisme (des objectifs, jamais le consommé) |
| `get_recent_meals` | Le journal alimentaire : repas notés sur les N derniers jours (1 par défaut, 7 au plus), en instants UTC |
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

Ordre de rendu : outils → système partagé (césure) → bloc par utilisateur →
messages. Le point de césure de cache se pose **sur le bloc système
partagé**, donc après le prompt et les définitions d'outils — identiques pour
tous les utilisateurs — et avant tout ce qui varie.

Interdits absolus dans le préfixe : date du jour, identifiant de requête, nom
de l'utilisateur, toute donnée qui change d'un appel à l'autre — ou d'un
utilisateur à l'autre. Ils vivent après la césure. Un `new Date()` dans le
prompt système annulerait la totalité du bénéfice — c'est le piège classique,
et il est silencieux : rien n'échoue, la facture double.

**Profil Carlys** : quand l'utilisateur a choisi son identité
(Constructeur/Challenger/Athlète/Stratège), un briefing d'angle
(`carlysProfileBriefing`, fonction pure de l'énumération — jamais de texte
libre) part en second bloc système, **après** la césure via
`CoachTurnInput.systemPerUser`. Il oriente le ton, jamais les chiffres — les
chiffres viennent des outils. Un nom de profil dans le préfixe partagé le
fragmenterait en quatre variantes de cache : un test l'interdit explicitement.

Vérification : `usage.cache_read_input_tokens` doit être non nul dès le
deuxième tour. Un test d'assemblage vérifie qu'aucune donnée volatile
n'apparaît avant la césure, et l'e2e vérifie que le préfixe reste identique
octet pour octet, briefing ou pas.

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

## État : le socle serveur est construit

Tout ce qui précède existe dans `apps/api/src/modules/coach/` : schéma et
migration, port du modèle, neuf outils de lecture, validateur, quota, dépôt,
contrôleur, client Anthropic. Le droit `ai_coaching` est accordé par le plan
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
repassée à cinq entrées (Accueil, Training, Progrès, Academy, Communauté) et
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
`CoachProposalCard`, `CoachComposer` — chacun sous 250 lignes.

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
si l'utilisateur a `ai_coaching` : elle appelle, et un `403` devient un écran
qui explique et mène à Premium. Un `429` devient une phrase au-dessus du
composeur — et la question reste dans le champ, prête à repartir demain. Un
`503` devient « le coach est en pause ». Aucun des trois ne ressemble à une
panne, parce qu'aucun n'en est une.

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

**Hors ligne — écart assumé.** Le composeur est **désactivé** avec un état
explicite : une question posée hors ligne recevrait sa réponse des heures plus
tard, ce qui n'est pas une conversation. C'est le seul écran de l'app qui
n'écrit pas hors ligne, et c'est délibéré. Le dépôt du coach est donc, seul de
toute l'application, **direct sur l'API** : ni Drift, ni file de
synchronisation.

**Ce qui n'est PAS fait :** l'historique ne se lit pas encore hors connexion.
Ouvrir l'onglet sans réseau montre l'état hors ligne, pas la conversation
passée. Il faudra pour cela une table Drift de messages en cache — c'est du
travail de finition (étape 3 du découpage), pas une correction.

**Les quatre états** sont obligatoires : chargement (`AppLoadingIndicator`),
erreur (`AppErrorState`), vide (`AppEmptyState` avec les suggestions de
départ), hors ligne (état dédié sur le composeur).

**Les puces de suggestion** se calculent depuis l'état réel — modèle de séance
disponible, record récent, poids qui bouge — et jamais en dur. Sans données,
une seule puce générique. La règle vit dans `domain/services/coach_suggestions.dart`
et ne prend qu'un `CoachContext` de valeurs simples : elle se teste seule, et
`coaching` ne dépend pas de la forme interne de `progress` ou
`workout_template`. Deux garde-fous mesurés : un record de plus de trois
semaines n'invite plus à « continuer » mais à débloquer, et une variation de
poids sous 400 g est du bruit de balance — elle ne dit rien.

**Mode démo.** `lib/demo/demo_coach.dart` sert une conversation d'exemple —
sans lui, l'onglet Coach de l'APK de démonstration serait un écran mort. Il
**dit ce qu'il est** : la réponse annonce qu'elle vient d'un mode démonstration
plutôt que de se faire passer pour un raisonnement. La séance proposée s'appuie
sur de vrais exercices du catalogue de démonstration, donc elle se lance
vraiment ; son plan, en revanche, n'est pas matérialisé (le dépôt de
démonstration ne stocke pas de plan) et la séance s'ouvre comme une séance
libre. Limite écrite dans le code.

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
2. ~~**Écran mobile**~~ — **fait** : dépôt, contrôleur, onglet, quatre états,
   mode démo, tests widget. Les puces de suggestion sont calculées depuis
   l'état réel dès cette étape (elles n'ont pas d'endpoint : la règle vit sur
   l'appareil, dans `CoachContext`).
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
4. ~~**Point d'entrée**~~ — tranché une première fois comme sixième onglet au
   centre de la barre, puis **re-tranché en août 2026** avec la réorganisation
   en cinq onglets : le coach s'ouvre depuis la carte « Coach IA » du hub
   Training (route sœur de la branche, barre visible). La carte sur l'accueil
   et le lien depuis le débrief de séance restent possibles en complément.
