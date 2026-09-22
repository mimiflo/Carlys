# Objectif d'entraînement (Plan 4)

## Deux axes, deux questions

L'objectif d'ENTRAÎNEMENT (`TrainingGoal`) dit **pourquoi on s'entraîne** ;
l'objectif nutritionnel (`NutritionGoal`) dit **ce que l'assiette vise**.
Viser un marathon en recomposition corporelle est parfaitement cohérent :
les deux questions se posent séparément (onboarding, étapes 2 et 3) et
s'écrivent séparément — poser l'une n'écrit jamais l'autre, et aucun des
deux ne se déduit de l'autre. Le e2e `auth.e2e-spec.ts` épingle cette
indépendance.

## Les huit objectifs

Perte de gras, Prise de muscle, Recomposition, Hyrox, Marathon, Maintien,
Force, Callisthénie — enum `TrainingGoal` (Prisma, contrat
`trainingGoalSchema`, entité Dart). Les wires ne recoupent JAMAIS ceux de
`NutritionGoal` (`MAINTENANCE` côté entraînement, `MAINTAIN` côté
nutrition) : un wire partagé inviterait à confondre les colonnes — un test
l'interdit.

L'enum est EXTENSIBLE : côté mobile, `TrainingGoal.fromWire` rend `null`
pour toute valeur inconnue — un serveur plus récent n'a pas le droit de
faire planter un ancien client, et jamais un objectif n'est deviné.

## Où il vit, où il se choisit

- **Serveur** : `UserProfile.trainingGoal` (nullable, migration
  `20260917190658_training_goal`), écrit par `PATCH /users/me`, servi dans
  `AuthUser.trainingGoal` — le même chemin que l'identité Carlys et la voix
  du Mentor : une seule source de vérité, choisir écrit PUIS relit.
- **Onboarding** : étape 2 (« Ton entraînement »), juste après l'identité —
  le POURQUOI des séances avant le plan nutrition. Répondu sans compte, il
  attend localement (`OnboardingAnswers`) et part par son endpoint dès
  qu'une session s'ouvre, comme l'identité.
- **Profil** : groupe « Entraînement » → « Mon objectif », feuille à huit
  cartes (image, nom, ce que l'objectif vise, sélection marquée) —
  `training_goal_sheet.dart`, modifiable à tout moment.

## Les entrées de génération (tranche 2)

Quatre entrées, toutes FACULTATIVES — la génération listera ce qui manque,
elle n'inventera rien :

- **Expérience** (`TrainingExperience` : débutant, intermédiaire, avancé) —
  un NIVEAU assumé, contrairement au profil Carlys qui est une identité.
- **Séances par semaine** et **durée d'une séance** — bornes au contrat
  (`TRAINING_WEEKLY_SESSIONS_*`, `TRAINING_SESSION_MINUTES_*`), l'écran
  propose des presets, le contrat accepte plus large.
- **Matériel** (`UserEquipment`) — des SLUGS de la taxonomie `Equipment`
  du catalogue, la même que le filtre d'exercices et le coach ; un slug
  inconnu est refusé en 400 en le nommant, jamais ignoré (une liste
  silencieusement amputée générerait un programme pour un matériel
  absent). Écriture par remplacement complet, transactionnelle avec les
  scalaires du même `PATCH`.

Écriture : `PATCH /users/me` (le guichet unique du profil). Lecture :
`GET /users/me/training` — l'état complet des entrées, objectif compris.
Sur mobile : écran « Préparer mon programme » (profil → Entraînement,
route `/programs/preparation`), chaque geste écrit SON champ puis relit —
l'écran reflète toujours l'état serveur.

## La génération (tranche 3)

`PUT /api/v1/programs/{id}/generate` — identifiant fourni par l'appareil,
comme tout le domaine. AUCUNE entrée de profil dans le corps : elles ont
déjà leur guichet, en accepter une copie ouvrirait une seconde source
donc une divergence. Seul `name` est accepté, et il est facultatif.

**Le moteur est une fonction PURE** (`programs/domain/generation/`) :
aucune base, aucun réseau, aucune horloge, aucun hasard. C'est ce qui rend
la tranche *auditable* au sens de la feuille de route — rejouer le calcul
explique un programme écrit il y a trois mois. La variété entre semaines
et entre créneaux vient d'un décalage modulaire calculé sur une graine
(identifiant du programme + profil + matériel trié), jamais d'un tirage.
Un test-garde interdit `Math.random`, `Date.now`, `new Date`,
`randomUUID` et `process.env` dans tout le dossier.

Les dosages vivent dans **une table par objectif** (`goal-rules.ts`), et
chaque ligne porte son `rationale` en français : sans lui, le prochain
développeur modifierait un 4 × 8 à 120 s sans savoir s'il avait une
raison. Huit contraintes dures (fréquence, récupération, temps, matériel,
difficulté, droits, volume, unicité) sont relues par `verify()` — la MÊME
fonction que le générateur appelle en dernière phase et que le test
rejoue sur les 8 232 combinaisons d'entrées.

Ce que le générateur ne fait JAMAIS : prescrire une charge (le serveur ne
sait pas ce que la personne soulève), écrire un exercice sans lien au
catalogue, dépasser le plafond de difficulté du niveau, ou remplir un
créneau avec un étirement. Et il n'invente aucune entrée manquante : un
profil incomplet rend un 400 qui liste TOUS les champs d'un coup.

**Le rapport de génération** (`Program.generationReport`, migration
`20260919163304_generation_de_programme`) est écrit une fois et rendu
avec le programme. Il porte le découpage retenu, le volume hebdomadaire
par groupe face à sa cible, les groupes qu'aucun exercice jouable ne
couvre, et chaque assouplissement consenti avec ses deux nombres. Sans
cette colonne, un support qui ouvre un programme trois semaines plus tard
ne pourrait plus expliquer pourquoi tel exercice y figure : il faudrait
régénérer, et le profil aura bougé — c'est justement la première chose
qu'on change quand un programme déçoit.

**Deux arbitrages qui se voient** :

- Le programme naît **inactif**. L'activer désactiverait le plan en cours
  dans la même transaction (invariant « un seul actif ») : quelqu'un qui
  voulait seulement voir à quoi ressemblerait une génération y perdrait
  son programme. L'activation reste le `PUT /programs/{id}` existant.
- **Rejouer le même identifiant rend le programme tel quel**, sans
  régénérer. Un renvoi après coupure ne crée donc pas un second programme
  et ne consomme pas le plafond du plan gratuit, et les retouches de la
  personne ne sont jamais écrasées. « Régénérer » côté mobile, c'est
  envoyer un NOUVEL identifiant — et comme la graine en dépend, le
  programme obtenu est différent.

**MARATHON et HYROX** passent par des jours à intitulé libre
(`ProgramDay.label`, `templateId` nul). Le catalogue ne contient aucun
mouvement de course, de rameur ni de traîneau, et `WorkoutTemplateSet`
n'a ni durée ni distance : inventer ces exercices leur ferait porter des
répétitions qui n'ont aucun sens et empoisonnerait `PersonalRecord`.
L'ordre correct est la migration des cibles temps/distance d'abord. En
attendant, le rapport DIT combien de jours ne produiront aucune donnée
dans l'application — trois quarts des jours actifs d'un plan marathon.

Les modèles engendrés portent `WorkoutTemplate.generatedFromProgramId` :
une génération dépose plusieurs dizaines de séances, et sans cette
colonne la bibliothèque de la personne se noierait sous des modèles
qu'elle n'a pas composés.

## Le calendrier se corrige (tranche 5)

Le calendrier daté DÉDUIT tout : « fait » découle du lien séance → case,
« manqué » de la date dans le fuseau de la personne. Rien n'est stocké, donc
rien ne peut mentir après coup. Mais cette déduction avait un angle mort,
et il était livré : **une séance lancée hors du calendrier ne portait
l'identifiant d'aucune case.** Elle était bel et bien faite, elle apparaissait
au journal, elle comptait pour la série de constance — et sa case restait
rouge. Le calendrier accusait d'un manquement quelqu'un qui s'était entraîné,
sans le moindre recours.

`PUT /programs/{id}/calendar/days/{dayId}/session` répare ce cas, et lui seul.

**Le JOUR CIVIL est la seule règle.** Une séance n'honore une case que si elle
a eu lieu CE JOUR-LÀ, dans le fuseau de la personne. Sans cette borne,
« marquer comme fait » deviendrait « cocher », et le calendrier ne mesurerait
plus rien. Celui qui a déplacé sa séance d'un jour n'a pas besoin de ce
geste-ci : il a besoin de déplacer sa CASE, ce que l'enregistrement complet du
programme sait déjà faire — les identifiants de jour sont stables d'une
écriture à l'autre, donc la case emporte son lien avec elle.

Trois refus NOMMÉS, chacun pour sa raison :

| Refus | Pourquoi |
| ----- | -------- |
| Séance d'un autre jour (400) | cocher n'est pas déplacer ; le message donne les deux dates |
| Jour de repos (400) | `rest` l'emporte sur `done` à la lecture : la reconnaissance y serait invisible |
| Case, séance ou programme d'autrui (404) | introuvable, jamais « interdit » — un refus qui distingue dirait que la chose existe |

La reconnaissance est **exclusive et transactionnelle** : lier une séance à une
case délie d'abord celle qui l'occupait. Sans cette exclusivité, deux séances
honoreraient la même case, la lecture n'en montrerait qu'une, et « délier » ne
saurait plus laquelle viser. `null` détache, et rejouer le même corps redonne
le même état — c'est ce qui en fait un PUT.

Côté mobile, la case ouvre désormais une **feuille** au lieu de lancer
directement : elle dit son état en toutes lettres, puis propose ce que cet
état autorise. Elle ne propose que du VRAI — les séances terminées de ce jour
civil, et seulement celles que le serveur connaît déjà. Une séance encore en
file de synchronisation n'est pas offerte, et la feuille le dit plutôt que de
se taire : se taire laisserait croire qu'elle n'a pas eu lieu.

## Déplacer une case

La feuille d'une case offre les **sept jours de sa semaine**, celui d'origine
marqué et inerte. Taper un autre jour déplace la case, et si ce jour est déjà
pris, **les deux s'échangent** : écraser ferait disparaître une séance prévue
sans le dire, et refuser obligerait à vider le jour d'arrivée d'abord — deux
gestes pour intervertir un mardi et un jeudi, ce que personne ne fait.

Le déplacement reste **dans la semaine**. Le calendrier en montre une à la
fois : déplacer au-delà serait déplacer vers quelque chose qu'on ne voit pas.
Changer de semaine reste une modification du programme, qui a sa propre porte.

**Une case DÉJÀ honorée ne se déplace pas**, et c'est la règle la moins
évidente. Son identifiant porte le lien avec la séance qui l'a honorée ;
l'emmener ailleurs ferait dire au calendrier qu'on s'est entraîné un jour où
on ne s'est pas entraîné. Le geste qui a du sens là est de détacher. Une case
d'avant le départ ne se déplace pas non plus : elle n'a jamais été promise.

Aucune route nouvelle : le PUT complet du programme suffit, puisque les
identifiants de jour sont stables d'une écriture à l'autre — la case emporte
son lien avec elle. **Une seule lecture et une seule écriture**, quoi qu'il
arrive : un échange fait en deux enregistrements laisserait, entre les deux,
un programme où la même séance occupe deux jours, ou aucun. La règle vit dans
`program_day_move.dart`, éprouvée sans réseau.

Le message de la feuille le disait avant de le faire — « c'est la case qu'il
faut déplacer », à côté d'un geste qui n'existait pas. Une phrase qui renvoie
à une action absente est pire qu'un silence : elle fait chercher.
