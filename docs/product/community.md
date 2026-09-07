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
5. **La progression des défis est collective.** La barre montre
   `somme des contributions / objectif`, bornée à 1 — l'effort du groupe,
   jamais un classement individuel.
6. **Chacun peut se protéger, sans que l'autre le sache.** Bloquer quelqu'un
   est unilatéral et OPAQUE : l'amitié et les demandes en attente sont
   retirées dans les deux sens, puis, pour chacun des deux, l'autre répond
   comme un compte qui n'existe pas (demande muette en `202`, code ami en
   `404`, encouragement en `403`, absent des listes et du fil). Jamais de
   « tu es bloqué ». Un encouragement se retire par son auteur OU son
   destinataire. Un signalement (personne, ou encouragement précis) part vers
   l'administration, qui le lit et le résout avec une permission dédiée ; la
   personne signalée n'en sait rien, et retirer son message n'efface pas la
   preuve : le texte est figé au moment du signalement.

## Modèle de données (Prisma)

| Table | Rôle |
| --- | --- |
| `Friendship` | UNE ligne par paire ; `PENDING` → `ACCEPTED`/`DECLINED`, direction conservée (qui a demandé). La symétrie est imposée par le service. |
| `Encouragement` | Mot d'un ami ; le nom de l'expéditeur est lu au moment de servir (nom COURANT, pas dénormalisé). |
| `CommunityChallenge` | Défi collectif du MOIS (`month`, `YYYY-MM` UTC), `SPORT` ou `CULTURE`, avec `target` et fenêtre `startsAt`/`endsAt` ; unique par `(slug, month)`, matérialisé paresseusement depuis le catalogue en code, jamais créé par un utilisateur. |
| `ChallengeParticipation` | Participation + `contribution` individuelle à l'objectif. |
| `CommunityPreference` | `sharesProgress` (absence = partagé, défaut du modèle). |
| `CommunityBlock` | Blocage unilatéral `(blockerId, blockedId)`, unique par paire orientée ; consulté dans les DEUX sens partout où deux personnes se rencontrent. |
| `CommunityReport` | Signalement : `reporterId`, `reportedUserId`, `encouragementId?` (mis à `NULL` si le message est supprimé), `encouragementMessage?` (cliché du texte visé, pris dans la même transaction que le signalement : la preuve survit au retrait du message), `reason` (`HARCELEMENT`, `SPAM`, `CONTENU_INAPPROPRIE`, `AUTRE`), `details?` (500 caractères), `status` (`OPEN`, `RESOLVED`), `resolvedAt?`. |

## API (`/api/v1/community`)

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| GET | `/feed` | Encouragements reçus (50 max, plus récents d'abord) |
| POST | `/encouragements` | Encourager un ami accepté (`403` sinon) |
| GET | `/friends` | Amis acceptés, stats `null` si progression privée |
| DELETE | `/friends/:userId` | Retirer un ami (idempotent) |
| GET | `/requests` | Demandes REÇUES en attente |
| POST | `/requests` | Demander par e-mail exact OU `friendCode` (exactement un des deux) — `202` opaque, refus opposable 30 jours, 10 demandes/min par adresse |
| GET | `/friend-codes/:code` | Nom du porteur d'un code (toutes formes humaines acceptées) — `404` sinon |
| POST | `/requests/:id/accept` · `/decline` | Répondre (destinataire uniquement) |
| GET | `/challenges` | Défis ouverts, progression collective incluse ; crée le jeu du mois à la première lecture (voir ci-dessous) |
| POST | `/challenges/:id/join` | Rejoindre (idempotent) |
| DELETE | `/challenges/:id/join` | Quitter (idempotent) |
| GET · PATCH | `/profile` | Ma préférence `sharesProgress` + mon `friendCode` |
| POST | `/blocks/:userId` | Bloquer (idempotent, `204`) : retire amitié et demandes dans les deux sens ; `400` soi-même, `404` compte inconnu |
| DELETE | `/blocks/:userId` | Débloquer (idempotent, `204`) : ne rétablit rien |
| GET | `/blocks` | Personnes que j'ai bloquées (`userId`, `displayName`, `blockedAt`) |
| DELETE | `/encouragements/:id` | Retirer un encouragement (auteur OU destinataire) : `204` rejouable et opaque, un identifiant étranger n'a aucun effet |
| POST | `/reports` | Signaler une personne, ou un encouragement qu'elle m'a envoyé (`201`) ; un signalement OUVERT identique n'est pas dupliqué (même accusé de réception) ; `404` si l'encouragement ne vient pas d'elle ou ne m'était pas adressé |

Côté back-office (`/api/v1/admin/community`, jeton admin, permission
`community:moderate`, actions auditées) :

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| GET | `/reports?status=&limit=&cursor=` | Signalements, plus récents d'abord, avec les deux personnes (id, e-mail, nom) et le texte de l'encouragement visé, figé au moment du signalement (lisible même si l'auteur l'a retiré depuis) |
| PATCH | `/reports/:id` | `{ status: "RESOLVED" }` résout (`resolvedAt` posé, audit `admin.community_report_resolved`) ; `{ status: "OPEN" }` rouvre (`admin.community_report_reopened`) ; rejouer le même statut ne réécrit rien |

Ces deux routes ont leur écran : la page **Signalements** du back-office
(`apps/admin`, `/reports`, entrée de navigation à côté d'Utilisateurs).
Elle liste les signalements ouverts par défaut (résolus, ou tous, sur
demande ; pages de 50 par curseur, « Charger la suite ») avec la date, le
motif et ses précisions, l'auteur, la personne visée et le texte de
l'encouragement visé. Ce texte est le cliché figé au signalement, donc trois
états seulement : le message seul (il est encore dans le fil) ; le message
suivi de « Message retiré depuis » (`encouragementId` remis à `NULL` par la
suppression, la preuve reste) ; « La personne en général » quand le
signalement ne vise aucun message. Un
bouton résout chaque signalement, un autre le rouvre ; résoudre ne prévient
personne et ne touche pas au compte visé : les deux personnes renvoient à
leur fiche utilisateur, seul endroit où l'on suspend. Sans
`community:moderate`, la page montre le refus du serveur tel quel (403),
sans le déguiser en panne. Transport : `adminApi.listCommunityReports` et
`adminApi.setCommunityReportStatus` (`apps/admin/src/lib/admin-api.ts`),
réponses validées par `adminCommunityReportSchema`.

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
  et toujours avec la réponse d'un compte inexistant. Bloquer supprime
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
- Les objectifs sont exprimés dans l'unité réellement comptée : une séance
  terminée (`SPORT`), une première bonne réponse par leçon et par jour
  (`CULTURE`).

## Contribution des séances aux défis

À la clôture d'une séance (`workouts.service`), `recordWorkoutCompleted`
incrémente de 1 la contribution de chaque défi **SPORT** rejoint dont la
fenêtre couvre la clôture. Comme le recalcul des records : l'échec est
journalisé et ne fait JAMAIS échouer la clôture.

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
  dire ; le dépôt de démonstration (`lib/demo/demo_community.dart`) fait
  vivre l'écran sans réseau.
- L'écran distingue HORS CONNEXION (statut dédié, comme le coach —
  `ConnectionAwareError`), panne serveur (« Réessayer » réessaie vraiment),
  premier chargement, vide (avec l'action « Ajouter un ami ») et données.
  Pendant un rafraîchissement, la liste reste en place (Riverpod conserve la
  valeur précédente).
- **Les défis du mois changent l'état vide.** Depuis que le serveur crée le
  jeu du mois à la lecture, un compte neuf en ligne voit toujours des défis :
  l'écran n'est plus jamais « vide » et ne suppose plus une liste de défis
  absente pour toujours. L'invitation à ajouter un premier ami vit donc dans
  la section « Amis » (`FriendsEmptyCard`), affichée tant qu'il n'y a ni ami
  ni demande en attente ; l'état vide global ne reste possible que si le
  serveur ne renvoie vraiment rien (ni défis, ni blocages), et il dit alors
  la vérité. Hors ligne au premier lancement, c'est « Hors connexion » qui
  s'affiche, jamais « personne ici » : rien n'a pu être lu.
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
  « Supprimer » (je suis toujours le destinataire de ce que montre le fil)
  et « Signaler ». Retirer et bloquer se confirment dans une feuille du
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
  signalement non relu), dépôt factice de test, dépôt de démonstration.
- L'accueil relaie le dernier encouragement (« X t'encourage ») quand il y en
  a un.
- Demandes d'ami, acceptations et encouragements déclenchent une notification
  push chez la personne concernée (jamais bloquante, jamais sur un refus) —
  voir [notifications.md](notifications.md).

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
  lecture et résolution auditée côté admin, `403` sans `community:moderate`.
- Unitaires API, modération : garde-fous des blocages et signalements,
  doublon ouvert, nettoyage des précisions, cliché du texte signalé (lu et
  écrit dans une même transaction, `null` si le message ne vient pas de la
  personne visée), audit de la résolution, pagination.
- Vitest back-office (`apps/admin/src/app/reports/page.test.tsx`,
  `apps/admin/src/lib/admin-api.test.ts`) : liste des ouverts par défaut
  avec motif, personnes liées à leur fiche et texte visé (message vivant,
  cliché d'un message retiré depuis, signalement visant la personne) ;
  résolution puis rechargement ; réouverture ; filtres Résolus/Tous ; pagination par
  curseur ; 403 distingué d'une panne, à la lecture comme à la résolution ;
  redirection sans jeton ; URL, corps du PATCH et rejet d'une réponse hors
  contrat côté transport.
- Défis du mois : catalogue (fenêtre UTC, passage d'année, slugs uniques,
  textes visibles sans tiret cadratin), service (création AVANT la liste sur
  un mois vierge, rien sur un mois servi) ; e2e : cinq lectures concurrentes
  d'un mois vierge produisent un seul jeu, une lecture de plus ne recrée rien.
- Widgets mobile (`test/features/community/`) : démo complète, états
  erreur/vide/chargement, acceptation de demande, ajout opaque, réglage de
  partage, défis présents sans ami (invitation dans la section « Amis »,
  pas d'état vide global, la feuille d'ajout s'ouvre ; une demande reçue
  suffit à retirer l'invitation) ; gestes de protection (`community_moderation_test.dart`) : retrait
  d'un ami (confirmation, annulation sans effet, échec hors ligne annoncé et
  ami conservé, cible tactile), blocage (la personne quitte amis et fil,
  rejoint « Personnes bloquées », retour non accusateur), déblocage (ligne
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
