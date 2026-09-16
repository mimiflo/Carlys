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
| Séances sans aucune charge notée | « Pas encore de courbe », et le rappel que le volume compte quand même |
| Une seule séance chargée | « La courbe se trace à partir de deux » |

Les séances restent listées dans les trois cas : elles ont bien eu lieu.

## Hors périmètre, et pourquoi

Deux morceaux de la tranche « Progression » attendent une décision qui n'est
pas technique :

- **Les photos de progression.** `StorageService` est PUBLIC par
  construction (`urlFor` concatène `s3PublicBaseUrl`, `put` pose
  `CacheControl: public, max-age=31536000, immutable`). Stocker des images
  intimes derrière une URL devinable et mise en cache un an n'est pas
  acceptable ; le choix entre URL présignées et relais API est technique, la
  décision de stocker des photos de corps ne l'est pas — elle emporte purge
  RGPD, effacement à la suppression de compte et sauvegardes MinIO.
- **La frise chronologique**, qui réunit séances, records, mesures, photos et
  récompenses. Ses quatre premières sources existent ; la cinquième dépend du
  point précédent, et une frise livrée sans elle serait à refaire.

## Couverture

- `progress_flow_test.dart` : parcours complet, ajout et suppression d'une
  mesure (avec confirmation ET annulation, prouvée par le compteur de
  suppressions du double), et la liste complète qui rend corrigeable une
  mesure que la page ne montrait pas.
- `exercise_progression_test.dart` : la route est réellement interrogée, la
  courbe se trace, un record du bon jour marque son point et un record d'un
  autre jour n'en marque aucun, les trois cas sans courbe, et l'état
  d'erreur avec son réessai.
