# Jeu d'essai CIQUAL — PAS la table CIQUAL

Ces fichiers reproduisent le **format** de la distribution XML officielle de
la table CIQUAL de l'Anses (quatre fichiers `alim_*`, `alim_grp_*`, `compo_*`,
`const_*`, encodés en **windows-1252**, enregistrements plats `<TABLE><ALIM>…`)
pour exercer `dist/cli/ciqual-import` sans le vrai fichier, inaccessible depuis
l'environnement de développement au moment de leur écriture.

**Les noms d'aliments sont réels ; les codes (`99xxxx`) et toutes les valeurs
sont ILLUSTRATIFS.** Ils ont été choisis pour exercer l'import, pas recopiés
de la table : ne jamais s'en servir comme donnée nutritionnelle, ni les charger
ailleurs qu'en base de test. Un commentaire XML le rappelle en tête de chaque
fichier.

Ce que chaque cas exerce :

| Cas | Où |
| --- | --- |
| `traces` → 0 | glucides du poulet filet (`990001`) |
| `&lt; 0,5` (sous le seuil de quantification) → 0 | lipides du brocoli (`990003`) |
| `-` (non dosé) → `null` | lipides de la galette de riz (`990006`) |
| énergie `-` → ignoré, « énergie inconnue » | eau du robinet (`990004`) |
| aucune teneur d'énergie → ignoré, « énergie inconnue » | sel (`990005`) |
| ligature `œ` en windows-1252 (octet `0x9C`) | œuf dur (`990009`), groupe « viandes, œufs… » |
| constituants voisins à ne PAS confondre | `Protéines, N x 6.25`, `Energie … (kJ/100 g)` |
| aliment retiré entre deux versions | cuisse de poulet (`990008`) : dans `v1`, absente de `v2` |
| valeur mise à jour entre deux versions | énergie du brocoli (`990003`) : 29,5 puis 30,5 |
| codes de constituants renumérotés | `v2` : tous décalés de 900 000 — la résolution se fait par le NOM |

`v1` porte la date de la distribution 2020 (`2020_07_07`) ; `v2` une date
volontairement fictive (`2099_01_01`), pour qu'on ne la prenne pas pour une
version publiée.
