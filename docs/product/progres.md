# Écran Progrès — statistiques, records, mesures corporelles

À ne pas confondre avec le **profil de progression** ([progression.md](progression.md)),
qui résume la pratique en cinq axes et un titre. La distinction existe dans le
code depuis le début : `features/progress` sert les FAITS mesurés (volume,
records, pesées) ; `features/progression` en tire un score.

Cible mobile : `apps/mobile/lib/features/progress/`
API : `apps/api/src/modules/progress/`

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
