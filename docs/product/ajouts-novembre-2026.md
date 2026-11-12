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
- **Changements visibles hors de l'écran** : Android 8.0 au minimum
  (`minSdk` 26) — **Android 7 ne reçoit plus de mise à jour** — et une
  dépendance alpha tirée par le greffon (`connect-client` 1.2.0-alpha02) ;
  sur iOS, la capacité HealthKit à cocher dans l'App ID et le profil
  (`docs/deployment/builds-mobiles.md`).
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

**Réalisé (6 novembre 2026).**
- *Donnée.* `apps/mobile/assets/nutrition/glycemic_index.json` : les
  62 aliments courants de la Table 1 d'Atkinson, Foster-Powell et
  Brand-Miller (*Diabetes Care* 2008, doi:10.2337/dc08-1239), traduits :
  sélection regroupée par Carlys, valeurs de la Table 1. Pour chacun : la moyenne (glucose = 100),
  l'erreur standard (le « ± »), la famille, et le renvoi de la source s'il
  y en a un (* des variétés à IG bas existent, † moyenne de toutes les
  données). Aucune valeur ajoutée ni estimée. Aucune API, aucune
  migration.
- *Page.* `/nutrition/index-glycemique` (`GlycemicIndexScreen`) :
  l'explication en tête (de combien un aliment fait monter la glycémie
  dans les deux heures, comparé au glucose, la portion et la charge
  glycémique, la cuisson, la maturité et le repas, « pas un avis
  médical »), une recherche sans casse ni accents avec son état vide, les
  huit familles en pastilles (et « Tous »), le tri par famille ou par IG
  croissant ou décroissant, puis les renvois et la source complète.
  Vert, orange, rouge : `success`, `warning`, `danger` du design system,
  toujours doublés du mot (bas, moyen, élevé).
- *Entrée.* Une ligne « Index glycémique » sous les cinq tuiles de
  l'onglet, pas une sixième tuile : c'est un repère qu'on consulte, pas un
  geste du jour, et sous les tuiles il se voit sans défiler (le bas de
  l'onglet recule à chaque repas noté).
- *Accessibilité.* Chaque ligne se lit d'un trait (« Pomme crue, IG 36,
  bas. »), avec son renvoi ; les titres de famille sont des en-têtes ; le
  texte agrandi passe à la ligne.
- *Point juridique à valider.* L'article est publié sous CC BY-NC-ND 3.0.
  Nous reprenons des valeurs mesurées (des faits), dans une sélection
  traduite et regroupée par nous, avec la source citée. Le propriétaire
  doit faire valider ce point avant la publication commerciale (voir
  `docs/product/nutrition.md`). Les conditions d'utilisation
  (`docs/legal/terms.md`, § 8), où sont recensées les sources tierces,
  citent la table.
- *Tests.* `glycemic_index_pack_test.dart` compare chaque ligne du pack à
  la source recopiée dans le test (62 entrées, valeur par valeur, dans
  l'ordre) ; `glycemic_selection_test.dart` (bornes 55, 56, 69, 70,
  recherche, filtre, tri stable) ; `glycemic_index_screen_test.dart`
  (recherche et état vide, filtre, tri, lecture d'écran, reprise après
  échec, texte à 200 %) ; et l'entrée depuis l'onglet dans
  `nutrition_flow_test.dart`. Captures `nutrition-16` à `nutrition-21`
  de `tool/screenshots/nutrition_test.dart`.
