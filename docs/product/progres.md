# Écran Progrès — statistiques, records, mesures corporelles

À ne pas confondre avec le **profil de progression** ([progression.md](progression.md)),
qui résume la pratique en cinq axes et un titre. La distinction existe dans le
code depuis le début : `features/progress` sert les FAITS mesurés (volume,
records, pesées) ; `features/progression` en tire un score.

Cible mobile : `apps/mobile/lib/features/progress/`
API : `apps/api/src/modules/progress/`

## Un record est une LECTURE de l'historique, plus un état à maintenir

Les records se calculaient en maximum incrémental : à la clôture, on
comparait les séries de la séance aux records stockés et on ne gardait que ce
qui montait. Deux défauts en découlaient, et la docstring promettait de
réparer le premier sans le faire.

**Un échec d'écriture perdait le record pour toujours.** `updateRecordsForSession`
attrape toute erreur et journalise « rattrapage à la prochaine séance ». Mais
la séance suivante ne voyait que SES propres séries : un 100 kg perdu laissait
un 80 kg ultérieur devenir le record, puisque plus aucune ligne stockée ne s'y
opposait. La promesse était fausse, et elle masquait une perte de donnée.

**Un record ne descendait jamais.** Une charge saisie 100 au lieu de 10 posait
un record faux, définitif, qui polluait aussi les statistiques et la courbe
par exercice. `PATCH /api/v1/workout-sets/{id}` existait pourtant, validé et
testé — il ne réparait simplement rien, puisque les records ne se recalculent
qu'à la clôture.

`recomputeRecords(userId, exerciseNames)` remplace les deux : les records de
ces exercices deviennent ÉGAUX à ce que dit l'historique, un record que plus
aucune série ne porte est supprimé, et le record cesse d'être un état à
maintenir pour devenir une fonction des séries stockées. Trois conséquences :

- toute écriture qui change ces séries n'a plus qu'à rappeler la méthode. Elle
  est donc branchée sur `PATCH` et `DELETE` d'une série, **uniquement quand la
  séance est TERMINÉE** : rien à faire tant qu'elle est en cours, aucun record
  n'a encore été écrit pour elle, et recalculer à chaque série validée
  mettrait une lecture d'historique sur le chemin le plus chaud de l'app ;
- le record est attribué à la séance où la performance a RÉELLEMENT eu lieu.
  `RecordCandidate` porte désormais son `sessionId` au lieu de le recevoir de
  l'appelant : avec un recalcul sur l'historique, le meilleur candidat peut
  venir d'une séance d'il y a six mois ;
- la lecture est bornée à l'historique de la personne (`WorkoutSession(userId,
  startedAt)` puis `WorkoutSet(sessionId, position)`, deux index qui
  existent), et une séance ABANDONNÉE n'y entre pas — un test e2e l'exige.

### Le geste qui manquait : corriger une série d'une séance terminée

Le serveur savait corriger, l'application ne le demandait jamais. `PATCH
/api/v1/workout-sets/{id}` était livré, validé et testé, et le manifeste
routes ↔ clients le notait « aucun » depuis le 7 septembre. Une séance
terminée était donc définitivement figée : aucun écran n'offrait de corriger
une série ni d'en supprimer une, la suppression n'existant que PENDANT la
séance. L'incohérence sautait aux yeux depuis que les mesures corporelles sont
redevenues corrigeables : une PESÉE se corrigeait, une SÉRIE non.

- La ligne ENTIÈRE ouvre la correction, l'appui long supprime. Poser un bouton
  d'édition à côté des chiffres créerait deux cibles concurrentes pour une
  seule intention, exactement ce que la règle des portes d'explication a déjà
  tranché ailleurs.
- La feuille s'ouvre PRÉ-REMPLIE, et ne renvoie que ce qui a bougé : un champ
  inchangé ne part pas au serveur.
- Les deux gestes DISENT leur conséquence avant de l'appliquer — « tes records
  et tes statistiques seront recalculés » — parce que personne ne devine qu'un
  record peut descendre.
- La correction passe par `set.update` dans la file de synchronisation, donc
  elle aboutit hors ligne. Elle ne passe PAS par un réenregistrement de la
  série : l'ajout est un upsert idempotent par identifiant, donc rejoué avec
  le même UUID il rend la série existante SANS la modifier.
- Une série supprimée ne se corrige plus, et rien n'est mis en file : un PATCH
  voué au 404 n'a rien à faire dans une file qui ne rejoue jamais
  indéfiniment un refus définitif.

## Mesures corporelles : tout est corrigeable

`PATCH` et `DELETE /api/v1/body-metrics/:id` existent, sont testés, et
appliquent une suppression logique idempotente. Côté mobile, la page ne
listait pourtant que les **trois dernières** mesures : une pesée d'il y a
deux semaines était enregistrée, tracée dans la courbe, et impossible à
corriger ou à supprimer. L'API savait faire, l'application ne demandait pas.

- La page garde ses trois lignes récentes : c'est une mise en page, plus une
  limite. Sous elles, « Voir mes N mesures » ouvre
  `body_weight_history_sheet.dart`, qui liste **tout** et rend chaque ligne
  corrigeable et supprimable.
- La feuille LIT le provider plutôt qu'une liste figée : corriger depuis la
  feuille se voit dans la feuille, sans la refermer.
- `WeightRow` est partagée entre la page et la feuille. Les recopier aurait
  fait diverger la confirmation de suppression, c'est-à-dire exactement ce
  qu'il ne faut pas voir diverger.

### La suppression demande confirmation, la correction non

La correction prévient par construction : on y voit la valeur qu'on remplace.
La suppression, elle, partait d'un seul tapotement, sans un mot et sans
retour possible — alors que supprimer la mesure la plus récente **déplace le
rapport métabolique** : métabolisme de base, cible calorique et macros sont
recalculés sur la pesée précédente. La boîte de dialogue dit cette
conséquence, et pas seulement le geste ; elle dit autre chose quand la mesure
n'est pas la dernière, parce que la conséquence n'est alors pas la même.

## Courbe par exercice

`GET /progress/exercises/:id` était écrite, testée, et **sans aucun client
depuis septembre 2026** : le serveur savait répondre, personne ne demandait.
L'écran de Progrès ne montrait que le volume agrégé par période, où la
progression d'un mouvement donné se noie dans celle de tous les autres.

- **Entrée** : une ligne de record ouvre la progression de son exercice.
  C'est la question qui vient juste après avoir lu un record. Un record sans
  `exerciseId` (exercice retiré du catalogue) reste une ligne muette plutôt
  qu'un bouton qui mènerait à une erreur.
- **Route** : `/progress/exercises/:exerciseId`, poussée sur le navigateur
  racine depuis la branche Progrès.
- **Les records sont MARQUÉS SUR le tracé**, pas listés à côté : la
  spécification dit « une courbe performances + records », un seul objet. Le
  rapprochement se fait au JOUR civil local entre `record.achievedAt` et
  `point.date`.

### Ce que la courbe refuse de tracer

La réponse serveur sert `maxWeightKg` à `null` quand la séance n'a porté
aucune charge — tractions au poids du corps, cardio. Tracer ces séances à
zéro raconterait une stagnation qui n'existe pas, et une ligne plate à zéro
est un mensonge plus convaincant qu'un graphique vide. L'écran distingue donc
trois cas et les DIT :

| Cas | Ce qui s'affiche |
| --- | --- |
| Aucune séance | État vide, avec la sortie (« termine une séance qui le contient ») |
| Séances sans charge, ni chrono, ni distance | « Pas encore de courbe », et le rappel que le volume compte quand même |
| Une seule séance chiffrée | « La courbe se trace à partir de deux » |

Les séances restent listées dans les trois cas : elles ont bien eu lieu.

### La courbe CARDIO (22 septembre 2026)

Un tapis et un développé couché ne se lisent pas sur la même courbe. La
charge maximale d'une course vaut `null`, et l'écran rendait donc « pas
encore de courbe » à quelqu'un qui courait depuis six mois : il disait
« rien » là où il y avait tout.

`GET /progress/exercises/:id` sert désormais `distanceMeters` et
`durationSeconds` par séance, **SOMMÉS** et non maximisés : trois fractionnés
de 400 m font 1 200 m de course, alors qu'une charge ne s'additionne pas
d'une série à l'autre. Zéro sur un exercice de fonte, ce qui est exact — et
c'est ce zéro qui permet au client de choisir la courbe à tracer.

**Ce qui décide de la courbe, ce sont les FAITS, jamais une étiquette
d'exercice.** Une fiche mal catégorisée n'a alors aucune conséquence, et un
exercice hybride (le rameur chargé, la marche lestée) suit ce qu'on y a
réellement noté :

1. plus de séances cardio que de séances chargées → **courbe cardio** ;
2. sinon, au moins deux séances chargées → **courbe de charge** ;
3. sinon, au moins deux séances cardio → **courbe cardio** (le repli d'un
   exercice qui n'a qu'une seule séance chargée) ;
4. sinon, l'état vide du tableau ci-dessus.

En ordonnée, la **distance** quand elle est notée au moins aussi souvent que
le chrono, le **temps** sinon. La distance l'emporte à égalité parce qu'elle
dit la performance : un coureur qui met le même temps sur plus de kilomètres
progresse, et l'inverse ne se lit pas. L'échelle est en kilomètres ou en
minutes, jamais en mètres ou en secondes — une échelle en secondes écrase la
courbe d'une séance à l'autre.

Les lignes de séance suivent : une séance de course écrit sa distance et son
chrono là où une séance de fonte écrit sa charge et son volume. Elles
affichaient « — » et « 0 kg », c'est-à-dire un échec là où il y avait huit
kilomètres.

Les deux courbes partagent leur CADRE (`progression_chart_frame.dart`) :
carte, tracé, révélation au balayage, trois repères de date pris sur des
séances réelles, énoncé pour le lecteur d'écran. Elles ne diffèrent que par
ce qu'elles tracent, et deux copies auraient divergé par leur sémantique,
c'est-à-dire par la moitié qui ne se voit pas.

## Les récompenses ne dépendent plus de l'appareil (22 septembre 2026)

**Le défaut, mesuré.** Le moteur de récompenses dérivait `completedSessions`,
`bestWeekStreak` et `balancedWeeks` de l'historique LOCAL. Celui-ci est
plafonné à 60 séances au rapatriement
(`WorkoutSessionDownloader.restoredSessionsMax`). Sur un compte à 200
séances, un téléphone neuf en voyait donc 60 : `discipline-150` n'était pas
re-mérité, et comme le journal des récompenses vit dans les préférences de
l'appareil — donc vide sur le neuf — la médaille **disparaissait**. C'est
exactement ce que le journal promet de ne jamais laisser arriver (« une
médaille obtenue le reste »).

**Le partage retenu : le serveur sert les FAITS, le mobile garde la RÈGLE.**
`GET /progress/lifetime` rend le nombre de séances terminées et la liste des
semaines actives avec leur compte — une ligne par semaine où l'on s'est
entraîné, soit une centaine sur deux ans. Ce qu'est une « meilleure série »
ou une « semaine équilibrée » reste décidé par `reward_facts_builder.dart`,
et par lui seul : le calculer aussi en SQL en ferait une seconde
implémentation, et deux copies divergent.

Les semaines sont découpées dans le **fuseau de la personne**, comme les
paniers de `overview` et pour la même raison : une séance du dimanche soir
bascule au lundi en UTC et changerait de semaine. Elles voyagent en jour
civil (`YYYY-MM-DD`), jamais en instant.

**Hors ligne**, la lecture échoue et l'historique local reprend la main.
Sous-compter n'efface rien, puisque le journal ne s'écrit qu'en AJOUT : seul
un appareil neuf ET hors ligne verrait moins, et il n'a de toute façon rien à
montrer.

## La frise — « Ton histoire » (22 septembre 2026)

`GET /progress/timeline` réunit ce qui s'est passé, du plus récent au plus
ancien : séances terminées, pesées, leçons et **franchissements**.

**Ce qui est dérivé, ce qui est matérialisé.** La ligne de partage tient en
une question : *le fait est-il déjà une ligne datée et corrigible ?*

- **Séances, mesures, leçons → DÉRIVÉES à la lecture.** Ce sont déjà trois
  tables datées et indexées. Les recopier dans une table d'événements
  ajouterait un état à maintenir pour zéro gain, et rouvrirait le bug que
  `recomputeRecords` a fermé : une séance corrigée laisserait derrière elle un
  événement qui n'a jamais eu lieu.
- **Franchissements → MATÉRIALISÉS** dans `ProgressMilestone`. Ce sont les
  trois seuls qui ne correspondent à aucune ligne existante :
  `PersonalRecord` ne garde que le maximum COURANT (un 80 kg battu en mars
  par un 85 en avril n'y laisse plus rien — c'est un mur de trophées, pas une
  chronologie) ; la récompense n'existait nulle part côté serveur ; et le
  titre dépend d'un score calculé sur une fenêtre mobile, que rejouer ici
  demanderait de réécrire le moteur Dart en TypeScript.

**Les franchissements de RECORD restent une FONCTION des séries.** Ils se
dérivent à chaque `recomputeRecords` par rejeu du maximum au fil du temps, et
la table est mise à l'ÉGAL de ce que dit l'historique — ce qui n'a plus de
série pour le justifier est retiré. Une charge saisie 300 au lieu de 30 fait
donc disparaître le franchissement qu'elle avait inventé.

**Les récompenses et les titres s'IMPORTENT** (`POST /progress/milestones`),
parce que le moteur qui les décide vit sur l'appareil. Règle : **la plus
ANCIENNE date gagne**, appliquée par un `LEAST` dans l'écriture elle-même. Le
journal local date une récompense du jour où l'application a REGARDÉ, pas du
jour du fait ; deux appareils n'ont pas regardé le même jour, et sans cette
règle le dernier à parler réécrirait l'histoire. Les records, eux, ne
s'importent jamais : les accepter d'un client laisserait inventer un
franchissement qu'aucune série ne justifie.

**Le curseur encode le couple `(occurredAt, id)`**, jamais l'identifiant
seul. Les autres listes paginées du dépôt s'en tirent avec l'id parce qu'une
SEULE table est triée ; un flux fusionné a des ex æquo à la milliseconde, et
un curseur sur l'id sauterait des lignes ou les rejouerait. Un curseur
illisible est traité comme absent — une position n'est pas une autorisation.

**Les en-têtes de mois se posent côté CLIENT.** Découpés côté serveur, une
page vaudrait deux lignes ou deux cents selon le mois ; le serveur pagine par
compte d'éléments, et l'écran ouvre un en-tête quand le mois change, y
compris à cheval sur deux pages.

**Le double comptage, évité nommément** : les leçons se groupent par jour
APRÈS dédoublonnage par leçon (le serveur garde deux réponses d'une même
leçon sur deux jours, là où l'appareil applique « la première gagne ») ; un
record battu ne produit qu'une ligne, celle du record, jamais aussi celle du
badge ; un titre ne produit jamais aussi un `REWARD`.

**Le libellé n'est pas en base.** Le serveur ne stocke que la clé
(`constance-4`) : le libellé est du contenu éditorial, il change avec
l'application, et le figer ferait vieillir les anciennes lignes. Le client le
retrouve dans son catalogue embarqué, et retombe sur un titre générique quand
la clé vient d'une version plus récente.

**Jamais l'historique Drift**, plafonné à 60 séances : une frise tronquée à
soixante séances mentirait sur deux ans de pratique. C'est une lecture
serveur, et elle affiche son erreur hors ligne plutôt qu'un vide. Une page
déjà lue RESTE quand la suivante échoue.

## Hors périmètre, et pourquoi

Un morceau de la tranche « Progression » attend une décision qui n'est pas
technique :

- **Les photos de progression.** `StorageService` est PUBLIC par
  construction (`urlFor` concatène `s3PublicBaseUrl`, `put` pose
  `CacheControl: public, max-age=31536000, immutable`). Stocker des images
  intimes derrière une URL devinable et mise en cache un an n'est pas
  acceptable ; le choix entre URL présignées et relais API est technique, la
  décision de stocker des photos de corps ne l'est pas — elle emporte purge
  RGPD, effacement à la suppression de compte et sauvegardes MinIO. La frise
  les accueillera sans rien changer à sa lecture : un sixième type
  d'événement, et rien d'autre.

## Couverture

- `progress_flow_test.dart` : parcours complet, ajout et suppression d'une
  mesure (avec confirmation ET annulation, prouvée par le compteur de
  suppressions du double), et la liste complète qui rend corrigeable une
  mesure que la page ne montrait pas.
- `exercise_progression_test.dart` : la route est réellement interrogée, la
  courbe se trace, un record du bon jour marque son point et un record d'un
  autre jour n'en marque aucun, les trois cas sans courbe, et l'état
  d'erreur avec son réessai.
