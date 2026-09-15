# Nutrition — métabolisme et journal alimentaire

Deux moitiés, jamais confondues :

- l'**objectif** — calculé côté serveur depuis le profil métabolique
  (Mifflin-St Jeor : BMR, TDEE, objectif calorique, macros, hydratation) ;
- le **consommé** — saisi par l'utilisateur dans le journal alimentaire.

L'accueil affiche « consommé / objectif » (ex. « 654 / 2 759 ») **uniquement
quand les deux existent**. Journal non chargé : l'objectif seul, jamais un
zéro inventé. Journal vide : un VRAI zéro (« 0 / 2 759 »), qui est un fait.

## Journal alimentaire (`/api/v1/nutrition/meals`)

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| POST | `/` | Ajouter un repas — id UUID généré sur l'appareil, création idempotente et rejouable |
| GET | `/?from&to` | Repas entre deux instants UTC |
| DELETE | `/:id` | Retirer (suppression douce, idempotente) |

Règles :

- **Le serveur ne découpe jamais les journées.** `eatenAt` est un instant
  UTC ; le client calcule les bornes de SA journée locale et les envoie
  (`from` inclus, `to` exclu). Un repas à 23 h 30 heure locale appartient au
  jour local, quel que soit le fuseau.
- **Mêmes garanties que les séances** : id client (rejouable), suppression
  douce idempotente, 404 indiscernable pour la donnée d'autrui.
- Un repas porte `name`, `kcal` (1 à 10 000) et `proteinG` facultatif.

## Hydratation — la seule mesure qui reste sur l'appareil

L'objectif d'eau (`waterMl`) vient du même calcul serveur que les calories et
les macros. Le **consommé**, lui, ne quitte jamais le téléphone : une table
Drift à une ligne par jour (`LocalWaterIntakes`, clé primaire = le jour local,
schéma 4), lue en flux par `consumedWaterTodayProvider`.

Ce choix est délibéré, et c'est l'exception à la règle du dépôt :

- un verre d'eau n'a **rien à raconter** à un autre appareil, contrairement à
  une séance ou à une mesure corporelle — pas de records à recalculer, pas de
  statistique à servir ;
- une file de synchronisation idempotente pour un entier remis à zéro chaque
  nuit coûterait bien plus qu'elle ne rapporte, schéma et endpoint compris ;
- l'écriture est bornée dans la transaction elle-même (0 à 20 L), et non par
  l'appelant : un total négatif ou absurde ne peut pas être écrit, quelle que
  soit la porte d'entrée.

La saisie passe par une **feuille** (`showWaterSheet`) ouverte depuis la
cellule Hydratation de l'accueil : `+ 25 cl`, `+ 50 cl`, et un retrait d'un
verre désactivé à zéro plutôt que borné en silence — un bouton qui ne fait
rien quand on le presse est pire qu'un bouton éteint.

## Recettes — contenu éditorial embarqué

Deux volets, dans l'ordre de la journée : **Petit-déj & collation**, partagé
en **sucré / salé**, puis **Déjeuner & dîner**. La saveur ne partage que le
premier : trancher la saveur d'un déjeuner n'aide personne à choisir un plat.

Le pack vit dans `apps/mobile/assets/nutrition/recipes.json`, embarqué comme
celui de l'Academy et pour la même raison : **une recette se lit en cuisine**,
où le réseau manque souvent. Aucune route d'API, aucune migration, aucune
ligne au manifeste routes ↔ clients.

### « Adaptée au profil » : ce que ça veut dire exactement

L'objectif alimentaire (`NutritionGoal`, déjà calculé et servi par
`GET /nutrition/metabolism`) **CLASSE** les recettes ; il n'en cache aucune.
Celles qui servent l'objectif passent devant et portent une pastille
« Pour ton objectif », les autres suivent. Filtrer viderait des volets
entiers et déciderait à la place de la personne : quelqu'un qui prend du
muscle a le droit de vouloir une salade. Le tri est **stable** — à l'intérieur
de chaque groupe, l'ordre du pack est conservé, sinon l'affichage changerait
d'une visite à l'autre sans raison visible.

Chaque recette annonce en plus **ce qu'elle pèse dans la journée** (sa part de
la cible calorique). Ce pourcentage n'apparaît QUE si le profil métabolique
est complet : sans cible, ce rapport n'existe pas, et en inventer un serait
pire que de se taire. Même règle pour la phrase « Classées pour ton
objectif », absente tant que l'objectif est inconnu.

### La garde qui compte : l'exactitude nutritionnelle

Des gens comptent leurs calories sur ces chiffres. Un test échoue si, pour une
recette, `protéines × 4 + glucides × 4 + lipides × 9` s'écarte de plus de
**15 %** des calories annoncées : c'est de l'arithmétique, pas une opinion, et
une recette dont le bilan ne tombe pas est une recette fausse. Le même fichier
vérifie l'unicité des identifiants, la présence d'une saveur sur tout le volet
petit-déj (sans elle la recette n'apparaîtrait nulle part), la couverture des
trois objectifs, et que le champ `goals` **discrimine** — si toutes les
recettes se disaient bonnes pour tout, le classement de l'écran serait
décoratif.

Une garde de plus, née d'un vrai défaut : **aucun titre en double dans un même
onglet**. Des identifiants uniques ne suffisent pas. « Déjeuner & dîner » est
UN onglet, et deux recettes écrites séparément y ont porté le même titre, à
quelques grammes près ; la liste se répétait à l'écran, ce qui se lit comme un
bug plutôt que comme un choix. C'est la paire (volet, saveur) qui fait
l'onglet, donc c'est elle que le test regroupe.

### Pas d'images, pour l'instant

Les recettes n'embarquent aucune photo : l'écran s'appuie sur la typographie
et les pastilles de macros. C'est le même arbitrage que pour les leçons non
anatomiques de l'Academy — exiger une photo par recette reviendrait à bloquer
l'écriture derrière la production d'images, ou à recycler des visuels sans
rapport avec l'assiette.

## Le POURQUOI de chaque chiffre

« Carlys ne dit jamais seulement quoi faire, il explique toujours pourquoi. »
L'écran annonçait « IMC 27,3 » puis « Surpoids », et s'arrêtait là : un
verdict, pas une explication. Les raisons existaient pourtant déjà — en
commentaires TypeScript dans `metabolism.calculator.ts`, c'est-à-dire là où
personne ne les lira jamais.

Elles sont désormais du **contenu**, dans
`apps/mobile/lib/features/nutrition/domain/metric_explanation.dart` : neuf
entrées, chacune en trois blocs, toujours dans le même ordre.

| Bloc | Ce qu'il porte |
| --- | --- |
| **Ce que c'est** | Une phrase, sans jargon. |
| **D'où ça sort** | Le calcul RÉEL, avec ses nombres — pas une paraphrase. |
| **Ce que ça ne dit pas** | Les limites. Facultatif, souvent le plus utile. |

### Où sont les portes

Le glyphe d'information marque la donnée ; **c'est la donnée entière qui
répond au doigt**, pas le glyphe. Poser un bouton de 48 points sur une tuile
recouvrirait la valeur et créerait deux cibles concurrentes pour une seule
intention. D'où deux composants, et la règle qui les départage :

- `AppExplainable` — enveloppe une donnée affichée : tuile d'IMC ou
  d'hydratation (`AppStatTile.onExplain`), ligne de macro, dépense totale et
  métabolisme de base du hero.
- `AppExplainButton` — quand le glyphe EST le bouton. Un seul emploi : les
  libellés « Niveau d'activité » et « Mon plan nutrition » du formulaire de
  profil, qui n'ont rien à ouvrir par eux-mêmes. C'est aussi là que le
  pourquoi compte le plus : ce sont les deux **seules** entrées libres, et
  elles déplacent tous les chiffres de l'écran.

### La donnée ABSENTE a sa porte, elle aussi

La masse grasse et la masse musculaire ne sont ni calculées ni estimées :
aucune des deux ne se déduit du poids et de la taille, et les formules qui
prétendent le contraire partent de l'IMC — elles se trompent donc surtout
chez les gens qui s'entraînent, c'est-à-dire ici. Une pastille « Et ma masse
grasse ? » le dit, avec la raison. Répondre « nous ne le mesurons pas, voici
pourquoi » vaut mieux qu'afficher un chiffre faux.

### La garde : une explication qui ment est pire que pas d'explication

`metric_explanation_test.dart` **lit le calculateur du serveur** et vérifie
que chaque nombre cité est celui qu'il applique : facteurs d'activité,
coefficients de Mifflin-St Jeor, ajustements par objectif, grammes de
protéines par kilo, part des lipides, millilitres d'eau par kilo, seuils
d'IMC. Changer `FAT_RATIO` ou un facteur d'activité côté API fait tomber un
test **côté mobile**, en nommant le chiffre qui a bougé.

Deux détails du test méritent d'être connus avant d'y toucher : la part des
lipides s'écrit en toutes lettres (« un quart »), donc une table dit comment
chaque valeur se lit — une valeur absente échoue exprès, pour qu'on écrive la
formulation au lieu de la deviner ; et le catalogue est aussi relu comme un
TEXTE, seul moyen sans réflexion de repérer une explication déclarée mais
oubliée dans `toutes`, qui échapperait sinon à tous les autres contrôles.

## Mobile

- Écran Nutrition : section « Journal du jour » (liste, total en en-tête
  face à l'objectif, feuille d'ajout nom/kcal/protéines, retrait) entre le
  rapport métabolique et le profil.
- **Le hero a deux états**, comme la grille et l'amorçage de l'accueil. Avec
  un métabolisme, la dépense totale en très grand. Sans, il garde son hélice
  et son titre mais ne prétend plus donner un chiffre : une phrase et le
  bouton « Compléter mon profil », qui fait défiler jusqu'au formulaire. Un
  tiret géant en accent servait l'absence comme le fait principal, sans dire
  comment en sortir ; c'est aussi là qu'arrive le bouton « Calculer mes
  objectifs » de l'accueil.
- **L'ordre des sections dépend du profil.** Complet : rapport, journal,
  profil. Incomplet : champs manquants, **profil**, journal. Le seul geste
  utile du premier jour n'est jamais le dernier bloc de la page.
- Accueil : la tuile Nutrition du « Résumé du jour » montre le consommé réel
  face à l'objectif (`consumedKcalTodayProvider`), et la cellule Hydratation
  ouvre la feuille d'eau (`waterStoreProvider`).

## Couverture

- Unitaires API (`meals.service.spec.ts`) : idempotence, conflit d'id
  d'autrui, retraits idempotents, 404 opaque.
- e2e API (`nutrition.e2e-spec.ts`) : ajout rejoué sans doublon, fenêtre de
  journée bornée par le client, retrait doux, validation des calories.
- Widgets mobile : ajout par la feuille (total mis à jour), suppression,
  « 0 / objectif » sur journal vide et « 654 / objectif » avec repas ;
  premier jour (aucun tiret, bouton présent, formulaire avant le journal, le
  bouton du hero amène le formulaire à l'écran) et profil complet (chiffre,
  journal avant le formulaire).
- Recettes : intégrité du pack (bilan 4/4/9 des macros à 15 % près, saveur
  obligatoire sur le volet petit-déj, trois objectifs couverts, `goals` qui
  discrimine, aucun titre en double dans un onglet, rechargement après échec
  de lecture) ; règle de classement pure
  (`recipe_selection_test` : classe sans cacher, tri stable, silence sans
  cible) ; écran (bascule des volets, partage sucré/salé absent sur les repas,
  recette pour l'objectif remontée sans faire disparaître les autres, part de
  la journée tue sans profil, dépliage ingrédients puis préparation).
- Pédagogie : couplage explication ↔ calculateur serveur
  (`metric_explanation_test`, qui lit `metabolism.calculator.ts`), intégrité
  du catalogue (titres uniques, aucune explication oubliée dans `toutes`), et
  les portes elles-mêmes (`metric_explanation_sheet_test` : chaque tuile,
  chaque ligne de macro et chaque bloc du hero ouvre SON explication et
  aucune autre, « J'ai compris » referme, l'annonce au lecteur d'écran donne
  la valeur avant le mot « Explication », et chaque porte dépasse la cible
  tactile).
- Hydratation : migration 3 → 4 non destructive (`app_database_migration_test`),
  lecture du compteur sur l'accueil, feuille ouverte au tapotement de la
  cellule et écriture réellement enregistrée dans le magasin.
