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

## Modèle de données (Prisma)

| Table | Rôle |
| --- | --- |
| `Friendship` | UNE ligne par paire ; `PENDING` → `ACCEPTED`/`DECLINED`, direction conservée (qui a demandé). La symétrie est imposée par le service. |
| `Encouragement` | Mot d'un ami ; le nom de l'expéditeur est lu au moment de servir (nom COURANT, pas dénormalisé). |
| `CommunityChallenge` | Défi collectif créé par l'équipe (seed puis admin), `SPORT` ou `CULTURE`, avec `target` et fenêtre `startsAt`/`endsAt`. |
| `ChallengeParticipation` | Participation + `contribution` individuelle à l'objectif. |
| `CommunityPreference` | `sharesProgress` (absence = partagé, défaut du modèle). |

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
| GET | `/challenges` | Défis ouverts, progression collective incluse |
| POST | `/challenges/:id/join` | Rejoindre (idempotent) |
| DELETE | `/challenges/:id/join` | Quitter (idempotent) |
| GET · PATCH | `/profile` | Ma préférence `sharesProgress` + mon `friendCode` |

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
- **Statistiques partagées** : `weeklySessions` = séances TERMINÉES sur 7
  jours glissants ; `streakDays` = jours calendaires consécutifs avec séance,
  découpés dans le FUSEAU du propriétaire (`UserProfile.timezone`), série
  d'hier non brisée tant que la journée en cours n'est pas finie
  (`streak.calculator.ts`, testé fuseau par fuseau).

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
- La feuille « Ajouter un ami » s'ouvre sur le navigateur RACINE : ouverte
  depuis un onglet, elle passerait sinon sous la bottom bar flottante.
- Elle montre MON code (QR sur aplat blanc — un lecteur veut du contraste,
  pas de l'ambiance) et un champ UNIQUE : l'arobase départage une adresse
  d'un code. Le scan (`mobile_scanner`) vit dans son propre écran — seul
  endroit de la fonctionnalité à toucher du natif : une caméra refusée
  n'enlève que le scan, et l'écran le dit avec un état d'erreur du design
  system. Un e-mail est confirmé opaque ; un code, par le prénom — ou
  « Ce code ne mène à personne ».
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
  code, reprise de contact par la personne qui a refusé, `429` au-delà de
  10 demandes par minute sans toucher les autres routes.
- Widgets mobile (`test/features/community/`) : démo complète, états
  erreur/vide/chargement, acceptation de demande, ajout opaque, réglage de
  partage.
- Code ami : normalisation éprouvée des DEUX côtés (spec Jest et test Dart
  miroirs — formes affichée/minuscule/QR, refus des caractères ambigus) ;
  service (silence sur code inconnu ou soi-même, aperçu 404) ; e2e du tour
  complet profil → aperçu → demande → amis ; feuille d'ajout (QR affiché,
  champ unique, saisie invalide retenue au bord).
