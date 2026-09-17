# Le Mentor Carlys

Le personnage-guide de l'application. « Mentor Carlys » est son nom
PROVISOIRE, accepté par la feuille de route ; le changer un jour ne
changera que des libellés, jamais des identifiants.

Le Mentor n'est pas un écran : c'est une VOIX et une présence.

- Sa voix teinte le coach IA, côté serveur, à chaque tour.
- Son mot paraît sur l'accueil (section « Pour toi »), à sa voix.
- Il fait visiter l'application, une pièce à la fois.
- Il fête un cap franchi, à sa voix, une seule fois.

## Les deux axes : profil et style, composés, jamais croisés

Le profil Carlys décrit LA PERSONNE (ce qu'il faut privilégier) ; le style
du Mentor décrit LA VOIX (comment le dire). Quatre styles : Bienveillant,
Exigeant, Athlète, Philosophe.

Côté serveur, `mentorVoiceBriefing` (coach.prompt.ts) COMPOSE les deux
briefings purs — `carlysProfileBriefing` + `mentorStyleBriefing` — joints
par une ligne vide : 4 + 4 textes, jamais 16 croisements, sinon chaque
correction se recopierait quatre fois. Les règles des briefings sont
verrouillées par `coach.prompt.spec.ts` : moins de 400 caractères, AUCUN
chiffre (les chiffres viennent des outils), aucun tiret long, aucun nom de
style dans le préfixe partagé (le cache du prompt se fragmenterait en
quatre), chaîne vide quand rien n'est choisi — jamais une voix devinée.

## La persistance : le même chemin que le profil Carlys

`UserProfile.mentorStyle` (enum `MentorStyle`, nullable, migration
`20260917175451_mentor_style`) → `PATCH /users/me` (DTO `@IsEnum`, contrat
`mentorStyleSchema`) → `presentUser` → `AuthUser.mentorStyle` → mobile
`MentorStyle.fromWire`, qui rend `null` pour toute valeur inconnue : un
serveur plus récent n'a pas le droit de faire planter un ancien client.

Le choix se fait dans le profil (groupe « Mentor Carlys » → « Sa voix »),
par une feuille à quatre options. Chaque carte porte l'image de sa voix et
un mot d'exemple tiré de son catalogue (`mentorWordCatalog`) : on ENTEND la
voix avant de la choisir. Écrit au serveur PUIS relu depuis
`AuthUser` : une seule source de vérité, un échec s'affiche sans état faux.

## Le mot du Mentor (accueil)

Une phrase dans « Pour toi », à la voix choisie (voix neutre tant que rien
n'est choisi). Toucher l'entrée ouvre la feuille du Mentor, qui s'ouvre sur
son bandeau de signature (`mentor_bandeau.dart`) : l'identité et le mot du
moment posés sur le dégradé de la marque — la même grammaire que les
bannières de franchissement. `mentorWord` est une fonction PURE : style + fréquence +
jour civil → le mot, en rotation DÉTERMINISTE par période — au cran
quotidien il change chaque jour, au cran hebdomadaire il tient la semaine.
Aucune date stockée, donc rien à désynchroniser : la même grammaire que la
question du jour.

Les préférences d'intervention (activées ou non, fréquence) sont LOCALES à
l'appareil (`mentor_prefs_store.dart`) : elles règlent quand le Mentor
parle ICI, comme le thème. Défauts : actives, au cran discret
(hebdomadaire) — même règle que les notifications, « jamais réglé vaut
accepté ».

## La visite guidée

Sept étapes (`mentor_tour.dart`) : accueil, entraînement, nutrition,
progrès, Academy, communauté, coach. Un manifeste constant, un état « déjà
vu » local, et RIEN de verrouillé — la même doctrine que le Parcours de
l'Academy. La feuille montre UNE étape à la fois, au-dessus du chemin des
sept pastilles (`mentor_tour_chemin.dart` — vue, courante, à venir ; chaque
étape porte l'icône de sa pièce, table `mentorTourIcons` gardée par le même
test que les routes) : « Aller voir » est
l'ancrage réel (marque vue, ferme, navigue), « Étape suivante » avance sur
place. La visite se rejoue depuis les réglages du Mentor, à volonté.

Le domaine ne connaît AUCUNE route : la table étape → destination vit dans
la présentation (`mentorTourRoutes`), et un test interdit l'étape sans
destination comme la destination orpheline.

## Les célébrations, au franchissement

Quand une récompense vient d'être gagnée, le mot du Mentor devient sa
célébration, à sa voix. Trois gardes, toutes héritées de règles écrites :

- **`EarnedReward.isNew` uniquement** : vrai seulement dans la session du
  franchissement, APRÈS la garde de première lecture du journal — sur un
  appareil neuf, quinze médailles s'inscrivent en silence et le Mentor se
  tait.
- **Dite une fois** : toucher l'entrée marque la récompense « dite »
  (`mentor.celebrations.dites`) et le mot ordinaire reprend la main. Le
  journal des récompenses garde la trace durable ; le Mentor ne garde que
  ce qu'il a déjà dit.
- **Jamais un second score** : le Mentor relaie une récompense existante,
  il n'en crée aucune et ne compte rien (règle de non-concurrence,
  `progression.md`).

## Couverture

- `coach.prompt.spec.ts` : les quatre briefings de style (distincts, sans
  chiffre, sans cadratin), la composition profil + style (les deux, un
  seul, rien), le préfixe partagé sans nom de style.
- `auth.e2e-spec.ts` / `coach.e2e-spec.ts` : PATCH `mentorStyle` (axe
  indépendant, valeur inconnue refusée), le tour du coach qui contient les
  DEUX briefings avec un préfixe intact octet pour octet.
- `mentor_word_test.dart` : mots par voix tous distincts, rotation
  quotidienne/hebdomadaire, célébration par voix, voix neutre sans choix.
- `mentor_tour_test.dart` : manifeste intègre, ordre, étape sautée,
  identifiant retiré ignoré, table des routes complète (tué par mutation
  sur l'ordre).
- `mentor_prefs_test.dart` : défauts sûrs, idempotence, remise à zéro.
- `mentor_providers_test.dart` : interventions coupées = silence (tué par
  mutation), célébration dite une fois, première lecture muette.
- `home_screen_test.dart` : le mot dans « Pour toi », la feuille du
  Mentor, la visite qui s'ouvre et avance.
