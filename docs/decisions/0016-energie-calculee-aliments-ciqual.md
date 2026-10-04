# ADR 0016 — L'énergie des aliments CIQUAL qui n'en publient pas, calculée depuis leurs macros

## Statut

Acceptée — 2026-10-04, à la demande du propriétaire (« On peut augmenter la
table ? »). Complète l'import CIQUAL (`docs/product/nutrition.md`, « Base
d'aliments ») et le scan d'assiette (ADR 0015).

## Contexte

L'import refusait tout aliment sans énergie publiée : on ne saurait pas
calculer un repas avec lui. Sur la vraie table CIQUAL 2020, importée le
4 octobre 2026, c'étaient **887 aliments sur 3 185** : l'Anses y écrit « - »
pour l'énergie (valeur UE comme N x Jones), tout en publiant protéines,
glucides et lipides. Parmi eux, des aliments de tous les jours : laitue
crue, salade verte, petits pois cuits, beurre de cacahuète. Le scan
d'assiette les reconnaissait sans pouvoir les proposer, et la recherche ne
les trouvait pas.

## Décision

1. **L'énergie se calcule** quand la table ne la publie pas, par les
   facteurs du règlement UE 1169/2011 (annexe XIV), ceux de l'étiquetage
   et de l'Anses : protéines et glucides 4 kcal/g, lipides 9, fibres 2,
   alcool 7, acides organiques 3, polyols 2,4 (comptés dans les glucides).
   `domain/energy-from-macros.ts`, arrondie au dixième comme la table.
2. **Vérifiée avant d'être crue** : appliquée aux 2 298 aliments dont
   l'énergie EST publiée, la formule la retrouve à 0,3 kcal près en médiane,
   99 % à moins de 6 kcal.
3. **Sans protéines, glucides ou lipides connus, rien ne se calcule** :
   l'aliment reste écarté (93 aliments). Une teneur secondaire inconnue
   (fibres, alcool, acides organiques, polyols) compte pour zéro.
4. **Ce qui est calculé se dit** : `Food.kcalComputed` (colonne, migration
   `energie_calculee_aliment`), servi par l'API (`kcalComputed`), et
   l'appli écrit « ≈ 15 kcal » et complète la mention de la source :
   « énergie absente de la table, calculée par Carlys d'après les
   protéines, glucides et lipides ». La valeur ne passe jamais pour une
   donnée publiée par l'Anses.

Résultat : 794 aliments ajoutés, la base passe de 2 298 à 3 092 aliments ;
le scan d'assiette, de 30 à 32 aliments sur 40 retrouvés au banc. Deux
réglages du rapprochement (`closest-food-query.ts`) accompagnent ces
nouveaux voisins : « lettuce » se traduit désormais « laitue » (et non
plus « salade »), et une variante SÉCHÉE recule quand le nom ne le dit
pas (sinon « Lettuce, cuit » trouvait la laitue de mer séchée, « pomme »
la pomme sèche).

## Alternatives écartées

- **Garder la table telle quelle** : la laitue et les petits pois restent
  introuvables, et le rapprochement du scan tombe sur leurs voisins (la
  « laitue de mer » séchée pour une salade).
- **Une autre base** (Open Food Facts, USDA) : produits emballés ou noms
  anglais, licences et valeurs à concilier ; la table CIQUAL a déjà les
  macros de ces aliments.
- **Estimer les macros manquantes aussi** : rien n'y autorise ; une macro
  inconnue reste `null`, jamais zéro (règle du journal).

## Inconvénients

- Une valeur calculée n'est pas une valeur mesurée : une fibre ou un polyol
  non dosé, compté pour zéro, sous-estime un peu l'énergie.
- Une ligne de repas déjà enregistrée ne garde pas le marqueur : son
  instantané porte les valeurs, pas leur origine. La mention se lit là où
  l'aliment est choisi : la recherche (« ≈ » et la mention) et l'écran du
  repas en cours, pré-rempli par le scan compris (la mention seule).
- Polyols : CIQUAL les compte DANS les glucides (vérifié sur les 47
  aliments qui en ont au moins 1 g : 0,37 kcal d'écart médian) ; la formule
  ne les laisse jamais dépasser les glucides.
