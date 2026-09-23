# Profil

Le profil répond à une question : **où en suis-je, depuis le début ?** Il
s'ouvre en plein écran depuis l'avatar de l'accueil. Refondu le
23 septembre 2026 d'après la maquette validée par le produit (thème violet,
retour « trop chargé »).

## Le profil raconte, les réglages règlent

L'ancien profil empilait douze groupes de réglages sous l'identité. Ce qu'on
vient **voir** (son parcours) se noyait dans ce qu'on vient **changer** une
fois par trimestre. Ils sont désormais séparés :

| Écran | Route | Contenu |
| ----- | ----- | ------- |
| Mon profil | `/profile` | Identité, trois chiffres, objectif, programme, portes vers statistiques, badges, amis, nouveau programme |
| Réglages | `/profile/reglages` | Tout ce qui se règle : abonnement, identité Carlys, Mentor, entraînement, nutrition, application, notifications, compte, légal, déconnexion |

On passe de l'un à l'autre par le **rouage** en tête du profil. Rien n'a été
retiré des réglages : chaque groupe est celui d'avant, dans le même ordre.

## Ce que chaque carte montre, et d'où elle le tient

Aucun chiffre n'est recalculé par le profil : il **présente** ce que d'autres
écrans comptent déjà (règle du « fait déjà compté », [progression.md](progression.md)).

| Carte | Donnée | Source | Ouvre |
| ----- | ------ | ------ | ----- |
| Identité | Initiale, nom | `AuthUser` | Profils Carlys |
| | « Membre depuis mars 2024 » | `AuthUser.createdAt` (servi par l'API depuis toujours ; le DTO mobile le jetait) | |
| | La phrase entre guillemets | Le profil Carlys choisi (`carlysProfileContentOf(…).quote`) | |
| | Jours consécutifs | Série de constance, **locale** — la même que l'accueil | |
| | Séances effectuées | `GET /progress/lifetime`, **depuis toujours** | |
| | Amis | `GET /community/friends` | |
| Mon objectif | L'objectif choisi | `AuthUser.trainingGoal` | Feuille d'objectif |
| | La jauge | Position dans le **programme suivi** (voir plus bas) | |
| Mon programme | Nom, rythme, durée | Programme actif (`GET /programs` puis son détail) | Fiche du programme, ou la liste |
| Mes statistiques | — | — | Onglet Progrès |
| Mes badges | Nombre de badges | Journal des récompenses, famille « badge » seule | Profil de progression |
| Mes amis | Nombre d'amis | `GET /community/friends` | Onglet Communauté |
| Toujours plus loin | — | — | Préparation d'un programme |

**Pourquoi les séances viennent du serveur.** L'historique local est plafonné
à 60 séances au rapatriement : un téléphone neuf afficherait « 60 » sur un
compte qui en a 200. C'est la même raison qui a fait passer les compteurs de
récompense au serveur (Plan 8.4).

**Pourquoi « badges » ne compte que les badges.** La ligne dit « 3 badges » ;
y compter les médailles et les certificats la ferait mentir sur ce qu'elle
nomme. La vitrine complète vit dans le profil de progression.

## La jauge de l'objectif nomme sa base

Elle dit la **position dans le programme suivi**, en jours civils depuis son
premier jour — jamais une note de la personne. Elle suit donc la règle du
pourcentage ([progression.md](progression.md), test de l'unité) :

- l'unité du plan d'abord : « Semaine 2 sur 8 » ;
- puis le pourcentage, qui **nomme sa base** : « 24 % » au-dessus de
  « du programme ».

Le jour en cours ne compte pas encore : le premier jour vaut 0 %, le
lendemain du dernier 100 %, et la veille de la fin n'est jamais « 100 % »
(le pourcentage est tronqué, pas arrondi). Avant le départ, la ligne dit
« Commence dans 5 jours ». La règle vit dans
`workout_program/domain/program_advancement.dart`, éprouvée jour par jour.

**Sans programme daté, pas de jauge.** Une barre vide se lirait comme un
retard ; la carte se contente alors de l'objectif.

## Le rythme d'un programme

« 4 séances par semaine · 8 semaines » quand toutes les semaines portent
autant de séances ; le **total** sinon (« 30 séances · 8 semaines »). Une
moyenne (« 3,5 séances par semaine ») décrirait une semaine qui n'existe dans
aucun plan. Un repos n'est pas une séance ; une activité libre (« Course »)
en est une.

## Aucun mensonge par omission

Chaque donnée serveur a trois états, et aucun ne se confond avec un autre :

| État | Chiffre de l'identité | Ligne d'une carte |
| ---- | --------------------- | ----------------- |
| En route | « — » | rien sous le titre |
| Échec | « — » | « Hors connexion », ou « Indisponible pour l'instant » |
| Servi, zéro | « 0 » | une invitation (« Ton premier badge t'attend ») |

« Aucun programme suivi » affiché hors ligne serait faux : c'est exactement
ce que l'ancien `valueOrNull` aurait dit. Un geste « tirer pour rafraîchir »
relit les trois sources serveur — nécessaire, car les compteurs de vie
entière ne sont pas auto-disposés (les récompenses en dépendent).

## L'illustration de « Toujours plus loin »

Le sommet au fanion, sous une lune violette, fourni par le produit le
23 septembre 2026 (`assets/illustrations/sommet.webp`). Il remplace un
paysage peint à la main qui tenait la place en attendant l'image.

- **Fondue par la gauche, comme sur la maquette.** L'image occupe les 62 %
  droits de la bannière ; son tiers gauche passe de transparent à plein.
  Le fondu agit sur l'ALPHA de l'image (`ShaderMask`, `BlendMode.dstIn`),
  pas par un voile posé dessus : c'est le fond de la carte qui apparaît, et
  aucune teinte nouvelle n'entre dans l'écran. Même technique que la
  photographie de la page de bienvenue.
- **Le texte reste lisible, et c'est mesuré.** Contraste le plus faible sur
  le fond réel, reconstitué à partir de l'image, de son cadrage et du
  fondu : titre 16,2:1, sous-titre 5,97:1, chevron 5,94:1 (seuil AA 4,5:1).
  La lune commence là où le fondu est déjà plein : elle se lit entière,
  à droite du texte.
- **19 Ko, pas 1,7 Mo.** Le PNG fourni est converti en WebP 1280 × 720,
  qualité 92 (écart moyen de 0,76 sur 255 par pixel) : 1280 points couvrent
  la bannière d'une tablette en densité 2. Un test plafonne le fichier à
  64 Ko — de la marge pour une retouche, pas pour le retour du PNG.
- **Muette pour le lecteur d'écran.** C'est un décor : la porte s'annonce
  par son texte. Une image manquante laisse la carte nue et se dit dans les
  journaux.

## Écarts à la maquette, tous délibérés

- **« Mes contenus sauvegardés » est absent.** Aucune sauvegarde de contenu
  n'existe dans le domaine ; une ligne qui ne mène nulle part mentirait.
- **« Bronze » est retiré de « Mes badges ».** Une ligue ne se reporte
  jamais dans le profil (test de la date de fin, [progression.md](progression.md)).
- **La jauge nomme sa base** sous son pourcentage.
- **Pas de barre d'onglets, une flèche de retour.** Le profil s'ouvre en
  plein écran depuis l'avatar ; la flèche vit au-dessus du titre, la ligne
  mono étant trop longue pour tenir entre deux boutons.
- **Le libellé des trois chiffres passe sous l'icône.** À sa droite, il
  disposait d'une soixantaine de points sur un écran de 393 : « consécutifs »
  perdait sa dernière lettre.
- **« Garde l'élan »** plutôt que « Reste motivé » : la copie ne présume pas
  du genre de la personne.
- **Deux touches d'orange** — la flamme de la série et le trophée des
  badges — là où l'accueil n'en admet qu'une. Ce sont des points, jamais des
  surfaces, et la maquette les pose ainsi.
- **Gouttière de 16** (et non 22 comme l'accueil) : la maquette est dense en
  largeur, et les trois chiffres n'y tiendraient pas autrement.

## Découpage

| Fichier | Rôle |
| ------- | ---- |
| `presentation/screens/profile_screen.dart` | L'ordre des cartes, et rien d'autre |
| `presentation/screens/profile_settings_screen.dart` | Les réglages, groupe par groupe |
| `presentation/providers/profile_hub_providers.dart` | Les chiffres, chacun à sa source, en `AsyncValue` |
| `presentation/widgets/profile_hub_wording.dart` | Les phrases, en fonctions pures |
| `presentation/widgets/profile_hub_tile.dart` | La carte, la ligne, le disque d'icône |
| `presentation/widgets/profile_identity_card.dart` · `profile_stats_row.dart` | L'identité et ses trois chiffres |
| `presentation/widgets/profile_objective_card.dart` · `profile_program_card.dart` | L'objectif et sa jauge, le programme |
| `presentation/widgets/profile_further_banner.dart` · `further_banner_illustration.dart` | « Toujours plus loin » et son illustration fondue |
| `workout_program/domain/program_advancement.dart` | Avancement et rythme d'un programme, purs |
| `core/utilities/civil_days.dart` | Le compte en jours civils, partagé avec la maxime du jour |

Captures : `13-profil`, `13a-profil-bas` (la bannière et son illustration), `13b-profil-reglages`.
