# Ajouts demandés le 3 novembre 2026

La demande du propriétaire, telle quelle : « Tableau indice glycémique ;
scanner du code-barres (Samsung payant, pas appel) ; pas ; à la fin, que tu
puisses t'auto-évaluer à la fin de ta séance + te dise temps de repos ;
balance connectée qui puisse s'intégrer ; truc de mensuration ».

Cinq tranches verticales, livrées une à une. Ce fichier dit, pour chacune, ce
qui existe déjà, ce qui est livré, et ce qui ne l'est pas. Ce sont des choix
par défaut : chacun se change sur simple demande.

## A. Scanner de code-barres — gratuit, Open Food Facts

**Existant.** Un lecteur de code-barres a été livré, puis retiré le
4 octobre 2026 (`fc50ed1c`) quand la demande était le scan de l'assiette par
IA. Le scan de l'assiette reste. Le lecteur de code-barres revient à côté.

**Livré.**
- Une photo du code-barres de l'emballage → le produit Open Food Facts : nom,
  marque, valeurs pour 100 g.
- La quantité en grammes, puis l'ajout au repas.
- Open Food Facts est gratuit et sans clé (licence ODbL, mention
  obligatoire). Contrairement au scanner payant de Samsung Health, il ne
  coûte rien.
- Le serveur garde la réponse en cache dans Redis : un produit déjà scanné ne
  rappelle pas Open Food Facts.

**Hors champ.** Ajouter un produit inconnu à Open Food Facts depuis
l'appli.

## B. Auto-évaluation de fin de séance et temps de récupération

**Existant.** Un RPE par série (`WorkoutSet.rpe`), et le bilan de séance.
Rien pour la séance entière.

**Livré.**
- **« Comment c'était ? »** sur le bilan, en cinq choix : Très facile,
  Facile, Modéré, Difficile, À fond. C'est l'effort perçu de la séance, sur
  l'échelle de Borg CR10, enregistré de 1 à 10.
- Facultatif, modifiable ensuite, et synchronisé hors ligne comme le reste
  de la séance.
- **« Repos conseillé »**, déduit de l'effort et des groupes musculaires
  travaillés. Repère : au moins 48 h avant de retravailler un même groupe
  (recommandation ACSM), modulé par l'effort :
  - Très facile ou Facile : 24 h ;
  - Modéré : 48 h ;
  - Difficile ou À fond : 72 h.
  La phrase dit quels muscles et jusqu'à quand.
- Les réglages par défaut sont une indication d'entraînement générale, pas
  un avis médical, et le texte le dit.

**Hors champ.** Une récupération calculée à partir du sommeil ou de la
fréquence cardiaque.

**Réalisé (3 novembre 2026).**
- *Donnée.* `WorkoutSession.perceivedEffort` (entier nullable, `CHECK` 1..10
  en base, migration `20261105120000_effort_percu_seance`), servi dans le
  détail de séance (`WorkoutSessionDetail.perceivedEffort`). Il s'écrit par
  `PATCH /workout-sessions/{id}` : l'écriture fait monter la révision, donc
  un autre appareil le rapatrie ; un rejeu à valeur égale ne touche aucune
  ligne. Côté appareil, colonne Drift `perceived_effort` (schéma local v11).
- *Synchronisation.* Le chemin des corrections de série, appliqué à la
  séance : nouvelle opération `session.update`, sur la voie de la séance,
  derrière sa création et sa clôture — donc modifiable après la clôture,
  hors ligne compris. Une évaluation encore en attente est remplacée par la
  suivante (un seul PATCH, comme `template.save`).
- *Bilan.* Carte « Comment c'était ? » en bas du bilan (`SessionEffortCard`),
  donc aussi sur toute séance ouverte depuis l'historique — séance TERMINÉE
  seulement : une séance abandonnée n'a ni carte ni repos. Très facile = 2,
  Facile = 4, Modéré = 5, Difficile = 7, À fond = 9 ; toucher la réponse
  choisie la retire. Une valeur venue d'ailleurs retombe sur la réponse de sa
  bande (`EffortChoice.fromBorg`).
- *Repos conseillé.* `recoveryAdvice` (domaine, pur) : ≤ 4 → 24 h, 5–6 →
  48 h, ≥ 7 → 72 h, à partir de la fin de séance. Les muscles sont les
  groupes PRINCIPAUX des fiches du catalogue (`ExerciseDetail.muscles`) ;
  hors ligne, ou dès qu'UNE fiche manque, la phrase se dit sans eux (jamais
  une liste tronquée), et l'échec est journalisé. L'échéance est
  dite en heure locale, arrondie à l'heure supérieure, et tue une fois
  passée (séance relue plus tard). La mention ACSM « pas un avis médical »
  l'accompagne toujours.

## C. Mensurations

**Existant.** Le poids et le taux de masse grasse (`BodyMetric`), dans
Progrès.

**Livré.**
- Les tours de taille, de hanches, de poitrine, de bras, de cuisse, de
  mollet et de cou, en cm, dans la même table : nouvelles valeurs de
  `BodyMetricType` et une migration.
- Une section « Mensurations » dans Progrès : la dernière valeur de chaque
  zone, son évolution depuis la première, et une saisie par feuille.

## D. Pas et balance connectée — Health Connect et Apple Santé

**Existant.** Rien.

**Livré.**
- Une connexion facultative, depuis les réglages, à **Health Connect**
  (Android) ou à **Apple Santé** (iOS), par le paquet Flutter `health`, qui
  couvre les deux. Il n'y a ni API payante ni compte tiers.
- Samsung Health et les balances connectées les plus courantes (Withings,
  Xiaomi, Renpho, Eufy…) y écrivent déjà leurs mesures : passer par ce
  point commun évite une intégration par marque.
- **Pas** : le nombre de pas du jour sur l'accueil. Il reste sur
  l'appareil, comme l'eau : un compteur du jour n'a rien à raconter à un
  autre appareil.
- **Balance** : les pesées (poids et masse grasse) que la balance a écrites
  dans Health Connect ou Apple Santé sont importées dans Carlys, comme des
  mesures saisies à la main. Leur identifiant est dérivé de celui de la
  mesure source, pour qu'une même pesée ne soit jamais importée deux fois.
- Lecture seule : Carlys n'écrit rien dans Health Connect ni dans Apple
  Santé.
- Le détail — couches, connexion, bornes, identifiant dérivé, configuration
  native, ce qui reste à faire côté magasins et sur un vrai téléphone — vit
  dans [`sante-connectee.md`](sante-connectee.md).

**Hors champ.** La connexion Bluetooth directe à une balance, propre à
chaque marque.

## E. Tableau des index glycémiques

**Existant.** La base CIQUAL ne donne pas d'index glycémique.

**Livré.**
- Une page « Index glycémique » dans Nutrition. Les aliments courants y sont
  classés bas (≤ 55), moyen (56–69) ou élevé (≥ 70), avec une recherche et
  une explication courte de ce que l'index mesure, et de ce qu'il ne mesure
  pas (la portion : la charge glycémique).
- C'est un contenu éditorial embarqué, comme les recettes, lisible hors
  ligne.
- Chaque valeur vient d'une table publiée, citée sur la page. Aucune valeur
  n'est estimée.

**Hors champ.** Un index glycémique affiché sur chaque aliment du journal :
la correspondance avec CIQUAL n'est pas fiable aliment par aliment.
