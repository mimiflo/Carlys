# Communauté — amis, encouragements, défis collectifs

La communauté fait des AUTRES un moteur : on voit la série de ses amis, on
s'encourage, on additionne ses efforts dans des défis collectifs. Elle est
**gratuite** (aucun entitlement) et **facultative** : rien dans le reste de
l'application ne dépend d'elle.

## Principes non négociables

1. **La confidentialité est décidée côté serveur.** Quand quelqu'un ne
   partage pas sa progression, sa série et ses séances arrivent `null` chez
   ses amis — la donnée ne quitte JAMAIS le serveur. Le client affiche
   « Profil privé » ; il ne « masque » rien, il n'a rien.
2. **L'ajout par e-mail est non énumérable.** `POST /community/requests`
   répond `202` que l'adresse ait un compte ou non, et les demandes
   **envoyées** ne sont jamais listées. Personne ne peut se servir de l'ajout
   d'amis pour découvrir qu'une adresse est inscrite. L'interface joue le même
   jeu : « Si ce compte existe, il recevra ta demande. »
3. **Le code ami est une identité qui se partage, pas qui se devine.**
   Chaque compte reçoit à vie un code de 8 caractères (alphabet sans
   ambiguïté visuelle — ni 0/O ni 1/I/L —, affiché `XXXX-XXXX`, porté par le
   QR du profil : charge utile `carlys:friend:<code>`). À la Snapchat : on
   l'affiche, on le fait scanner, on le dicte. Contrairement à l'e-mail, un
   code SE CONFIRME par le prénom de son porteur (« Demande envoyée à
   Sarah ») : donner son code, c'est déjà dire « ajoute-moi » — et 26⁸
   combinaisons derrière le throttler rendent l'essai en rafale vain. La
   demande reste une demande : jamais de lien automatique, même scanné.
   Règles canoniques : `modules/users/domain/friend-code.ts` côté serveur,
   miroir Dart `features/community/domain/friend_code.dart` côté mobile.
4. **On n'écrit que chez ses amis.** Un encouragement vers quiconque n'est pas
   un ami ACCEPTÉ est refusé (`403`). Le fil de chacun est privé.
5. **Un défi COLLECTIF ne classe personne.** La barre d'un défi ouvert à
   toute la communauté montre `somme des contributions / objectif`, bornée à
   1 : l'effort du groupe, et rien d'autre — la part d'une personne nommée ne
   sort JAMAIS du serveur. Cette règle porte sur les défis collectifs, et sur
   eux seuls (réécriture du 19 septembre 2026 : elle interdisait tout
   classement individuel, ce qui rendait impossibles les défis entre amis et
   les ligues décidés par le propriétaire du produit). Un défi ENTRE AMIS et
   une LIGUE ordonnent des personnes par construction ; ils sont permis, sous
   trois conditions qui les tiennent à distance du titre Carlys :
   - **périmètre CHOISI** — on n'est classé qu'avec des gens qu'on a acceptés
     (invitation à un défi) ou après avoir rejoint une ligue ; jamais un
     classement mondial subi, jamais un ami qui découvre son rang sans avoir
     rien demandé ;
   - **fenêtre qui SE FERME** — un classement expire avec sa période et
     repart ; il ne devient jamais un palier que la personne « est » ;
   - **aucun report dans le profil** — ni point, ni axe, ni titre, ni
     récompense (voir [progression.md](progression.md), « Un seul score : la
     règle de non-concurrence »).
6. **Chacun peut se protéger, sans que l'autre le sache.** Bloquer quelqu'un
   est unilatéral et OPAQUE : l'amitié et les demandes en attente sont
   retirées dans les deux sens, puis, pour chacun des deux, l'autre répond
   comme un compte qui n'existe pas (demande muette en `202`, code ami en
   `404`, encouragement en `403`, absent des listes et du fil — classement
   de ligue compris, sans décaler les rangs des autres). Un défi entre amis
   dont le créateur est séparé de moi par un blocage disparaît tant que je
   ne suis pas à son classement (invitation en attente ou refusée, défi
   quitté) : absent de ma liste, et `404` « Défi introuvable. » au détail, à
   l'acceptation et au refus, comme un défi qui n'existe pas — le
   réaccepter après un refus ou un départ compris. Un défi où je suis au
   classement (accepté, pas quitté) reste lisible des deux, avec son titre
   et son classement (un résultat partagé ne se réécrit pas), mais le mot de
   son créateur n'est plus servi à l'autre : un texte libre suit la règle
   du fil. Jamais de « tu es bloqué ». Un encouragement se retire par son auteur OU son
   destinataire. Un signalement (personne, encouragement précis, ou défi
   entre amis qu'elle a lancé) part vers l'administration, qui le lit et le
   résout avec une permission dédiée ; la personne signalée n'en sait rien,
   et retirer son message n'efface pas la preuve : le texte est figé au
   moment du signalement.

## Modèle de données (Prisma)

| Table | Rôle |
| --- | --- |
| `Friendship` | UNE ligne par paire ; `PENDING` → `ACCEPTED`/`DECLINED`, direction conservée (qui a demandé). L'unicité porte sur la PAIRE ordonnée (`userLowId`, `userHighId`) : c'est la base qui l'impose, y compris quand les deux personnes se demandent en même temps. |
| `Encouragement` | Mot d'un ami ; le nom de l'expéditeur est lu au moment de servir (nom COURANT, pas dénormalisé). |
| `CommunityChallenge` | Défi collectif du MOIS (`month`, `YYYY-MM` UTC), `SPORT` ou `CULTURE`, avec sa `metric` (ce qu'il compte), son `target` et sa fenêtre `startsAt`/`endsAt` ; unique par `(slug, month)`, matérialisé paresseusement depuis le catalogue en code, jamais créé par un utilisateur. |
| `FriendChallenge` | Défi lancé par quelqu'un à ses amis : `message?` (le mot du créateur, 280 points de code, `NULL` s'il n'a rien écrit ; son heure est `createdAt`), `metric`, `target` facultatif, `durationDays` (3/7/30), `endsAt` CALCULÉ par le serveur, `closedAt` qui sert de clé d'idempotence au règlement. |
| `FriendChallengeMember` | Membre d'un défi entre amis : `status` (INVITED/ACCEPTED/DECLINED/LEFT), `contribution` dans l'unité de la métrique, `finalRank` figé à la clôture. |
| `ChallengeParticipation` | Participation + `contribution` individuelle à l'objectif. Quitter DATE le départ (`leftAt`) sans effacer la ligne : la contribution déjà versée reste acquise au collectif, seule la présence s'arrête. |
| `CommunityPreference` | `sharesProgress` (absence = partagé, défaut du modèle) et `joinsLeague` (défaut `false` : la ligue est un opt-in). |
| `LeagueMembership` | Ma place dans une ligue pour UNE période : `(userId, periodKey)` où `periodKey` est la semaine ISO en UTC, plus `division`, `cohort` (mon GROUPE de 20 dans la division, attribué à l'ouverture ; `0` pour les lignes d'avant les groupes), `score` en POINTS, `finalRank` et `nextDivision` figés au règlement, `settledAt` qui en est la clé d'idempotence. |
| `CommunityBlock` | Blocage unilatéral `(blockerId, blockedId)`, unique par paire orientée ; consulté dans les DEUX sens partout où deux personnes se rencontrent. |
| `CommunityReport` | Signalement : `reporterId`, `reportedUserId`, `encouragementId?` (mis à `NULL` si le message est supprimé), `encouragementMessage?` (cliché du texte visé, pris dans la même transaction que le signalement : la preuve survit au retrait du message), `friendChallengeId?` (défi entre amis visé, exclusif avec `encouragementId`, mis à `NULL` si le défi disparaît), `friendChallengeTitle?` et `friendChallengeMessage?` (clichés du titre et du mot du créateur, pris dans la même transaction), `reason` (`HARCELEMENT`, `SPAM`, `CONTENU_INAPPROPRIE`, `AUTRE`), `details?` (500 caractères, comptés en points de code), `status` (`OPEN`, `RESOLVED`), `resolvedAt?`. |

## API (`/api/v1/community`)

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| GET | `/feed` | Encouragements reçus (50 max, plus récents d'abord) |
| POST | `/encouragements` | Encourager un ami accepté (`403` sinon) ; `message` de 280 caractères au plus, comptés en points de code (`encourageRequestSchema`) |
| GET | `/friends` | Amis acceptés, stats `null` si progression privée |
| DELETE | `/friends/:userId` | Retirer un ami (idempotent) |
| GET | `/requests` | Demandes REÇUES en attente |
| POST | `/requests` | Demander par e-mail exact OU `friendCode` (exactement un des deux) — `202` opaque, refus opposable 30 jours, 10 demandes/min par adresse |
| GET | `/friend-codes/:code` | Nom du porteur d'un code (toutes formes humaines acceptées) — `404` sinon |
| POST | `/requests/:id/accept` · `/decline` | Répondre (destinataire uniquement) |
| GET | `/challenges` | Défis ouverts, progression collective incluse ; crée le jeu du mois à la première lecture (voir ci-dessous) |
| POST | `/challenges/:id/join` | Rejoindre (idempotent) |
| DELETE | `/challenges/:id/join` | Quitter (idempotent) : la contribution déjà versée reste au compteur collectif |
| GET | `/friend-challenges` | Mes défis ENTRE AMIS (proposés et acceptés) ; un défi échu est réglé à la lecture ; une invitation dont le créateur est séparé de moi par un blocage n'y figure pas |
| POST | `/friend-challenges` | Défier ses amis (id appareil, création idempotente) — `403` si l'un des invités n'est pas un ami accepté ou qu'un blocage les sépare ; `title` de 80 caractères et `message` facultatif de 280, tous deux comptés en points de code après découpage (`400` au-delà, `message` blanc = absent), jamais réécrits par un rejeu |
| GET | `/friend-challenges/:id` | Un défi et son classement — `404` pour qui n'en est pas membre, et pour une INVITATION dont le créateur est séparé de moi par un blocage (même message « Défi introuvable. »). Même forme que la liste, la création et l'acceptation : `message` (ou `null`), `createdAt` (ISO UTC, l'heure du message), `durationDays`, et `isCreator` sur chaque membre ; sur un défi déjà accepté, `message` vaut aussi `null` quand un blocage, dans un sens ou l'autre, me sépare du créateur |
| POST | `/friend-challenges/:id/accept` | Accepter : on entre au classement, à zéro — `404` « Défi introuvable. » pour une invitation masquée par un blocage |
| DELETE | `/friend-challenges/:id/join` | Refuser ou quitter (`204`) : dans les deux cas, on SORT du classement (`404` pour une invitation masquée par un blocage) |
| GET | `/league` | Ma ligue de la semaine : le classement de MON GROUPE de 20, sans les personnes bloquées ; sans adhésion, classement VIDE |
| POST | `/league/join` | Entrer dans la ligue (le geste EST le consentement) |
| DELETE | `/league/join` | Sortir : le compte s'arrête, la semaine en cours se règle |
| GET · PATCH | `/profile` | Ma préférence `sharesProgress` + mon `friendCode` |
| POST | `/blocks/:userId` | Bloquer (idempotent, `204`) : retire amitié et demandes dans les deux sens ; `400` soi-même, `404` compte inconnu |
| DELETE | `/blocks/:userId` | Débloquer (idempotent, `204`) : ne rétablit rien |
| GET | `/blocks` | Personnes que j'ai bloquées (`userId`, `displayName`, `blockedAt`) |
| DELETE | `/encouragements/:id` | Retirer un encouragement (auteur OU destinataire) : `204` rejouable et opaque, un identifiant étranger n'a aucun effet |
| POST | `/reports` | Signaler une personne, un encouragement qu'elle m'a envoyé (`encouragementId`), ou un défi entre amis qu'elle a lancé (`friendChallengeId`) — `201` ; les deux cibles à la fois : `400` ; un signalement OUVERT identique n'est pas dupliqué (même accusé de réception) ; `404` si l'encouragement ne vient pas d'elle ou ne m'était pas adressé, et `404` « Défi introuvable. » si le défi n'existe pas, si je n'en suis pas membre (tout statut) ou s'il n'est pas d'elle |

Côté back-office (`/api/v1/admin/community`, jeton admin, permission
`community:moderate`, actions auditées) :

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| GET | `/reports?status=&limit=&cursor=` | Signalements, plus récents d'abord, avec les deux personnes (id, e-mail, nom) et le contenu visé, figé au moment du signalement : le texte de l'encouragement (lisible même si l'auteur l'a retiré depuis), ou le titre et le mot du défi (`friendChallengeTitle`, `friendChallengeMessage`) |
| PATCH | `/reports/:id` | `{ status: "RESOLVED" }` résout (`resolvedAt` posé, audit `admin.community_report_resolved`) ; `{ status: "OPEN" }` rouvre (`admin.community_report_reopened`) ; rejouer le même statut ne réécrit rien |

Ces deux routes ont leur écran : la page **Signalements** du back-office
(`apps/admin`, `/reports`, entrée de navigation à côté d'Utilisateurs).
Elle liste les signalements ouverts par défaut (résolus, ou tous, sur
demande ; pages de 50 par curseur, « Charger la suite ») avec la date, le
motif et ses précisions, l'auteur, la personne visée et le contenu visé
(colonne « Contenu visé »). Pour un encouragement, ce texte est le cliché
figé au signalement, donc trois états seulement : le message seul (il est
encore dans le fil) ; le message suivi de « Message retiré depuis »
(`encouragementId` remis à `NULL` par la suppression, la preuve reste) ;
« La personne en général » quand le signalement ne vise aucun message. Pour
un défi entre amis : « Défi « titre » », puis le mot du créateur cité, ou
« (sans message) » s'il n'en avait pas écrit. Un bouton résout chaque signalement, un
autre le rouvre ; résoudre ne prévient personne et ne touche pas au compte
visé : les deux personnes renvoient à leur fiche utilisateur, seul endroit
où l'on suspend. Sans
`community:moderate`, la page montre le refus du serveur tel quel (403),
sans le déguiser en panne. Transport : `adminApi.listCommunityReports` et
`adminApi.setCommunityReportStatus`, portés par
`apps/admin/src/lib/admin-community-api.ts` et étalés dans `adminApi`
(`admin-api.ts`), réponses validées par `adminCommunityReportSchema`.

Cas particuliers du service :

- **Demandes croisées** : si B demande A alors que A → B est en attente, la
  demande existante est ACCEPTÉE (les deux se veulent amis).
- **Refus opposable** : après un refus, le MÊME demandeur reste muet pendant
  30 jours : sa demande répond `202` comme toujours, mais rien ne réapparaît
  chez l'autre et aucune notification ne part. La personne qui a refusé
  peut, elle, prendre contact à tout moment : la ligne `DECLINED` repart
  `PENDING` dans SON sens, comme une demande neuve. Sans cette règle, une
  adresse ou un code ami connus suffisaient à harceler à coups de demandes,
  avec une notification à chaque coup.
- **Limite dédiée** : `POST /community/requests` porte son propre seau,
  calqué sur celui des routes d'authentification (10 demandes par minute et
  par adresse, `429` au-delà), indépendant du plafond global.
- **Blocages** : consultés par `requestFriendTo` (e-mail et code), l'aperçu
  de code, `encourage`, `listFriends` et le fil, toujours dans les deux sens
  et toujours avec la réponse d'un compte inexistant. Aussi par l'invitation
  à un défi entre amis (`403` commun avec « pas ami ») et par sa LECTURE
  (liste, détail, acceptation, refus) : une invitation encore en attente
  disparaît (`404` d'un défi inconnu), un défi déjà accepté reste mais le mot
  du créateur n'est plus servi. Et par le classement de la ligue, qui tait
  les personnes bloquées sans renuméroter les autres. Bloquer supprime
  l'amitié ou la demande en attente de la paire (`ACCEPTED`, `PENDING`) ;
  débloquer ne la recrée pas. Une ligne `DECLINED`, elle, reste en place : le
  blocage la rend inopérante, et son délai de 30 jours survit au déblocage.
  Bloquer puis débloquer n'est donc pas un moyen de contourner un refus, ni
  pour la personne refusée (rien ne réapparaît, personne n'est notifié), ni
  au détriment de celle qui a refusé (elle garde la main pour reprendre
  contact).
- **Statistiques partagées** : `weeklySessions` = séances TERMINÉES sur 7
  jours glissants ; `streakDays` = jours calendaires consécutifs avec séance,
  découpés dans le FUSEAU du propriétaire (`UserProfile.timezone`), série
  d'hier non brisée tant que la journée en cours n'est pas finie
  (`streak.calculator.ts`, testé fuseau par fuseau).

## Les défis du mois

Les défis étaient créés par le seed avec une date de fin fixe : un mois
après, la liste restait vide pour toujours, sans écran d'administration ni
tâche de fond pour la regarnir. Désormais le jeu du mois se crée **tout
seul, à la lecture** :

- Le catalogue vit dans le code (`modules/community/domain/challenge-catalog.ts`),
  pas dans le seed : il est versionné, testé, et identique partout.
- `GET /community/challenges` compte les défis du catalogue déjà présents
  pour le mois courant (par slug : un défi posé à la main dans le même mois
  ne compte pas) ; s'il en manque, il écrit le catalogue daté de ce mois
  (`startsAt` = le 1er à minuit **UTC**, `endsAt` = le 1er du mois
  suivant), puis liste. Un catalogue enrichi en cours de mois se complète
  donc tout seul. Les dates du dépôt sont en UTC ; le calendrier collectif
  l'est aussi, pour que tout le monde voie le même défi finir au même
  instant.
- L'unicité `(slug, month)` et `createMany({ skipDuplicates })` absorbent
  les lectures concurrentes : deux premières lectures simultanées écrivent
  chacune ce qui manque, jamais deux fois la même ligne. **Pas de cron**, rien
  à surveiller : un mois déjà servi ne coûte qu'un comptage.
- Les objectifs sont exprimés dans l'unité réellement comptée, et cette unité
  est une **donnée** (`CommunityChallenge.metric`), plus une phrase du
  catalogue. Quatre valeurs, toutes avec une source réelle : `WORKOUTS`
  (séances terminées), `QUIZ_CORRECT` (une bonne réponse par leçon et par
  jour), `ACTIVE_SECONDS` (secondes chronométrées série par série),
  `DISTANCE_METERS` (mètres déclarés série par série). `kind` ne dit plus que
  la FAMILLE, pour le badge de la carte.

  Les pas et l'eau n'y figurent pas, et c'est délibéré : les pas ne sont pas
  lus, l'eau ne quitte jamais l'appareil. Une valeur d'enum que rien
  n'alimente est une promesse qu'aucun écran ne peut tenir.

  Toutes ces métriques sont des **événements**, jamais des totaux redéclarés :
  elles s'additionnent par incrément, ce qui suppose que le même fait ne se
  produise qu'une fois (la clôture est gardée par sa transition d'état, la
  réponse de quiz par son unicité). Le jour où une métrique redéclare un
  total — les pas d'hier resynchronisés — l'incrément devient faux, et il
  faudra un registre de totaux quotidiens avec un delta `max(0, nouveau −
  ancien)`.

## Contribution des séances aux défis

À la clôture d'une séance (`workouts.service`), `recordWorkoutCompleted`
verse à **trois** métriques à la fois : une séance, ses secondes d'effort et
ses mètres parcourus. C'est tout l'objet de la généralisation — le même fait
alimente les défis qui comptent des séances ET ceux qui comptent des
kilomètres, sans que personne n'ait à choisir.

Les secondes versées sont celles des SÉRIES, pas la durée de la séance :
`durationSeconds` mesure du début à la fin, pauses et rangement compris, et
un défi qui compte des secondes d'effort ne doit pas créditer le temps passé
à discuter. Une quantité nulle n'écrit rien du tout — une séance de fonte ne
parcourt aucun mètre, c'est le cas ordinaire.

Comme le recalcul des records : l'échec est journalisé et ne fait JAMAIS
échouer la clôture.

Les défis **CULTURE** sont alimentés par les quiz de l'Academy :
`POST /community/quiz-answers` enregistre chaque réponse — idempotente par
(utilisateur, leçon, jour LOCAL de l'appareil, table `QuizAnswer`) — et seule
une PREMIÈRE réponse juste contribue aux défis culturels rejoints. Rejouer
l'envoi ne compte jamais deux fois ; une réponse fausse est enregistrée mais
ne contribue pas. Côté mobile, l'envoi ne gêne JAMAIS le quiz : l'Academy
fonctionne hors ligne, un échec réseau est journalisé et la contribution est
simplement perdue (la barre est collective, pas comptable).

## Mobile

- `CommunityRepositoryImpl` (Dio) transporte ce que le serveur a accepté de
  dire ; la doublure en mémoire des tests
  (`test/support/in_memory_community_repository.dart`, dont le monde
  d'exemple — amis, mots, demandes, défis, codes — vit dans
  `test/support/community_sample_world.dart`) fait vivre l'écran sans
  réseau.
- **Trois onglets** (refonte du 23 septembre 2026, d'après maquette). La page
  empilait tout sur un seul défilement ; elle se range désormais en Défis
  (ouvert le premier), Ligue et Amis, sur une piste segmentée du design system
  (`AppSegmentedTabs`, qui porte le compte des demandes en attente en pastille
  et le dit en mots au lecteur d'écran). Rien n'a été retiré en chemin :
  Défis = défis du mois et défis entre amis ; Ligue = la carte « où j'en
  suis », le classement de la semaine et la bannière ; Amis = demandes,
  encouragements, amis, confidentialité, personnes bloquées. L'en-tête
  (`AppScreenHeader`, partagé avec le profil) porte la loupe et l'ajout d'un
  ami. L'onglet ouvert survit à un détour par un autre onglet de la barre du
  bas, et l'ADRESSE le suit (`/community?onglet=amis`,
  `AppRoutes.communityTab(CommunityTab.amis)`, typé par l'énumération) : les
  raccourcis de l'accueil (encouragement → Amis, défi du profil Challenger →
  Défis) et du profil (« Mes amis » → Amis) ouvrent l'onglet qu'ils
  annoncent, y compris quand on l'avait quitté à la main.
- **La loupe FILTRE l'onglet ouvert, et rien d'autre** : amis, demandes, mots
  et blocages par prénom ; noms du classement de la ligue (podium ou pas) ;
  défis par titre. Elle n'interroge jamais le serveur, qui n'énumère personne
  (principes 2 et 3) : on n'y cherche pas des inconnus. Rien ne correspond ?
  L'onglet le dit ; un réglage (Confidentialité) sort des résultats.
- Chaque onglet distingue HORS CONNEXION (statut dédié, comme le coach —
  `ConnectionAwareError`), panne serveur (« Réessayer » réessaie vraiment),
  premier chargement et données, sur SES sources seulement
  (`CommunityTabGate`) : une ligue en panne ne masque plus les défis, qui ont
  répondu. Pendant un rafraîchissement, la liste reste en place (Riverpod
  conserve la valeur précédente).
- **Les défis du mois changent l'état vide.** Depuis que le serveur crée le
  jeu du mois à la lecture, un compte neuf en ligne voit toujours des défis.
  L'onglet Amis, lui, affiche « Personne ici pour l'instant » (avec l'action
  « Ajouter un ami ») quand il n'a ni demande, ni mot, ni ami, ni blocage ;
  dès qu'une de ces listes existe, l'invitation au premier ajout vit dans la
  section « Amis » (`FriendsEmptyCard`), tant qu'il n'y a ni ami ni demande en
  attente. Hors ligne au premier lancement, c'est « Hors connexion » qui
  s'affiche, jamais « personne ici » : rien n'a pu être lu.
- **L'onglet Ligue** (`widgets/league/`) : « LIGUE », la division et celle
  qui vient (« Bronze → Argent ») avec le blason peint aux couleurs des
  métaux (`AppColors.league*`, réservés aux ligues), puis la phrase qui dit
  où j'en suis — d'après le bloc `promotion` du serveur, dans cet ordre :
  rien de calculé (score seul), Diamant (tenir sa place), moins de dix
  joueurs actifs (la semaine ne comptera pas, jauge en JOUEURS), dans le top
  5 (« la zone de montée », jamais « tu montes » : un ex æquo peut garder
  quelqu'un en place), sinon l'écart (« Encore 35 points pour entrer dans le
  top 5 », jauge « 240 / 275 pts » et sa base en toutes lettres : « 275 pts :
  le score du 5e aujourd'hui »). La maquette écrivait « 260 points pour
  passer Argent » sur « 240 / 500 » : ce seuil n'existe pas. Vient ensuite le
  barème en trois tuiles et une ligne (la quatrième règle, l'Academy), le
  classement de la semaine (podium couronné, MA ligne même hors du podium,
  « Voir le classement complet » dans une feuille, sans nouvelle requête),
  puis une bannière illustrée. Le classement est celui de MON GROUPE (vingt
  joueurs au plus) ; ses rangs sont ceux du serveur, jamais renumérotés : une
  personne bloquée n'a pas de ligne mais garde sa place, et « 1, 3, 4 » dit
  vrai là où « 1, 2, 3 » mentirait sur la mienne. Le résultat de la semaine
  passée (« À la 3e place la semaine passée : … ») reste affiché toute la
  semaine, pour chaque membre, quel que soit celui dont la lecture l'a
  réglée. Sans adhésion, l'onglet montre l'invitation —
  la division où l'on entrerait et le barème, jamais un nom — et la même
  bannière au futur. Les avatars sont des INITIALES (`AppInitialAvatar`) :
  Carlys n'a pas de photo de profil, et en afficher serait inventer une
  donnée. Chaque carte, chaque ligne du classement, le blason et le titre
  sont leur propre nœud sémantique : fondue, la carte s'annonçait comme UN
  bouton dont le geste couvrait tout l'onglet.
- **L'écran d'un défi entre amis** (`screens/friend_challenge_screen.dart`,
  route `/community/defis/:id`, maquette du 23 septembre 2026). Chaque carte
  de l'onglet Défis y mène ; il relit le défi par son identifiant (`GET
  /community/friend-challenges/:id`, réservé aux membres). On y lit
  l'en-tête (titre, « Léa te défie », participants, fin, compte à rebours),
  une rangée de faits (objectif, durée, ce qui compte, « Amis uniquement »),
  les participants avec leur statut (à l'origine, dans le défi, en attente —
  des initiales, jamais des photos), le classement (avec l'objectif, « 2 / 5
  séances » et une coche pour qui l'a atteint), la règle du jeu, puis le MOT
  du créateur daté (« Aujourd'hui, 08h24 »). Une invitation se répond en bas
  de l'écran (« Accepter le défi » / « Refuser ») ; une fois dedans, on
  quitte depuis le menu « … », qui propose aussi « Signaler ce défi » (le
  titre et le mot, sous le nom de leur auteur). Un défi refusé ou quitté
  n'est plus lisible : l'écran dit « Ce défi n'est plus là » au lieu d'une
  panne, et hors ligne, « Hors connexion ». Écarts VOULUS avec la maquette :
  pas de « +150 points » ni de « validé si tout le monde atteint l'objectif »
  (un défi entre amis classe, il ne rapporte rien — principe 5 ; la tuile et
  le bloc disent la durée et la vraie règle du jeu), pas de bouton « Ajouter
  des amis » (les invités se choisissent à la création), pas de « suivi en
  temps réel » (le classement se relit, il n'est pas poussé). La photo
  d'haltères de l'en-tête sera fondue dans le dégradé violet quand elle sera
  fournie ; en attendant, une haltère en filigrane.
- La feuille « Défier mes amis » porte un **mot facultatif** (280 caractères,
  comptés en points de code comme le serveur : le champ tronque aux
  caractères visibles, la feuille refuse au-delà avant l'aller-retour).
- La feuille « Ajouter un ami » s'ouvre sur le navigateur RACINE : ouverte
  depuis un onglet, elle passerait sinon sous la bottom bar flottante.
- Elle montre MON code (QR sur aplat blanc — un lecteur veut du contraste,
  pas de l'ambiance) et un champ UNIQUE : l'arobase départage une adresse
  d'un code. Le scan (`mobile_scanner`) vit dans son propre écran — seul
  endroit de la fonctionnalité à toucher du natif : une caméra refusée
  n'enlève que le scan, et l'écran le dit avec un état d'erreur du design
  system. Un e-mail est confirmé opaque ; un code, par le prénom — ou
  « Ce code ne mène à personne ».
- **Se protéger.** Chaque carte d'ami porte un menu « plus d'options »
  (cible tactile pleine, infobulle « Options pour X » pour les lecteurs
  d'écran) avec « Retirer », « Bloquer » et « Signaler » ; chaque mot du fil,
  « Supprimer » (je suis toujours le destinataire de ce que montre le fil),
  « Bloquer » et « Signaler », ces deux derniers visant son AUTEUR.
  « Bloquer » sur un mot n'est pas un doublon de la carte d'ami : retirer une
  amitié laisse en place les mots déjà reçus, donc l'auteur d'un mot blessant
  peut très bien n'avoir plus aucune carte à l'écran ; le menu du mot est
  alors le seul chemin qui mène encore à son blocage. Retirer et bloquer se
  confirment dans une feuille du
  design system qui dit ce qui va se passer ; bloquer fait disparaître la
  personne des amis et du fil sans un mot accusateur (le retour dit seulement
  où revenir dessus). Signaler ouvre une feuille avec le motif (les valeurs
  de l'enum serveur, libellées en français : Harcèlement, Spam ou publicité,
  Contenu inapproprié, Autre) et des précisions facultatives (500
  caractères, blanc = absent) ; un mot est signalé sous le nom de son AUTEUR
  (`fromUserId`, désormais porté par l'entité). La section « Personnes
  bloquées », en pied d'écran, permet de débloquer, et rappelle que rien
  n'est rétabli. Un compte qui n'a plus que des blocages n'est pas « vide ».
- Tous les gestes de l'écran passent par `CommunityGestures` →
  `CommunityActions` / `CommunityModerationActions` → dépôt : le retour est
  un mot sobre dans la barre de message, et l'échec dit VRAI (hors ligne
  n'est pas une panne, `runCommunityGesture`), au lieu d'échouer en silence.
  Le dépôt (`CommunityRepository`) expose `removeFriend`, `blockUser`,
  `unblockUser`, `listBlocked`, `reportUser`, `reportEncouragement`,
  `deleteEncouragement` : impl Dio (204 sans corps, accusé de réception du
  signalement non relu), doublures de test (pilotée et monde en mémoire).
- L'accueil relaie le dernier encouragement (« X t'encourage ») quand il y en
  a un.
- Demandes d'ami, acceptations, encouragements et invitations à un défi
  déclenchent une notification push chez la personne concernée (jamais
  bloquante, jamais sur un refus). La toucher ouvre l'écran concerné :
  l'onglet Amis, ou le défi entre amis — voir
  [notifications.md](notifications.md).

## Couverture

- Unitaires API : calculateur de série (fuseaux, y compris à l'ouest de
  Greenwich : une séance du dimanche 19 h à `America/Montreal` compte pour le
  dimanche, là où un découpage parisien la ferait glisser au lundi ; trous,
  hier/aujourd'hui),
  règles du service (non-énumération, demandes croisées, confidentialité
  null-jamais-zéro, 403 hors amitié, division par zéro d'un objectif).
- e2e API (`test/community.e2e-spec.ts`) : parcours complet à trois comptes —
  demande opaque, acceptation, bascule de confidentialité, encouragements,
  défi rejoint/contribué/quitté, retrait d'ami idempotent ;
  `test/community-friend-requests.e2e-spec.ts` (application isolée, le seau
  du throttle vivant dans l'application) : refus opposable par e-mail et par
  code, bloquer puis débloquer (dans un sens comme dans l'autre) ne fait
  rien réapparaître, reprise de contact par la personne qui a refusé, `429`
  au-delà de 10 demandes par minute sans toucher les autres routes ;
  `test/community-moderation.e2e-spec.ts` (application isolée) : retrait
  d'un encouragement par l'auteur ou le destinataire (jamais un tiers, réponse
  opaque), signalement avec doublon ouvert et garde-fous, blocage (amitié
  retirée, réponses opaques dans les deux sens, liste, déblocage), preuve
  d'un signalement lisible après le retrait du message par son auteur,
  lecture et résolution auditée côté admin, `403` sans `community:moderate`,
  signalement d'un défi entre amis (invité qui a refusé → `201`, clichés du
  titre et du mot en base, doublon ouvert rendu tel quel ; non-membre,
  personne signalée qui n'est pas la créatrice et défi inconnu → le même
  `404` « Défi introuvable. » ; encouragement ET défi → `400` ; clichés
  encore lus par l'administration une fois le défi effacé) ;
  `test/friend-challenges.e2e-spec.ts` : le mot du créateur découpé, rendu
  avec `createdAt`, `durationDays` et `isCreator`, lu par l'invité au détail
  et dans sa liste, inchangé par un rejeu, `404` pour un non-membre ;
  281 caractères → `400`, 280 entourés de blancs → acceptés, blanc → `null` ;
  280 émojis simples acceptés, 281 refusés, 141 ❤️ (282 points de code)
  refusés ; sur un défi ACCEPTÉ, un blocage dans un sens puis dans l'autre
  tait le mot à la liste, au détail et à l'acceptation, sans retirer le défi
  ni empêcher son signalement (cliché intact en base), et la créatrice lit
  toujours le sien ; une INVITATION d'un créateur bloqué (dans un sens puis
  dans l'autre) sort de la liste, rend au détail et à l'acceptation le même
  `404` « Défi introuvable. » qu'un défi inconnu, n'écrit rien, reste
  signalable, et revient au déblocage ; le créateur la voit toujours.
- Unitaires API, modération : garde-fous des blocages et signalements,
  doublon ouvert, nettoyage des précisions, cliché du texte signalé (lu et
  écrit dans une même transaction, `null` si le message ne vient pas de la
  personne visée), clichés du défi signalé (une seule lecture : membre ET
  créateur, sinon rien d'écrit), exclusivité encouragement/défi, audit de la
  résolution, pagination. Défis entre amis (`friend-challenges.service.spec.ts`,
  `friend-challenge.presenter.spec.ts`) : message découpé, blanc ou absent →
  `null`, notification sans le message (mais avec l'identifiant du défi),
  rejeu qui rend le mot déjà écrit, créateur marqué quel que soit le lecteur,
  mot masqué quand le CRÉATEUR est séparé du lecteur par un blocage (et lui
  seul), invitation d'un créateur bloqué absente de la liste et `404` au
  détail, à l'acceptation et au refus sans rien écrire. Notifications
  (`community-notifier.spec.ts`) : chaque message porte sa destination,
  validée par le schéma publié `pushDataSchema`. DTO
  (`community.dto.spec.ts`) : chaque texte libre (mot et titre d'un défi, mot
  d'un encouragement, précisions d'un signalement) posé au DTO ET au contrat
  Zod, qui doivent s'accorder (lettres, émojis simples, ❤️, sélecteurs,
  blancs, absent). Swagger (`community-dtos.openapi.spec.ts`, et
  `app/openapi-document.spec.ts` sur le document de l'application ENTIÈRE) :
  aucun champ de requête `string | null` ou `number | null` n'est annoncé
  comme un objet vide.
- Vitest back-office (`apps/admin/src/app/reports/page.test.tsx`,
  `apps/admin/src/lib/admin-community-api.test.ts`) : liste des ouverts par défaut
  avec motif, personnes liées à leur fiche et contenu visé (message vivant,
  cliché d'un message retiré depuis, signalement visant la personne, défi
  avec son mot cité ou « (sans message) ») ;
  résolution puis rechargement ; réouverture ; filtres Résolus/Tous ; pagination par
  curseur ; 403 distingué d'une panne, à la lecture comme à la résolution ;
  redirection sans jeton ; URL, corps du PATCH et rejet d'une réponse hors
  contrat côté transport.
- Ligues : barème et groupes (`league-ladder.spec.ts` : premier groupe qui a
  de la place, groupe plein à 20, nouveau groupe après le plus grand) ;
  service (`leagues.service.spec.ts` : classement lu sur MON groupe,
  règlement d'une période échue sur SON groupe, personnes bloquées tues sans
  décaler les rangs ni la zone, résultat de la semaine passée lu en base) ;
  e2e `test/leagues.e2e-spec.ts` (règlement à la lecture, résultat servi
  toute la semaine, semaine plus ancienne réglée mais pas annoncée, montée
  qui survit à une séance du lundi, règlement fait par un autre : chacun lit
  SON résultat) et `test/leagues-groups.e2e-spec.ts` (dix ouvertures
  simultanées face à un groupe de 19, écritures retenues pour forcer la
  course : 20 puis 9 ; ouverture dans une transaction ; changement de groupe
  au règlement et à la lecture ; classement de mon seul groupe, blocages
  dans les deux sens tus avec un trou dans les rangs).
- Défis du mois : catalogue (fenêtre UTC, passage d'année, slugs uniques,
  textes visibles sans tiret cadratin), service (création AVANT la liste sur
  un mois vierge, rien sur un mois servi) ; e2e : cinq lectures concurrentes
  d'un mois vierge produisent un seul jeu, une lecture de plus ne recrée rien.
- Widgets mobile (`test/features/community/`) : monde d'exemple complet, états
  erreur/vide/chargement, acceptation de demande, ajout opaque, réglage de
  partage, défis présents sans ami (invitation dans la section « Amis »,
  pas d'état vide global, la feuille d'ajout s'ouvre ; une demande reçue
  suffit à retirer l'invitation) ; gestes de protection (`community_moderation_test.dart`) : retrait
  d'un ami (confirmation, annulation sans effet, échec hors ligne annoncé et
  ami conservé, cible tactile), blocage (la personne quitte amis et fil,
  rejoint « Personnes bloquées », retour non accusateur), blocage DEPUIS UN
  MOT quand l'auteur n'est plus un ami (aucune carte à l'écran : le mot
  disparaît, les autres restent, l'auteur rejoint « Personnes bloquées »
  sous son nom ; annulation sans effet), déblocage (ligne
  retirée, amitié non rétablie, compte « non vide »), signalement d'un ami
  et d'un mot (motif serveur, précisions nettoyées, auteur du mot), retrait
  d'un mot du fil. Feuille de signalement (`report_sheet_test.dart`) : quatre
  motifs en français, envoi qui attend un motif, précisions nettoyées,
  annulation. Contrat Dio (`community_repository_impl_test.dart`) : chemins,
  verbes, 204 sans corps, charge utile des signalements (`encouragementId`
  et `details` omis quand absents), `fromUserId` lu dans le fil, réseau mort
  en `NetworkException`.
- Code ami : normalisation éprouvée des DEUX côtés (spec Jest et test Dart
  miroirs — formes affichée/minuscule/QR, refus des caractères ambigus) ;
  service (silence sur code inconnu ou soi-même, aperçu 404) ; e2e du tour
  complet profil → aperçu → demande → amis ; feuille d'ajout (QR affiché,
  champ unique, saisie invalide retenue au bord).

## Une ligue ne peut pas devenir un second score

La tranche 42 apportera des ligues. Deux contraintes les encadrent avant la
première ligne de code.

**Elle ne double pas le titre Carlys.** Le titre est le seul score de
progression personnelle (voir [progression.md](progression.md), « Un seul
score : la règle de non-concurrence »). Une ligue est une comparaison SOCIALE
bornée dans le temps : elle dit qui fait quoi pendant une période, la fenêtre
se ferme puis repart, et rien de ce qu’elle affiche ne devient un palier que la
personne « est ». En particulier, une ligue assise sur `streakDays`
contredirait l’axe Constance, qui compte les semaines et non les jours : trois
jours sans séance ne retirent rien à l’axe tant que chaque semaine garde la
sienne, alors qu’ils remettent la série à zéro. Le même arrêt ferait reculer un
écran et pas l’autre, et celui qui recule serait servi par le serveur alors que
le profil, lui, est local.

**Elle contredisait le principe 5 — tranché le 19 septembre 2026.** Le
principe disait « la progression des défis est collective, jamais un
classement individuel », sans restriction : une ligue ordonne des personnes,
donc aucune rédaction ne réconciliait les deux. Le propriétaire du produit a
tranché en faveur des ligues et des défis entre amis ; le principe 5 ci-dessus
est réécrit en conséquence et ne porte plus que sur les défis COLLECTIFS, avec
les trois conditions qui encadrent tout classement (périmètre choisi, fenêtre
qui se ferme, aucun report dans le profil). Ce que le service tient reste
intact pour les défis collectifs : seule la somme agrégée des contributions
sort du serveur, jamais la part d’une personne nommée
(`community-challenges.repository.ts`, `withStats`).

**Sur quel fait une ligue compte.** Pas sur `streakDays` (raison ci-dessus),
et pas non plus sur « les semaines avec séance » : c’est EXACTEMENT ce que
l’axe Constance compte déjà (`progression_engine.dart`, `_constance` : les
semaines avec au moins une séance terminée sur les huit dernières). Une ligue
assise dessus ne mesurerait pas autre chose, elle repèserait le même fait sur
une autre échelle, et le même point de bascule ferait bouger deux nombres à
l’écran. Une ligue compte donc un fait que le profil ne regarde pas —
par exemple la somme des contributions versées aux défis pendant la période,
ou une métrique (pas, eau) qui n’entre dans aucun axe. Le test est simple et
il s’applique avant d’écrire la règle : si le fait figure dans
`ProgressionFacts` ou dans `RewardFacts`, la ligue ne le compte pas.

### Ce test, mesuré — et ce qu’il devient (19 septembre 2026)

Le test ci-dessus a été écrit AVANT d’être appliqué aux métriques réelles.
Appliqué, il ne laisse presque rien :

| métrique | le profil la regarde-t-il ? | où |
| -------- | --------------------------- | -- |
| `WORKOUTS` | OUI | `ProgressionFacts.completedSessions`, `RewardFacts.completedSessions` |
| `QUIZ_CORRECT` | OUI | `ProgressionFacts.lessonsAnswered`, `RewardFacts.lessonsAnswered` |
| `ACTIVE_SECONDS` | non | absente des deux |
| `DISTANCE_METERS` | non | absente des deux |

Les deux seules qui passent sont exactement celles qu’une séance de FONTE
produit à zéro : `sessionEffort` (`workouts.service.ts`) le dit en toutes
lettres — « les séries sans chrono ni distance, la fonte, l’immense majorité,
apportent zéro, ce qui est exact ». Le test strict ne donne donc pas une ligue
plus sage, il donne une ligue que seuls les coureurs peuvent jouer.

Il est donc ramené à ce qu’il protégeait. Ce qui empêche une ligue de devenir
un second score, ce n’est pas la disjonction des FAITS — c’est qu’elle ne
rende rien au profil. Les trois conditions du principe 5 tiennent seules, et
la troisième fait tout le travail :

- **aucun report dans le profil.** Ni point, ni axe, ni titre, ni récompense.
  Vérifiable, et pas seulement affirmé : ni `progression_facts_builder.dart`
  ni `reward_facts_builder.dart` ne lisent `LeagueMembership`, et aucun des
  deux ne connaît le mot « ligue ». C’est la garde à relire à chaque ajout.
- **fenêtre qui se ferme** — une semaine, puis on repart de zéro. Un rang de
  ligue n’est jamais un palier que la personne « est ».
- **périmètre choisi** — la ligue est un OPT-IN, voir plus bas.

Et la collision que le test visait est bornée par la FORME des deux mesures :
l’axe Constance est un binaire par semaine sur huit semaines — il ne sait pas
distinguer une séance de cinq ; la ligue est un total continu sur UNE semaine,
et cette différence-là est tout son signal. Elles bougent ensemble une fois
par semaine au plus, à la première séance, et jamais dans la même unité.

## Les ligues, barème complet

**Cinq divisions**, dans l’ordre : Bronze, Argent, Or, Platine, Diamant.

**La période est la semaine ISO, en UTC** (`YYYY-Www`, fonction pure de
l’instant comme `monthWindowUtc`). La semaine plutôt que le mois : une fenêtre
qui se ferme doit se fermer assez souvent pour se sentir, et un mauvais mois
serait irrattrapable.

**Le score est l’EFFORT de la période, converti en points** — pas les
contributions versées aux défis. La nuance est délibérée : compter les
contributions ferait dépendre le rang d’une autre fonctionnalité (avoir
rejoint le jeu du mois), et une ligue dont le droit d’entrée est une seconde
fonctionnalité est un piège. L’effort est versé par la MÊME couture que les
deux familles de défis (`verser`), donc les trois compteurs ne peuvent pas
diverger.

| métrique | une unité de contribution | points |
| -------- | ------------------------- | ------ |
| `WORKOUTS` | 1 séance terminée | **50** |
| `ACTIVE_SECONDS` | 60 s réellement chronométrées | **1** |
| `DISTANCE_METERS` | 100 m parcourus | **1** |
| `QUIZ_CORRECT` | 1 bonne réponse, première du jour | **10** |

Le barème est choisi pour qu’AUCUNE métrique ne domine les autres : 10 km de
course valent 100 points, soit deux séances ; une heure de chrono en vaut 60,
soit un peu plus d’une. Une semaine de fonte à trois séances fait 150 points,
une semaine de course de 20 km en fait 200 : un pratiquant de fonte et un
coureur peuvent tous deux tenir le haut d’une division. Ordre de grandeur
d’une semaine régulière : 150 à 400 points.

La conversion est une **division entière tronquée** : 59 secondes valent 0
point, 119 mètres en valent 1. Le reste n’est PAS reporté — le reporter
demanderait un registre de restes par personne et par métrique, et rendrait le
score dépendant de l’ordre des écritures.

**On se classe dans un GROUPE de 20** (`LEAGUE_GROUP_SIZE`, `league-ladder.ts`),
jamais contre toute une division : avec des milliers de joueurs en Bronze,
entrer dans le top 5 d'un classement mondial serait hors d'atteinte, et la
promesse « vingt places » ne voulait rien dire. Chaque période d'une division
se découpe donc en groupes (`LeagueMembership.cohort`), et tout ce qui classe
se lit par groupe — `(periodKey, division, cohort)` : le classement servi, le
règlement, la zone de montée et le compte des joueurs actifs.

- **Remplissage.** Une période s'ouvre (première séance ou première lecture
  de la semaine) dans le PREMIER groupe de sa (période, division), par numéro
  croissant, qui compte moins de 20 membres ; s'ils sont tous pleins, dans un
  nouveau groupe numéroté après le plus grand (`cohortToJoin`, pure). Remplir
  d'abord plutôt qu'ouvrir un groupe par vague d'arrivées : un groupe de trois
  ne décide de rien. Un groupe qui compte moins de 20 membres se joue tel
  quel : ni adversaire fabriqué, ni fusion.
- **Verrou.** Compter puis écrire est une lecture-écriture : deux ouvertures
  simultanées liraient chacune « 19 » et rempliraient le groupe à 21. Un index
  unique ne sait pas dire « au plus 20 lignes » ; l'attribution est donc
  sérialisée par un verrou consultatif TRANSACTIONNEL de PostgreSQL
  (`pg_advisory_xact_lock`), pris par (période, division) sur une empreinte
  stable de la clé (`league-groups.ts`), dans la MÊME transaction que
  l'écriture de la ligne. Il ne bloque ni les autres divisions ni les autres
  semaines, et se libère tout seul à la fin de la transaction. L'écriture est
  un `INSERT … ON CONFLICT DO NOTHING` : une ouverture concurrente de la même
  ligne n'avorte pas la transaction englobante (la réponse de quiz verse sa
  part de ligue dans la sienne).
- **Changer de division, c'est changer de groupe.** Les deux réalignements
  (voir plus bas) prennent une place dans la division d'arrivée sous le même
  verrou, comme une ouverture ; quand un règlement en déplace plusieurs, les
  verrous se prennent dans un ordre fixe, sans interblocage possible.
- **Les lignes d'avant les groupes** (migration
  `20260924120000_ligues_groupes_de_vingt`) gardent le groupe `0` : leur
  classement reste celui qu'elles avaient, toute la division. Une semaine
  déjà ouverte au-delà de 20 se finit telle quelle ; les ouvertures suivantes
  débordent dans le groupe 1.

**Montées et descentes, au règlement de la période :**

- les **5 premiers** de chaque groupe montent d’une division (rien au-dessus
  de Diamant) ;
- les **5 derniers** descendent d’une division (rien en dessous de Bronze),
  **mais uniquement parmi les membres dont le score est supérieur à zéro**.
  Un score nul veut dire « n’a pas joué », et ne fait jamais descendre : la
  règle du dépôt est qu’aucun axe ne punit une absence (`progression_engine`,
  fenêtre de 28 jours), et une ligue qui reléguerait une semaine de maladie la
  contredirait ;
- si **moins de 10 membres du groupe ont joué**, personne ne bouge. Un
  classement à trois ne décide pas d’une division.

**Les ex æquo partagent leur rang, et le suivant saute** — même règle que les
défis entre amis. Départager par l’identifiant serait un tirage au sort
déguisé. Conséquence assumée : une égalité à la frontière peut faire monter
plus de cinq personnes.

**Où j’en suis face à la montée, dit par le serveur.** `GET /league` (et les
réponses de `join`/`leave`) porte un bloc `promotion`, `null` sans adhésion :
le barème lui-même (`promotedCount`, `minPlayers`), les joueurs du groupe
qui ont marqué (`activePlayers`), `topDivision` en Diamant, et `inZone`,
`zoneScore`, `pointsToZone`. La montée se joue au RANG, pas à un seuil de
points : `zoneScore` est le cinquième score des AUTRES joueurs, qu’il suffit
d’égaler, et il BOUGE avec eux — `null` tant que moins de cinq autres ont
marqué, un point suffit alors. `inZone` dit la zone au sens du rang seul : le
minimum de dix joueurs se lit à part (`activePlayers` face à `minPlayers`), et
la garde d’ambiguïté du règlement n’y entre pas. Le calcul vit à côté du
règlement et partage sa règle de montée (`promotionOutlook` et
`settleDivision` appellent `ranksForPromotion`, `league-ladder.ts`) : une copie
côté mobile divergerait exactement sur l’ex æquo à la frontière, et à la
première retouche du barème. L’appli lit le bloc de façon tolérante — absent
(serveur plus ancien) ou mal typé, il vaut `null` et la ligue s’affiche sans
zone.

**La ligue est un OPT-IN** (`CommunityPreference.joinsLeague`, défaut
`false`). Y entrer EST le consentement, ce qu’exige le « périmètre choisi ».
C’est un réglage DISTINCT de `sharesProgress` : celui-ci décide si un ami voit
ta progression, il n’a jamais promis de montrer ton nom et ton score à
dix-neuf inconnus. Sortir arrête le compte ; la ligne de la semaine en cours
reste jusqu’à son règlement, et aucune autre n’est créée ensuite.

**Le règlement est PARESSEUX**, comme le jeu du mois et les défis entre amis :
la première lecture qui passe après la fin d’une période fige les rangs de
cette période (`finalRank`), pose `settledAt`, et l’écriture est conditionnée
à sa nullité — deux lectures simultanées n’en règlent qu’une. Une lecture
règle le GROUPE ENTIER, sans quoi deux personnes liraient deux classements
différents de la même semaine.

**Un classement déjà annoncé ne se corrige pas.** La garde `settledAt: null`
porte sur CHAQUE ligne, et le rang, la division suivante et `settledAt`
s’écrivent ensemble : une ligne réglée n’est jamais réécrite, et seules les
lignes que ce règlement vient de régler réalignent leur semaine suivante. Une
ligne peut en effet entrer APRÈS coup dans un groupe réglé — une séance
synchronisée en retard ouvre la semaine close d’un nouveau membre, ou un
réalignement déplace une semaine passée —, et elle se règle alors seule, sur
le groupe tel qu’il est : sa place se lit parmi des rangs figés, et personne
ne glisse d’un cran. Le règlement réécrivait auparavant les rangs du groupe
entier, et pouvait annuler après coup une montée déjà annoncée (relecture du
24 septembre 2026, e2e dans `test/leagues.e2e-spec.ts`).

**Le résultat de la semaine passée, pour TOUS.** `lastResult` est le résultat
réglé de la semaine ISO qui précède immédiatement la semaine en cours
(`previousPeriodKey`), lu en base sur MA ligne : rang figé, division d’où je
pars, division où j’arrive. Peu importe qui a réglé le groupe — moi ou
n’importe quel autre membre : chacun lit SON résultat. Il était auparavant
rendu par le règlement lui-même, donc au seul lecteur dont la lecture
réglait la semaine ; les dix-neuf autres voyaient leur division changer sans
jamais lire « te voilà en Argent ». Il reste servi toute la semaine en cours :
la phrase dit « la semaine passée », elle est vraie jusqu’à dimanche. Pas de
ligne la semaine passée (six semaines d’absence, par exemple) : pas de
`lastResult`, même si une semaine plus ancienne vient d’être réglée.

**Une personne bloquée est absente du classement** (principe 6), dans un sens
comme dans l’autre. Les RANGS restent ceux du groupe entier — on ne décale
personne, un trou dans la numérotation est honnête —, et la zone de montée se
calcule elle aussi sur tout le groupe : taire quelqu’un ne rapproche personne
de la montée.

**Une semaine ouverte AVANT le règlement de la précédente suit la décision.**
Une séance du lundi peut ouvrir la nouvelle semaine avant que quiconque ait
relu la ligue : la semaine passée n’a alors pas encore de division suivante,
et la nouvelle s’ouvre dans l’ancienne. Deux gardes la remettent à sa place,
sans toucher à son score : le règlement réaligne la PREMIÈRE période ouverte
après celle qu’il règle, pour chaque membre du groupe (qui que soit le
lecteur qui règle), et chaque lecture aligne la période en cours de son
lecteur sur la division qui lui revient — filet des lignes écrites avant ce
correctif. Dans les deux cas, la période change aussi de GROUPE : elle prend
une place dans la division d’arrivée, sous son verrou. La division d’une période se lit toujours sur les périodes
ANTÉRIEURES (`divisionToOpen`), jamais sur elle-même : c’est ce qui faisait
perdre la montée (défaut trouvé à la relecture du 23 septembre 2026, e2e dans
`test/leagues.e2e-spec.ts`).

Deux conséquences, relevées à la relecture du 24 septembre 2026 :

- **plusieurs semaines échues se règlent dans l’ordre, chacune sur sa ligne
  RELUE.** Régler l’avant-dernière semaine peut réaligner la dernière
  (division et groupe changés) ; la régler ensuite avec la ligne lue avant ce
  réalignement réglait l’ancien groupe, sans son lecteur, et laissait sa
  semaine passée en suspens — sans `lastResult`, et la semaine en cours
  ouverte dans la mauvaise division jusqu’à une seconde lecture ;
- **seule la semaine qui SUIT est réalignée, jamais une plus lointaine.** Si
  elle est déjà réglée, elle a décidé de la suite elle-même : régler une
  ligne tardive, plus ancienne, ne saute pas par-dessus pour réécrire la
  semaine en cours.

**Les périodes manquées ne se rattrapent pas, et n’ont pas à l’être.** Aucune
ligne n’existe pour une semaine sans effort et sans lecture : il n’y a donc
rien à régler. Six semaines d’absence produisent ZÉRO relégation, et le retour
ouvre une semaine neuve dans la division quittée. Ce n’est pas une règle
ajoutée par-dessus la matérialisation paresseuse, c’est sa conséquence.

## Défis entre amis

Des TABLES SÉPARÉES des défis collectifs, et pour des raisons mesurées :

- la lecture des défis collectifs n'a **aucun prédicat de visibilité**
  (`listOpenChallenges` filtre sur la seule fenêtre de dates) parce qu'elle
  n'en a jamais eu besoin. Y glisser des défis d'utilisateurs exposerait le
  défi de chacun à tout le monde, instantanément ;
- `@@unique([slug, month])` EST l'identité d'un défi de catalogue. Un défi
  entre amis n'a ni slug ni mois ;
- la sémantique du DÉPART est **inverse**. Quitter un défi collectif garde la
  contribution acquise, parce qu'un compteur collectif ne peut que monter ;
  quitter un défi entre amis retire du classement, qui est individuel ;
- rejoindre un défi collectif est un simple upsert : il n'existe pas d'état
  « invité, pas encore accepté », et c'est tout l'objet de celui-ci.

Ce qui EST partagé : l'enum `ChallengeMetric` et le **chemin d'écriture des
contributions** — une séance terminée verse aux deux familles par le même
appel. Deux compteurs séparés dériveraient au premier ajout de métrique.

Les garde-fous, chacun repris d'une règle déjà écrite :

- **on n'invite que des amis acceptés**, jamais quelqu'un qu'un blocage
  sépare, dans un sens comme dans l'autre. Un seul message pour les deux
  refus : rien ne doit distinguer « pas ami » de « t'a bloqué », sans quoi
  l'invitation devient un détecteur de blocage ;
- **une invitation bloquée disparaît.** Le blocage peut arriver APRÈS
  l'invitation : tant que je ne suis pas au classement — invitation en
  attente (`INVITED`) ou refusée (`DECLINED`), défi quitté (`LEFT`) —, le
  défi d'un créateur qu'un blocage sépare de moi (dans un sens ou dans
  l'autre) sort de ma liste, et son détail, son acceptation et son refus
  répondent le `404` « Défi introuvable. » d'un défi inconnu, sans rien
  écrire (`isHiddenByBlock`, `friend-challenge.presenter.ts`). Sans cette
  règle, j'acceptais encore le défi de quelqu'un que j'avais bloqué, et un
  créateur bloqué gardait une carte sur mon écran. La première version ne
  masquait que l'invitation EN ATTENTE : refuser, bloquer, puis réaccepter
  rouvrait le défi (relecture du 24 septembre 2026, e2e dans
  `test/friend-challenges.e2e-spec.ts`). Le créateur, lui, voit toujours
  son défi et son invitée (membre acceptée d'office, sa liste ne se réécrit
  pas), et le signalement reste possible. Débloquer fait revenir
  l'invitation ;
- **plafonds** : 9 invités par défi, 5 défis ouverts par créateur. Sans eux,
  l'invitation devient un canal d'envoi de messages vers quelqu'un qui ne l'a
  pas demandé — exactement ce que le refus opposable des demandes d'ami avait
  fermé ;
- **`endsAt` est calculé côté serveur** depuis `durationDays`. Une fin fournie
  par l'appelant est un défi éternel en une requête ;
- **`CHALLENGE_INVITES`** est une famille de notification à part : quelqu'un
  peut vouloir des encouragements sans vouloir être défié.

### Le mot du créateur (23 septembre 2026)

Une maquette de l'écran de détail montrait un « Message de Chloé » daté. Le
propriétaire du produit a tranché : **un message facultatif à la création,
stocké côté serveur, affiché avec son heure et signalable**. Aucune
récompense ni point n'y est attaché (principe 5, inchangé), et on n'ajoute
toujours personne après la création.

- **Facultatif**, parce qu'un défi se comprend sans lui : le titre, la
  métrique et la durée disent déjà tout ce qui compte. Un champ obligatoire
  produirait des « . » et des « go » pour franchir la validation.
- **280 caractères au plus, mesurés APRÈS découpage** des blancs autour
  (`FRIEND_CHALLENGE_MESSAGE_MAX_LENGTH`, contrat partagé, réutilisé par le
  DTO) : la longueur d'un encouragement, dont c'est la version adressée à
  tous les invités d'un coup. Au-delà, `400`. Vide après découpage, il vaut
  « pas de message » et s'écrit `NULL`, jamais une chaîne vide (une bulle
  vide à l'écran).
- **Un « caractère » est un POINT DE CODE Unicode**, compté par la même
  fonction des deux côtés (`codePointLength` du contrat, `@MaxCodePoints` au
  DTO) — pour le mot, et pour tous les textes libres de la communauté : titre
  d'un défi (80, `FRIEND_CHALLENGE_TITLE_MAX_LENGTH`), mot d'un encouragement
  (280, `ENCOURAGEMENT_MESSAGE_MAX_LENGTH`, contrat `encourageRequestSchema`)
  et précisions d'un signalement (500), qui avaient le même écart. Un émoji simple vaut un ; un émoji composé en vaut plusieurs (❤️ et
  son sélecteur de variante : deux ; un drapeau : deux ; une famille : cinq
  et plus). Ni les unités UTF-16 (`z.string().max()` refusait 141 émojis),
  ni le compte de `@MaxLength` (qui efface les sélecteurs de variante : la
  base stockait jusqu'à trois fois la longueur annoncée), ni les graphèmes
  (sans borne de stockage : un seul peut empiler des centaines de
  diacritiques). C'est aussi l'unité de `maxLength` en JSON Schema, donc ce
  que Swagger annonce. Un client qui borne la saisie compte de même
  (`runes` en Dart), sans quoi il laisse taper ce que l'API refusera.
- **Écrit une fois.** Le rejeu idempotent de la création (même `id`) rend
  le défi tel qu'il est en base, message compris : il n'existe aucune route
  pour le modifier. Son heure est donc `createdAt`, rendue en ISO UTC ; le
  client la localise.
- **Visible des seuls membres**, quel que soit leur statut (invité compris :
  c'est en lisant le défi qu'on décide de l'accepter), hors blocage (voir
  ci-dessous). Pour tous les autres, le défi entier est un `404`, message
  compris.
- **Masqué après un blocage.** Si un blocage sépare le lecteur du créateur, dans
  un sens ou dans l'autre, et que le lecteur est au classement (défi
  accepté, pas quitté), la liste, le détail et l'acceptation rendent
  `message: null` (un
  défi dont il n'est pas au classement, lui, disparaît entièrement : voir
  plus haut) : bloquer est LE geste de protection, et un mot blessant
  de 280 caractères ne doit pas y survivre alors que le fil tait déjà les
  encouragements de la même personne. Le défi, lui, reste lisible avec son
  titre, son créateur et son classement : c'est un résultat partagé, et le
  réécrire (retirer quelqu'un du classement) fausserait les rangs des
  autres. Le titre reste aussi : il nomme le défi, 80 caractères, et il a
  déjà été porté par la notification d'invitation. Le signalement reste
  possible : son cliché est lu en base, pas dans la réponse. Débloquer rend
  le mot.
- **Jamais dans la notification push.** L'invitation dit « Chloé te défie :
  <titre> », sans le mot ; elle porte l'identifiant du défi (`data`,
  `destination: friend-challenge`), pour que le toucher ouvre CE défi. Le titre est borné à 80 caractères ; le mot, trois
  fois plus long et plus personnel, s'afficherait sur un écran verrouillé,
  lisible par-dessus l'épaule, et hors de tout geste de protection : c'est
  dans le défi qu'il se lit, là où l'on peut le signaler.
- **Signalable, avec cliché.** `POST /community/reports` accepte
  `friendChallengeId` (exclusif avec `encouragementId`, `400` sinon). Le
  signalant doit être membre du défi, **quel que soit son statut** — il a pu
  lire le mot avant de refuser —, et la personne signalée doit en être la
  **créatrice** : le titre et le mot sont les siens. Toute autre combinaison
  (défi inconnu, non-membre, autre personne visée) répond le MÊME `404`
  « Défi introuvable. », sans oracle. Le titre et le mot sont figés dans
  `friendChallengeTitle` et `friendChallengeMessage` par la transaction qui
  crée le signalement, comme le texte d'un encouragement ; le doublon ouvert
  (même signalant, même personne, même défi) rend le même accusé.

La réponse d'un défi (liste, détail, création, acceptation) porte en
conséquence `message` (ou `null` : pas de mot, ou mot masqué par un blocage),
`createdAt`, `durationDays` et, sur chaque membre, `isCreator` (vrai pour le
créateur, membre `ACCEPTED` d'office).

### La clôture, sans cron — mais avec une écriture

Les défis collectifs ne closent RIEN : ils cessent simplement d'être lus
(`endsAt >= now`). Un défi entre amis, lui, produit un **résultat** : le
classement final doit rester stable même si plus personne ne regarde.

La première lecture qui passe après la fin règle donc le défi : rangs figés
dans `finalRank`, `status = CLOSED`, `closedAt` posé. L'écriture est
conditionnée à `closedAt: null` — deux lectures simultanées d'un défi échu
tentent chacune le règlement, une seule le gagne. Même absence de tâche
planifiée que le jeu du mois, une écriture de plus.

Le rang se calcule à contribution décroissante, **ex æquo compris** : deux
personnes à 12 séances sont deuxièmes, et la suivante quatrième. Départager
par l'identifiant serait un tirage au sort déguisé.
