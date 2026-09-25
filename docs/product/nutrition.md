# Nutrition — métabolisme et journal alimentaire

Deux moitiés, jamais confondues :

- l'**objectif** — calculé côté serveur depuis le profil métabolique
  (Mifflin-St Jeor : BMR, TDEE, objectif calorique, macros, hydratation) ;
- le **consommé** — saisi par l'utilisateur dans le journal alimentaire.

L'accueil affiche « consommé / objectif » (ex. « 654 / 2 759 ») **uniquement
quand les deux existent**. Journal non chargé : l'objectif seul, jamais un
zéro inventé. Journal vide : un VRAI zéro (« 0 / 2 759 »), qui est un fait.

## Deux bornes de sécurité sur le calcul

Le calcul n'avait aucun fond, ni en entrée ni en sortie.

**L'âge.** `birthDate` n'était bornée que par « pas dans le futur » au DTO, et
par un maximum de 120 ans recopié dans `users.service.ts` — deux règles pour
un seul fait, dont la seconde n'était couverte par aucun test unitaire, le
module n'ayant pas de `.spec.ts`. Entre les deux, un âge de 0 an passait et
entrait tel quel dans Mifflin-St Jeor, où il vaut `-5 × 0`. L'intervalle vit
désormais dans le contrat (`AGE_YEARS_MIN` 15, `AGE_YEARS_MAX` 120,
`birthDateRange`), le DTO l'applique seul, et `update-profile.dto.spec.ts` le
tient — bornes incluses, on naît admissible le jour de ses 15 ans. Les deux
dates sont recalculées à CHAQUE requête : les figer au chargement du module
ferait vieillir la borne avec le processus.

Ce n'est **pas** une vérification d'âge à l'inscription — le compte se crée
sans date de naissance, et `docs/legal/privacy.md` §8 continue de le dire
honnêtement. C'est le refus d'une valeur dont les documents du produit disent
déjà qu'elle ne devrait pas exister.

**L'objectif calorique.** `tdee × 0,85` n'avait pas de plancher : le seul
`Math.max` du calculateur bornait les glucides à 0, ce qui protégeait la
cohérence des macros, jamais la personne. Une fixture du dépôt atteignait
déjà le cas sans le voir — femme de 70 ans, 150 cm, 40 kg, sédentaire, perte
de gras — et rendait **843 kcal**. `TARGET_KCAL_FLOOR` vaut désormais 1200
(femmes) et 1500 (hommes), les seuils bas usuels d'un régime non supervisé
médicalement, et s'applique **avant** les macros : lipides et glucides se
calculent sur la cible affichée, pas sur celle d'avant.

Deux conséquences assumées, toutes deux testées :

- l'objectif cesse d'être **monotone** en objectif — sous le plancher, perte
  de gras et maintien se rejoignent. C'est précisément ce que le plancher
  veut dire ;
- la cible ne vaut plus « dépense × facteur », donc l'afficher nue la ferait
  contredire son explication. Le serveur pose `targetKcalFloored`, l'écran
  montre la mention « Cible relevée au minimum de sécurité », et cette
  mention ouvre sa propre explication — pas celle de l'objectif, qui répond à
  une autre question.

## Journal alimentaire (`/api/v1/nutrition/meals`)

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| POST | `/` | Ajouter un repas — id UUID généré sur l'appareil, création idempotente et rejouable ; saisi à la main (`kcal`) ou composé d'aliments (`components`, chaque ligne sous un UUID de l'appareil) |
| GET | `/?from&to` | Repas entre deux instants UTC, composants compris |
| GET | `/:id` | Un repas, composants compris — 404 indiscernable pour un repas inconnu, supprimé ou d'autrui |
| PATCH | `/:id` | Corriger sur place — champ absent = inchangé, champ `null` = effacé ; `components` remplace (ou, vide, retire) la composition, une ligne désignée par son `id` gardant son instantané |
| DELETE | `/:id` | Retirer (suppression douce, idempotente) |

Règles :

- **Le serveur ne découpe jamais les journées.** `eatenAt` est un instant
  UTC ; le client calcule les bornes de SA journée locale et les envoie
  (`from` inclus, `to` exclu). Un repas à 23 h 30 heure locale appartient au
  jour local, quel que soit le fuseau.
- **Mêmes garanties que les séances** : id client (rejouable), suppression
  douce idempotente, 404 indiscernable pour la donnée d'autrui.
- Un repas porte `name`, `kcal` (1 à 10 000) et **les trois macros**,
  `proteinG`, `carbsG` et `fatG`, toutes facultatives (0 à 1 000) et
  **indépendantes**. `null` veut dire « on ne sait pas », jamais « zéro » :
  l'écran doit pouvoir faire la différence, sinon une macro inconnue
  s'afficherait « 0 g ».

  L'écran montrait quatre macros CIBLES et n'en journalisait que deux : sur
  les deux tiers de ce qu'il affichait, la comparaison consommé / objectif
  était impossible. Les colonnes sont nullables et sans valeur par défaut
  (migration `20260915170000_meal_macros`) — poser un 0 aux entrées déjà
  enregistrées les aurait fait mentir.

- **La quantité est PUREMENT DESCRIPTIVE.** `quantity` (0,01 à 9 999,99) et
  `quantityUnit` (`GRAM`, `MILLILITER`, `PORTION`, `PIECE`) vont **par
  paire** — une quantité sans unité ne dit rien — et valent `null` ensemble
  quand l'entrée n'en porte pas (migration `20260919181907_quantite_du_repas`).

  Elle ne multiplie NI `kcal` NI les macros, qui restent le TOTAL réellement
  consommé. La rendre multiplicatrice changerait le sens de `kcal` — il
  cesserait de dire « ce repas » pour dire « une unité de ce repas » — et les
  bornes de saisie (10 000 kcal, 1 000 g par macro) sont des bornes de REPAS.
  L'écran l'écrit sous le champ, parce que « 250 g » à côté de « 350 kcal » se
  lit sinon comme « 350 kcal pour 100 g ».

- **`eatenAt` ne peut pas être dans le futur** (`@MaxDate(nowWithClockSkew)`,
  un jour de tolérance d'horloge), à la création COMME à la correction. Sans
  cette borne, un repas daté de l'an prochain sortait du jour courant pour
  toujours : le total « consommé » de l'accueil ne le voyait plus, et la
  personne cherchait un repas pourtant bien enregistré. La pesée portait déjà
  la même borne ; le repas ne l'avait pas.

- **Corriger, plutôt que supprimer puis ressaisir.** `PATCH /:id` garde
  l'identifiant, donc la place dans le journal et le total : un champ ABSENT
  du corps reste tel quel, un champ à `null` EFFACE ce qu'on croyait savoir.
  `name`, `kcal` et `eatenAt` refusent `null` (400, jamais 500) ; un corps
  vide est refusé ; le repas d'autrui, inconnu ou supprimé répond 404 sans
  distinction. La cohérence de la paire quantité/unité se juge sur l'état
  APRÈS correction, pas sur le fragment reçu.

  Côté mobile, UN écran plein sert les DEUX usages — ajouter, corriger (voir
  « Mobile » plus bas). En correction, il relit le repas et le montre en
  entier : une case vidée veut dire « on ne sait plus » et part en `null`
  explicite. Un repas SAISI envoie donc toutes ses clés de totaux ; un repas
  COMPOSÉ n'en envoie aucune (sa composition gardée, ou la liste de ses
  lignes). La version publiée avant cet écran, une feuille, envoyait
  toujours toutes ses clés : sur un repas composé, des totaux renvoyés **à
  l'identique** ne sont pas une correction, ils sont ignorés, et renommer ou
  changer l'heure reste possible depuis cette version. Un total CHANGÉ reste
  refusé (400).

- **Toute correction se décide sous verrou.** Le repas est relu sous le
  verrou de sa ligne (`SELECT … FOR UPDATE`) dans la transaction qui écrit :
  la règle des totaux, la paire quantité / unité et l'instantané des lignes
  gardées se jugent sur CET état, jamais sur une lecture faite avant. Une
  correction manuelle qui croise une recomposition passe après elle, et se
  voit refuser des calories qui ne correspondraient plus aux aliments ; un
  retrait de composition qui la croise retire aussi la nouvelle. La
  suppression douce et le dépôt d'une photo prennent le même verrou.

- **Le journal se consulte en arrière.** Deux flèches reculent d'un jour
  civil (jusqu'à un an, la plage que le serveur accepte en une requête) ;
  celle de demain reste éteinte, un jour à venir n'ayant rien à montrer ni à
  recevoir. Le jour sélectionné est un ÉCART en jours avec aujourd'hui, jamais
  une date mémorisée — celle-ci se périmerait à minuit en continuant de
  s'appeler « Aujourd'hui ».

### Le moment de la journée

`moment` vaut `BREAKFAST`, `LUNCH`, `DINNER` ou `SNACK` (petit-déjeuner,
déjeuner, dîner, collation). C'est une **donnée enregistrée**, pas une
déduction de l'heure : un dîner pris à 23 h 40 reste un dîner, une collation
à midi reste une collation. Facultatif à la création, effacé par `null` en
correction.

Les repas enregistrés avant son arrivée le laissent à `null` (migration
`20260925100000_moment_aliments_composition`, colonne nullable sans défaut) :
en inventer un les ferait mentir. Le client en déduit alors un **affichage**
depuis l'heure locale, sans rien écrire tant que la personne n'enregistre pas
le repas ; à l'enregistrement suivant, le moment affiché (proposé ou choisi)
s'écrit. Le coach le reçoit tel quel (`get_recent_meals`), `null` compris.

La proposition suit l'heure LOCALE du repas, bornes basses incluses : avant
10 h 30, petit-déjeuner ; jusqu'à 15 h, déjeuner ; jusqu'à 18 h, collation ;
jusqu'à 22 h 30, dîner ; au-delà, collation (`MealMoment.suggestFor`, éprouvée
borne par borne par `meal_rules_test.dart`). Un repas neuf la reçoit aussi,
et elle suit l'heure qu'on règle tant que personne n'a choisi.

## Base d'aliments (`/api/v1/nutrition/foods`) — table CIQUAL de l'Anses

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| GET | `/?q&limit` | Chercher un aliment : valeurs **pour 100 g**, `meta.source` = mention à afficher |
| GET | `/:code` | Fiche d'un aliment (404 s'il est inconnu ou retiré) |

On cherche un aliment, on donne sa quantité en grammes, et le serveur calcule
calories et macros. C'est l'« Option 1 » du Plan 6, arbitrée par le
propriétaire le 25 septembre 2026 : une base **côté serveur**, calcul **côté
serveur**.

### La source, et la mention obligatoire

La **table CIQUAL** (composition nutritionnelle des aliments) de l'Anses :
française, publique, environ 3 200 aliments génériques, sous **Licence Ouverte
Etalab 2.0**. La réutilisation est libre, y compris commerciale, **à
condition de mentionner la source et la date de sa dernière mise à jour**.
Partout où une valeur de la base est montrée, l'écran affiche donc :

> Source : Anses, Table de composition nutritionnelle des aliments Ciqual

avec la version dont viennent les valeurs. Les deux routes d'aliments la
renvoient dans `meta.source` (`attribution`, `version`, `license`, `url`),
avec la version chargée. Les routes de repas aussi, dès qu'un repas rendu
porte des aliments de la base : `meta.source` (`attribution`, `license`,
`url`), et la version de CHAQUE ligne dans `components[].sourceVersion`,
qui reste celle de l'ajout (une ligne gardée d'une version à l'autre ne
prend pas la date de la nouvelle table). Un repas saisi à la main n'en porte
pas (`meta` vide). Le client n'a rien à coder en dur, même pour un aliment
retiré depuis. Les conditions d'utilisation (`docs/legal/terms.md`, §8) le
disent aussi.

### Ce que la base contient

Une ligne `Food` par aliment, clé = `alim_code` CIQUAL (stable d'une version
à l'autre, c'est ce qui rend l'import rejouable) :

- `name` : le nom officiel, « Poulet, filet, sans peau, cuit » ;
- `shortName` : le segment avant la première virgule, « Poulet » ;
- groupe et sous-groupe (codes et noms) ; la réponse de l'API en sert le
  groupe (`group`) ;
- quatre valeurs **pour 100 g**, lues par le NOM du constituant dans
  `const_*.xml`, jamais par un code supposé :

  | Valeur | Constituant CIQUAL |
  | --- | --- |
  | `kcal` | « Energie, Règlement UE N° 1169/2011 (kcal/100 g) » |
  | `proteinG` | « Protéines, N x facteur de Jones (g/100 g) » |
  | `carbsG` | « Glucides (g/100 g) » |
  | `fatG` | « Lipides (g/100 g) » |

- une clé de recherche normalisée (minuscules, sans accents ni ligatures,
  ponctuation en espaces : « Œuf, dur » → `oeuf dur`) ;
- la version de la table dont viennent ces valeurs, et `retiredAt`.

**Comment une teneur est lue.** La table écrit pour un lecteur humain :

| Écrit | Sens | Stocké |
| --- | --- | --- |
| `12,5` | une valeur, virgule décimale | `12.5` (deux décimales) |
| `traces` | présent, en quantité négligeable | `0` |
| `< 0,5` | sous le seuil de quantification du dosage | `0` |
| `-` ou vide | non dosé : la table ne sait pas | `null` |

`traces` et `< x` valent 0 parce que l'Anses publie ces mentions quand le
dosage existe mais ne mesure rien d'exploitable : compter la borne haute
gonflerait un repas d'un nutriment qu'on sait quasi absent. `-` vaut `null`,
**jamais 0** — même règle que le journal : un inconnu compté pour zéro rend
un total faux avec l'aplomb d'un vrai. Toute autre forme fait échouer
l'import en citant la valeur : une convention nouvelle ne se devine pas.

**Un aliment sans énergie connue n'est pas importé** : on ne saurait pas
calculer un repas avec lui. Le rapport d'import les compte et en nomme
quelques-uns.

**Un aliment disparu d'une nouvelle version est RETIRÉ, jamais supprimé**
(`retiredAt`) : il sort de la recherche, ne peut plus entrer dans un repas
(400 qui nomme son code), et les repas qui le contiennent gardent leur
instantané. La base elle-même refuse sa suppression (`MealComponent → Food`
en `Restrict`). Un aliment retiré qui revient dans une version ultérieure
est réactivé.

### La recherche

`q` de 2 à 60 caractères, `limit` de 1 à 30 (20 par défaut). Chaque mot de
`q`, normalisé comme la clé, doit figurer dans la clé de recherche ; les
aliments retirés sont exclus. Classement simple : d'abord ceux dont le nom
court **commence** par le premier mot, puis les noms les plus courts —
« riz » rend « Riz blanc, cuit » avant « Galette de riz soufflé ». Une
saisie sans lettre ni chiffre (« !! ») rend une liste vide, pas une erreur :
l'écran interroge à chaque frappe.

**Un balayage séquentiel, sans index ni extension PostgreSQL** (pas de
`pg_trgm`, pas de `unaccent`) : ~3 200 lignes se parcourent en une
milliseconde, `LIKE '%mot%'` n'utiliserait de toute façon pas un index
B-tree, et la normalisation est faite une fois, à l'import. Les mots
normalisés ne contiennent que `[a-z0-9]` : aucun joker SQL ne peut s'y
glisser, et la requête reste paramétrée.

### Charger la table : `dist/cli/ciqual-import`

**D'où vient le fichier.** La distribution officielle se télécharge sur le
site de l'Anses, [ciqual.anses.fr](https://ciqual.anses.fr/), rubrique
« Téléchargement », au format **XML** ; le même jeu est publié sur
[data.gouv.fr](https://www.data.gouv.fr/) (« Table de composition
nutritionnelle des aliments Ciqual »). C'est une archive de fichiers datés,
encodés en **windows-1252** : `alim_AAAA_MM_JJ.xml` (aliments),
`alim_grp_…` (groupes), `compo_…` (teneurs), `const_…` (constituants), et
`sources_…` dont l'import n'a pas besoin. Décompresser l'archive dans un
dossier, sans renommer les fichiers.

**La commande**, depuis l'image de l'API (ou `apps/api` après `pnpm build`) :

```bash
# 1. simulation : lit tout, compte tout, n'écrit rien
node dist/cli/ciqual-import /chemin/vers/ciqual --a-blanc
# 2. import réel, dans une seule transaction
node dist/cli/ciqual-import /chemin/vers/ciqual
```

Options : `--version <libellé>` (défaut : la date du nom de `alim_*.xml`,
« 2020-07-07 ») et `--accepter-retraits` (voir plus bas). Le raccourci
`pnpm --filter @carlys/api ciqual:import <dossier absolu> --a-blanc` fait la
même chose (sans `--` : pnpm le transmettrait tel quel ; chemin absolu : la
commande s'exécute depuis `apps/api`).

Ce que la commande garantit :

- **idempotente** : la même version rejouée ne crée ni ne modifie rien
  (« inchangés : N ») ;
- **jamais une base à moitié chargée** : un fichier introuvable (ou présent
  en deux versions), un constituant introuvable (ou en double), une teneur
  illisible, un document tronqué font échouer l'import AVANT toute écriture,
  en nommant la cause ; l'écriture elle-même tient dans une transaction, sous
  un verrou consultatif (deux imports simultanés se suivent) ;
- **pas de retrait massif par erreur** : une version qui retirerait plus
  d'un quart des aliments en service est refusée — c'est presque toujours un
  dossier incomplet ou la mauvaise distribution. `--accepter-retraits`
  l'assume, après une simulation ;
- **un rapport** : lus, créés, mis à jour, réactivés, inchangés, retirés,
  ignorés avec leur raison et des exemples, et la mention de source à
  afficher.

L'extracteur XML est écrit à la main (`infrastructure/ciqual/xml-records.ts`)
plutôt qu'emprunté à une bibliothèque : le XML CIQUAL est une table plate,
une dépendance de production pour une commande lancée une fois par version
ne se justifiait pas. Il est strict (tout ce qu'il ne comprend pas le fait
échouer avec la position fautive) et testé sur les formes du vrai fichier :
éléments vides à attributs (`<min missing=" " />`), entités (`&lt; 0,5`),
commentaires, fins de ligne CRLF, fichier tronqué. Mesuré sur une
distribution synthétique à l'échelle réelle (3 200 aliments × 67
constituants, 47 Mo) : moins d'une seconde d'analyse, 155 Mo de mémoire,
1,8 s pour le premier import complet, 5,3 s pour une nouvelle version qui
réécrit toutes les lignes.

### Pas encore validé sur le vrai fichier

Au 25 septembre 2026, le réseau de l'environnement de développement bloque
ciqual.anses.fr et data.gouv.fr : **l'import n'a tourné que sur le jeu
d'essai** (`apps/api/test/fixtures/ciqual/`, format reproduit, noms réels,
codes et valeurs ILLUSTRATIFS). Dès l'ouverture du réseau, à faire dans cet
ordre :

1. télécharger la distribution XML officielle, vérifier les URL ci-dessus ;
2. `ciqual-import <dossier> --a-blanc` sur une base de développement, et
   relire le rapport : nombre d'aliments lus (~3 200 attendus) et nombre
   d'ignorés « énergie inconnue » (une large part de la table ignorée
   signalerait un constituant mal résolu, pas des aliments sans énergie) ;
3. vérifier que les quatre noms de constituants ci-dessus existent tels
   quels dans `const_*.xml`, que l'encodage déclaré est bien windows-1252, et
   qu'aucune forme de teneur inattendue ne fait échouer l'import ;
4. comparer à la main trois aliments au site CIQUAL (poulet filet cuit, riz
   blanc cuit, brocoli cuit) ;
5. seulement alors, l'import réel sur la recette, puis la production.

### Où la brancher dans le déploiement (pas encore fait)

La commande n'est **pas** appelée par `carlysctl` ni par `deploy.sh` : à la
différence du catalogue d'exercices, la table **n'est pas livrée avec le
code** (elle n'est pas dans l'image), et son rythme est celui de l'Anses, pas
celui des déploiements. Deux branchements possibles, à trancher après la
validation ci-dessus :

- **manuel** (recommandé tant que la table n'a pas été validée) : une
  sous-commande `carlysctl ciqual-import <env> <dossier>` dans
  `scripts/server/`, sur le modèle de `catalogue_charger` (`_common.sh`) — un
  `docker compose run --rm --no-deps -T -v <dossier>:/ciqual:ro api node
  dist/cli/ciqual-import /ciqual` (la commande ne touche que la base, d'où
  `--no-deps`) ;
- **automatique** : embarquer la distribution dans l'image (données
  ouvertes, plusieurs dizaines de Mo non compressés) et ajouter une étape après « Catalogue
  d'exercices » dans `deploy.sh` ; l'idempotence rend l'étape quasi gratuite
  quand la version n'a pas bougé.

En attendant, sur un serveur : copier le dossier sur l'hôte et lancer la
même commande par `docker compose run` avec ce montage (voir
`docs/deployment/mise-en-route-serveur.md`, « La base d'aliments »). Tant
qu'elle n'a pas tourné, la recherche rend une liste vide et `meta.source.version`
vaut `null` : l'écran d'ajout doit alors proposer la saisie à la main.

## Repas composé : le serveur calcule

Un repas est **saisi à la main** ou **composé** d'aliments de la base —
jamais les deux. La maquette « Modifier ce repas » le montre : 120 g de
poulet, 150 g de riz et 50 g de brocoli font 320 g, et les calories comme
les macros découlent des aliments.

**Créer ou recomposer.** `components: [{ id, foodCode, quantityG }]`, 30
aliments au plus, 1 à 5 000 g chacun (deux décimales). `id` est un **UUID
généré sur l'appareil** à l'ajout de la ligne, puis conservé : c'est lui
qui, dans une correction, désigne une ligne déjà enregistrée. Unique dans
tout le journal (celui de la ligne d'un autre repas : 409) et dans la liste
(en double : 400). Pour une ligne NEUVE, le serveur lit la base, prend un
**instantané** de l'aliment (nom, nom court, groupe, valeurs pour 100 g,
version de la table) ; puis il calcule, en décimal exact :

- `kcal` = somme des composants, arrondie à l'entier (demi vers le haut) ;
  sous 1 kcal, 400 explicite ;
- chaque macro = somme arrondie, **ou `null` si UN composant l'ignore** ;
- `quantity` = somme des grammes, `quantityUnit` = `GRAM`.

L'arrondi n'a lieu qu'une fois, sur le total : arrondir chaque composant
puis sommer ferait dériver le total d'une calorie par aliment. Un total
calculé hors des bornes d'un repas (10 000 kcal, 1 000 g par macro,
9 999,99 g au total) est refusé comme la même saisie à la main, avec un
message qui dit quoi corriger. Un aliment inconnu ou retiré fait refuser
toute la composition (400 qui nomme le code). Le même aliment peut
apparaître deux fois (deux portions notées à part).

**Qui fait foi : jamais d'ambiguïté.** Avec des composants non vides, le
client **n'envoie pas** `kcal`, `proteinG`, `carbsG`, `fatG`, `quantity` ni
`quantityUnit` — même à `null` : 400 explicite qui nomme les champs. Sans
cette règle, l'un des deux serait ignoré en silence, et personne ne saurait
lequel.

**Corriger.**

| Corps du PATCH | Effet |
| --- | --- |
| sans `components` | la composition ne bouge pas ; `name`, `moment`, `eatenAt` se corrigent librement ; `kcal`, les macros ou la quantité d'un repas COMPOSÉ renvoyés à l'identique sont ignorés, changés → 400 (retirer la composition d'abord) |
| `components: [...]` | remplace toute la composition et recalcule tout : une ligne dont l'`id` est déjà dans le repas **garde son instantané** (même si l'aliment a quitté la base) et ne change que de quantité ou de place ; une ligne à `id` neuf lit la base (inconnu ou retiré : 400) ; un `id` existant avec un autre `foodCode` : 400 (changer d'aliment, c'est une ligne neuve) |
| `components: []` | retire la composition : le repas redevient saisi à la main et **garde ses derniers totaux** ; le même corps peut les corriger |
| `components: null` | 400 : `null` n'est pas `[]` |

Tout s'écrit dans **une transaction** : le repas et ses composants à la
création (même instruction), l'effacement de l'ancienne liste, l'écriture
de la nouvelle et les totaux en correction, sous le verrou de la ligne du
repas. Deux corrections simultanées passent l'une après l'autre, la seconde
jugée sur l'état laissé par la première. Rejouer la création d'un repas déjà
écrit (file de synchronisation) rend ce repas tel quel, SANS recomposer : un
aliment retiré entre-temps par une nouvelle version de la table ne
transforme pas un rejeu en 400.

**L'instantané fait foi.** Une nouvelle version de CIQUAL qui corrige une
valeur ne réécrit pas un repas passé : les valeurs d'un composant se
recalculent depuis SON instantané, jamais depuis la base. Corriger la
quantité d'une ligne ne relit pas la base non plus : seule une ligne NEUVE
le fait. Sans cela, passer le brocoli de 50 à 80 g après l'import d'une
nouvelle version aurait recalculé le poulet resté intact, et une cuisse
retirée de la table aurait dû quitter le repas pour qu'on puisse enregistrer
la correction : le journal serait devenu faux.

**La réponse.** Chaque repas porte `components` (vide pour un repas saisi à
la main) et `computed` (vrai quand les totaux sont calculés). Un composant :
`{ id, foodCode, name, shortName, group, sourceVersion, quantityG, kcal,
proteinG, carbsG, fatG }`, où les valeurs sont celles **du composant** (pour
sa quantité, arrondies au dixième), une macro inconnue restant `null`, et
`sourceVersion` la version de la table d'où elles viennent. `meta.source`
porte la mention à afficher près d'elles. La somme des
valeurs affichées des composants peut donc différer du total d'une unité :
c'est l'effet de l'arrondi unique, pas une erreur.

La quantité d'un repas saisi à la main reste **descriptive**, comme avant.

## Photo d'un repas (`/api/v1/nutrition/meals/:id/photo`)

Arbitrage du propriétaire, 25 septembre 2026 : la photo que la personne
prend de SON plat (bouton appareil photo de l'écran « Ajouter / Modifier ce
repas ») est **envoyée au serveur et y reste privée**. C'est un changement de
promesse : `docs/legal/privacy.md` disait qu'aucune photo n'était demandée,
la roadmap qu'une photo de repas n'était jamais stockée. Les deux sont
réécrits. La future **analyse IA** d'une photo (Plan 6, option 3) est une
autre affaire : elle reste « transmise au modèle puis jetée ».

**Les routes.** Authentifiées, réservées à la personne qui a enregistré le
repas ; repas inconnu, supprimé ou d'autrui : le même 404, pour lire, poser
ou retirer.

| Route | Effet |
| --- | --- |
| `PUT …/photo` | pose ou remplace la photo ; rend le repas, `photo.updatedAt` renouvelé |
| `GET …/photo` | les octets, `image/jpeg`, `Cache-Control: private, no-cache`, ETag fort ; 304 sur `If-None-Match` ; 404 sans photo |
| `DELETE …/photo` | 204, et 204 encore s'il n'y a plus de photo |

Le repas porte `photo: { updatedAt } | null` (la liste du journal aussi) :
c'est la clé de cache du client, qui relit les octets quand elle change. La
clé de stockage, elle, ne sort jamais de l'API.

**Ce qui est accepté.** `multipart/form-data`, champ `file`, UN fichier,
aucun autre champ (400). Le type déclaré doit être `image/jpeg` ET les octets
doivent le prouver : signature `FF D8 FF`, puis une structure que le filtre
parcourt jusqu'à la fin d'image — un PNG renommé, un JPEG tronqué ou une
variante exotique répondent 415 (`UNSUPPORTED_MEDIA_TYPE`). 5 Mio au plus
(`MEAL_PHOTO_MAX_BYTES`) : l'envoi est coupé pendant la réception, 413 en
français. Vingt dépôts par minute (limite de débit de la route). Rejouer le
même envoi (file hors ligne) ne dépose rien de plus.

**Les métadonnées sont retirées AVANT stockage** par un filtre de segments
JPEG écrit à la main (`apps/api/src/common/images/jpeg-metadata.ts`), sans
décoder ni réencoder l'image : EXIF (avec la position GPS, l'appareil, la
date), XMP, IPTC, commentaires, tous les APP1 à APP15, et tout octet après
la fin d'image (où certains téléphones rangent une seconde image et son
EXIF). Restent JFIF (vignette retirée), le profil de couleur ICC et le
segment Adobe de douze octets, qui servent à AFFICHER l'image. Un marqueur
inconnu fait refuser le fichier plutôt que de le recopier à l'aveugle.
**Conséquence pour le client** : l'orientation EXIF part avec le reste ; le
mobile redresse les pixels avant l'envoi (ce que font les compresseurs
d'image par défaut).

**Où elle vit.** Dans un bucket PRIVÉ, `S3_PRIVATE_BUCKET`, distinct du
bucket des médias du catalogue, qui est lisible sans jeton : un préfixe dans
ce dernier aurait laissé chaque photo à une clé près d'internet. Clé
`meal-photos/<userId>/<uuid>.jpg`, un UUID neuf par dépôt, jamais le nom du
fichier envoyé. Aucun vhost ne sert ce bucket. Il n'est **pas sauvegardé** :
une photo effacée ne survit nulle part (voir `scripts/server/backup.sh`).

**Effacement.**

- Remplacer une photo efface l'ancienne, APRÈS l'écriture de la nouvelle.
- Supprimer le repas efface sa photo : la ligne `MealPhoto` part dans la
  transaction de la suppression douce, l'objet juste après.
- Supprimer le compte efface TOUTES ses photos de repas : les lignes dans la
  transaction de la suppression, puis tout le préfixe de la personne dans le
  bucket, y compris un objet qu'aucune ligne ne citait plus. Les repas, eux,
  restent (historique anonyme, voir SECURITY.md), sans leur photo.

Un stockage qui ne répond pas au moment d'effacer ne fait JAMAIS échouer la
suppression, qui a bien eu lieu en base : l'échec est journalisé en ERREUR
(Pino, avec le `requestId` et la clé), et l'objet devient un **orphelin** —
plus aucune ligne ne le cite.

**Un dépôt qui croise une suppression.** Les octets partent au stockage
avant la ligne : le temps de l'envoi, la personne peut supprimer le repas,
ou son compte. La ligne `MealPhoto` ne s'écrit donc qu'après avoir relu,
sous verrou, le compte (`FOR SHARE`) et le repas (`FOR UPDATE`) ; supprimé
l'un ou l'autre, le dépôt répond 404 et l'objet neuf est effacé aussitôt.
La suppression du compte verrouille sa ligne `User` EN PREMIER : un dépôt
passé avant elle voit sa ligne effacée avec les autres, un dépôt passé après
voit le compte supprimé.

**Le rattrapage des orphelins : `dist/cli/meal-photos-sweep`.** Une seule
règle : un objet du bucket est vivant si et seulement si la ligne d'un repas
non supprimé, d'un compte non supprimé, le cite. La commande liste le
préfixe `meal-photos/`, efface le reste, et épargne les objets de moins
d'une heure (un dépôt écrit l'objet PUIS la ligne). `--a-blanc` compte sans
effacer ; elle sort en 1 si un effacement échoue. Rejouable à volonté.
**La supervision du serveur la lance une fois par jour** et alerte si elle
échoue (`scripts/server/_photos.sh`) ; à la main :
`carlysctl meal-photos-sweep <env> [--a-blanc]`
(`docs/deployment/mise-en-route-serveur.md`, « Les photos de repas »).

Une ligne dont l'objet a disparu (base restaurée sans le bucket) se répare
à la lecture : 404, erreur journalisée, et la ligne est retirée pour que le
repas cesse d'annoncer une photo illisible.

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
`apps/mobile/lib/features/nutrition/domain/nutrition_explanations.dart` : dix
entrées, chacune en trois blocs, toujours dans le même ordre. Le gabarit
(`Explanation`) et la feuille qui l'ouvre vivent dans `core/explanations/`,
parce que la progression s'en sert aussi pour expliquer ses titres.

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

`nutrition_explanations_test.dart` **lit le calculateur du serveur** et vérifie
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
  face à l'objectif, retrait d'un geste) entre le rapport métabolique et le
  profil. « Ajouter un repas » et le toucher d'un repas ouvrent l'écran plein
  décrit ci-dessous.

### L'écran « Ajouter / Modifier ce repas »

D'après la maquette du propriétaire du 25 septembre 2026. **Un seul écran**
pour ajouter et pour corriger, parce que ce sont les mêmes champs, les mêmes
bornes et les mêmes pièges. Il a remplacé la feuille de saisie
(`add_meal_sheet.dart` et ses voisins, supprimés).

| | Ajouter | Modifier |
| --- | --- | --- |
| Route (plein écran, hors coquille) | `/nutrition/repas/nouveau?jour=AAAA-MM-JJ` (`AppRoutes.newMeal`) | `/nutrition/repas/:mealId` (`AppRoutes.meal`) |
| En-tête | « Nouveau repas / NOTE CE QUE TU AS MANGÉ » | « Modifier ce repas / AJUSTE LES DÉTAILS », corbeille rouge à droite |
| Lecture | aucune : l'identifiant (UUID) naît sur l'appareil à l'ouverture | `GET /nutrition/meals/:id` : chargement, erreur (hors connexion ou panne, avec « Réessayer »), introuvable (« Ce repas n'est plus là ») |
| Bas de page | « Ajouter au journal » | « Enregistrer la modification », puis « Supprimer ce repas » (contour rouge) |

Deux portes y mènent, et une seule écriture : le journal (daté du jour qu'il
affiche : un jour passé propose midi) et la tuile Calories de l'accueil
(aujourd'hui, à l'heure qu'il est). L'identifiant d'un repas neuf naît à
l'OUVERTURE : un enregistrement raté puis rejoué part sous le même, et le
serveur ne fait pas de doublon.

**De haut en bas.**

1. La carte d'identité : la vignette du plat (la photo, lue par le GET
   authentifié ; sans elle, un dessin au dégradé violet et l'icône du
   moment, jamais une case vide ; le bouton appareil photo en surimpression,
   voir « La photo du plat » plus bas), le **nom**, le **moment de la journée**
   en quatre tuiles (petit-déjeuner, déjeuner, dîner, collation) et, en
   dessous, **le jour et l'heure** du repas (deux pastilles sobres qui
   ouvrent les sélecteurs de date et d'heure ; la maquette ne les montre pas,
   la fonction reste). Le moment d'un repas neuf, ou d'un repas noté avant
   que le moment existe, est PROPOSÉ d'après l'heure (règle plus haut) et
   s'enregistre avec le repas.
2. **Quantité** : les pastilles d'unité g | ml | portion | pièce, le champ
   « Quantité (grammes) » dont le libellé et le suffixe suivent l'unité, et
   la mention « La quantité décrit ton assiette… ».
3. **Valeurs nutritionnelles** : quatre tuiles (calories, protéines,
   glucides, lipides), chacune avec son icône et son nom dans la couleur de
   la valeur (`AppColors.nutrition*`, jetons `color.nutrition`).
4. **Aliments composant le repas** : une ligne par aliment (vignette de sa
   FAMILLE CIQUAL dans un disque violet, la table n'ayant pas de photos ; nom
   court, nom officiel, quantité, croix de retrait), le bouton pointillé
   « Ajouter un aliment » (la feuille de recherche, plus bas), et la mention
   de la base avec la version de chaque ligne (licence Etalab).

**Deux régimes, qui ne se mélangent jamais.**

- **Saisi à la main** (aucun aliment) : les tuiles sont des cases. Calories
  obligatoires (1 à 10 000), macros facultatives (0 à 1 000 g, case vide =
  « on ne sait pas », jamais zéro), quantité descriptive facultative (0,01 à
  9 999,99, deux décimales, virgule acceptée) et son unité, par paire. Les
  fautes ne s'affichent qu'après une première tentative d'enregistrement,
  sous le nom, sous la quantité et sous la grille des valeurs.
- **Composé** (au moins un aliment) : valeurs et quantité se LISENT, l'unité
  est verrouillée sur g ; « La somme des aliments du repas » sous la
  quantité et « Calculé à partir des aliments » sous les valeurs le disent. Les
  totaux affichés sont ceux du serveur tant que la composition n'a pas bougé ;
  dès qu'une ligne est ajoutée, retirée ou requantifiée, l'écran montre un
  APERÇU calculé sur l'appareil (`compositionPreview`, même règle que le
  serveur : somme des « valeur pour 100 g × grammes / 100 », une macro
  inconnue d'un seul aliment rend le total inconnu, affiché « — », arrondi
  unique à l'entier, demi vers le haut). Les valeurs pour 100 g d'une ligne
  déjà enregistrée se DÉDUISENT de ses valeurs au dixième : l'aperçu peut
  différer d'une unité du total que le serveur calculera, et c'est ce
  dernier qui s'enregistre. Toucher la quantité d'une ligne la corrige
  (popup de saisie numérique, 1 à 5 000 g) ; la ligne garde son identifiant,
  donc le serveur garde son instantané. Retirer le DERNIER aliment repasse
  en saisie à la main, cases remplies des derniers totaux.

**Ce qui part au serveur** (`meal_mappers.dart`, figé corps entier par
`nutrition_repository_http_test.dart`) : le nom, le moment et l'heure
toujours ; pour un repas composé, les lignes `{ id, foodCode, quantityG }`
et AUCUN total (le serveur refuserait) — ou rien des aliments si la
composition n'a pas bougé ; pour un repas saisi, tous les totaux, `null`
compris, et `components: []` quand il vient de perdre son dernier aliment.

**Les états.** Chargement de la lecture, erreur (hors connexion : la cause
juste ; panne : réessayer), introuvable, envoi en cours, échec de l'envoi
(popup d'erreur, l'écran reste avec tout ce qui a été saisi), date future
refusée AVANT l'envoi (« On ne mange pas demain : choisis un moment
passé. »). La suppression, par la corbeille ou par le bouton du bas, passe
par une confirmation destructive, puis revient au journal.

**Pendant l'envoi** (enregistrement ou suppression, jusqu'à 10 s de
connexion et 20 s de réception hors ligne), ce qui part est déjà figé, donc
l'écran aussi :

- **les gestes sont suspendus** : le bouton tourne, la corbeille et
  « Supprimer ce repas » se disent désactivés, et les cartes ne répondent
  plus ni au doigt, ni au lecteur d'écran, ni au clavier (le champ qui avait
  le focus le perd, le clavier se ferme). Le contrôleur ignore aussi toute
  saisie arrivée par un autre chemin. Une frappe acceptée alors ne serait ni
  envoyée ni gardée ;
- **le retour est retenu** (`PopScope`) : l'écran se referme de lui-même à
  la réponse. Et s'il a été refermé entre-temps par une navigation venue
  d'ailleurs, la réponse ne dépile rien de plus : le message s'affiche, la
  page du dessous reste ;
- **une création dont la réponse s'est perdue** (délai dépassé, coupure) a
  pu être écrite : le serveur rendrait alors, à un nouveau `POST` sous le
  même identifiant, le repas DÉJÀ écrit, sans rien réécrire, et la
  correction faite entre-temps se perdrait. Après tout échec d'une
  création, le prochain essai RELIT donc le repas (`GET …/meals/:id`) :
  absent (404), il se crée ; présent, il se corrige (`PATCH`) avec tout ce
  que l'écran montre (`components: []` compris pour un repas saisi à la
  main, qu'il ait été écrit composé ou non). Une création qui aboutit du
  premier coup ne relit rien.

**Au lecteur d'écran.** Chaque champ porte son libellé (« Nom du repas »,
« Quantité (grammes) »), lu avant sa valeur ; « Moment de la journée » est
le nom du groupe de ses quatre tuiles ; chaque titre de carte est un nœud à
lui seul (la navigation par titres ne lit plus une carte entière), et chaque
aliment se lit sur sa ligne, noms ensemble, suivis de ses deux gestes. Une
case de valeur fautive se DIT invalide, avec sa faute (« Calories : entre 1
et 10 000. ») : la couleur seule ne dit rien à qui ne la voit pas.

#### La feuille « Ajouter un aliment »

Le bouton pointillé ouvre une FEUILLE (`showFoodSearchSheet`) : un champ de
recherche, les résultats, et en pied la **mention de la base avec sa
version et son adresse**, là où l'on cherche, comme la licence l'exige
(« Source : Anses, Table de composition nutritionnelle des aliments Ciqual
(version 2020-07-07), Licence Ouverte Etalab 2.0, ciqual.anses.fr. », lue
dans `meta.source` de la réponse — rien n'est codé en dur). L'adresse
(`url`) s'écrit sans son préfixe `https://`, en texte et non en lien : la
licence demande de citer la source, pas d'y renvoyer, et un appui distrait
ouvrirait le navigateur au milieu d'une saisie.

- **La recherche** (`FoodSearchController`, un Notifier à lui) part après
  un anti-rebond (`Debouncer.search`, 350 ms) et à partir de DEUX
  caractères (la borne du serveur) ; vingt résultats par réponse. Chaque
  recherche porte un numéro de génération : une réponse dont le numéro
  n'est plus le dernier est JETÉE — une réponse lente à « riz » ne remplace
  jamais celle, plus récente, de « riz complet ». Pendant une nouvelle
  recherche, les résultats précédents restent, sous une barre de
  progression : la liste ne clignote pas à chaque mot.
- **Un résultat** : la vignette de la famille de l'aliment, son nom court,
  son nom officiel, et ses calories POUR 100 g (l'unité de la table). Toute
  la rangée répond au doigt ; le lecteur d'écran la lit d'un tenant.
- **Les états** : l'invitation à chercher (moins de deux caractères), le
  chargement, aucun résultat (« Aucun aliment pour « … » », avec « Saisir à
  la main »), hors connexion ou panne (la cause juste, et « Réessayer »), et
  la **base vide** — le serveur n'a pas encore importé la table (version
  nulle) : « La base d'aliments arrive bientôt : saisis les valeurs à la
  main. », avec « Saisir à la main », qui referme la feuille sur les cases.
- **La quantité** : toucher un résultat ouvre la popup de saisie numérique
  (`showAppPrompt`), 100 g par défaut (les valeurs de la table sont pour
  100 g), de 1 à 5 000. Renoncer ramène aux résultats ; valider referme la
  feuille, et le contrôleur de l'écran (`MealEditorController.addFood`)
  dépose la ligne sous un **UUID v4 né sur l'appareil**, qu'elle garde
  d'une correction à l'autre. Rien ne part au serveur avant
  l'enregistrement du repas.
- **Petit écran, grand texte, clavier ouvert** : sous 420 points de texte de
  hauteur, l'en-tête et la mention défilent avec les résultats au lieu de
  rester fixes — trois blocs fixes ne laisseraient plus rien à la liste.

#### La photo du plat

Le bouton appareil photo de la vignette ouvre une feuille : « Prendre une
photo », « Choisir dans la galerie », et « Retirer la photo » quand il y en
a une. La photo reste privée : routes et stockage plus haut.

- **Sur l'appareil, avant tout envoi** (`prepareMealPhoto`, pur Dart, dans
  un isolat) : la photo est **redressée** (l'orientation EXIF appliquée aux
  PIXELS — un téléphone tenu debout enregistre souvent l'image couchée avec
  une simple étiquette, que le serveur retire avec les autres métadonnées :
  sans ce redressement, le plat s'afficherait couché), **réduite** à 1 600
  pixels sur son plus grand côté (jamais agrandie), et **réencodée** en JPEG
  qualité 80 **sans aucune métadonnée** (ni position, ni appareil, ni
  date). Au-delà de 5 Mio (le plafond du serveur), la qualité baisse, puis
  la taille ; une image illisible est refusée avec sa cause.
- **Quand elle part** : à l'ENREGISTREMENT, après l'écriture du repas (la
  route a besoin d'un repas écrit) : `PUT …/photo` en multipart, un seul
  fichier « file » déclaré `image/jpeg`. « Retirer la photo » montre le
  dessin tout de suite et envoie `DELETE …/photo` à l'enregistrement.
  Renoncer à l'écran n'a rien envoyé.
- **Si l'envoi échoue** : le repas EST enregistré, et l'écran le dit
  (« Repas ajouté, mais la photo n'est pas partie… », en précisant « hors
  connexion » quand c'est la cause). L'écran reste ouvert, sur le repas
  désormais enregistré (« Modifier ce repas »), la photo toujours en vue et
  en attente : « Enregistrer la modification » corrige le repas (idempotent)
  puis renvoie la photo. Rien n'est perdu en silence. Un RETRAIT en échec
  se dit pour ce qu'il est — la photo est toujours là : « Repas modifié,
  mais la photo n'a pas pu être retirée… Touche « Enregistrer la
  modification » pour réessayer. », et le retrait reste demandé.
- **Les autres échecs se nomment** : accès refusé à l'appareil photo ou aux
  photos (« Autorise-le dans les réglages du téléphone… »), image
  illisible, appareil photo qui ne s'ouvre pas.
- **L'affichage** : les octets viennent du `GET …/photo` authentifié, par le
  dépôt (jamais depuis un widget), et se gardent EN MÉMOIRE seulement
  (`MealPhotoCache`, 12 Mio au plus, les plus anciennement vues partent)
  sous la clé (repas, `photo.updatedAt`) : une photo remplacée change de
  date, donc de clé ; rouvrir un repas ne relit pas sa photo. La photo
  qu'on vient d'envoyer y est rangée sous la date que le serveur lui donne.
  Pendant la préparation, la vignette porte un indicateur et l'enregistrement
  attend ; pendant la lecture d'une photo existante aussi (« Photo du plat,
  en chargement »). Sans photo, ou si elle ne se lit pas, le dessin violet :
  mais une photo qui existe et ne se montre pas (hors connexion, introuvable)
  se dit « Photo du plat, indisponible pour l'instant », jamais « Pas encore
  de photo », et le bouton reste « Changer la photo ».
- **Le port** : l'appareil photo et la galerie passent par
  `MealPhotoPicker` (domaine), implémenté par `ImagePickerMealPhotoPicker`
  (données). Les tests remplacent le port par un faux : aucun ne touche de
  greffon. Dépendances et permissions : `docs/development/photo-du-plat.md`.

### Le reste de l'écran Nutrition

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
  d'autrui, retraits idempotents, 404 opaque ; moment ; composition calculée
  et instantané écrit avec le repas ; ambiguïté refusée avant toute lecture
  de la base ; totaux d'un repas composé verrouillés, totaux renvoyés à
  l'identique ignorés ; composition retirée qui garde ses totaux ; décision
  prise sur l'état relu sous verrou ; 409 sur un identifiant de ligne pris.
- Unitaires du calcul et des règles : `meal-composition.spec.ts` (somme en
  décimal exact, arrondi unique demi vers le haut, macro inconnue
  contagieuse), `meal-write-rules.spec.ts` (création, correction, `null`
  compté comme envoyé, champs calculés inchangés), `meal-composer.spec.ts`
  (instantané dans l'ordre sous l'identifiant de l'appareil, inconnu et
  retiré nommés, bornes d'un repas ; ligne gardée qui conserve son
  instantané même retirée de la base, ligne neuve qui lit la base, aliment
  changé sous le même identifiant et identifiant en double refusés).
- Unitaires de l'import CIQUAL : normalisation (`food-text.spec.ts`),
  extracteur XML (`xml-records.spec.ts` : entités, éléments vides, `<` brut,
  commentaires, CRLF, fichier tronqué), teneurs (`ciqual-values.spec.ts`),
  fichiers et encodage (`ciqual-files.spec.ts`), lecture du jeu d'essai
  (`ciqual-parse.spec.ts` : constituants par le nom, renumérotés en v2),
  plan d'import (`ciqual-sync.spec.ts` : idempotence, retrait, réactivation,
  garde-fou des retraits massifs), commande (`cli/ciqual-import.spec.ts`).
- Photo d'un repas. Unitaires : filtre JPEG sur une VRAIE photo porteuse
  d'un EXIF GPS (`common/images/jpeg-metadata.spec.ts` : aucune trace de
  position, d'appareil, d'adresse ni de ville ne sort, image identique octet
  pour octet, idempotence, métadonnée cachée entre les tables ou après la fin
  d'image, vignette JFIF, APP2 et APP14 triés ; PNG, tronqué, marqueur
  réservé refusés), acceptation (`meal-photo-upload.spec.ts`), objets et
  journalisation des échecs (`meal-photo-objects.spec.ts`), service
  (`meal-photos.service.spec.ts` : 404 opaque, ordre des écritures, rejeu,
  409 et reprise de l'objet perdant, objet disparu), balayage
  (`meal-photo-sweep.spec.ts`, `cli/meal-photos-sweep.spec.ts`), stockage S3
  sur le bucket privé (`s3-private-object-store.spec.ts`), traduction des
  refus multer (`single-file-upload.spec.ts`), suppression de compte
  (`account.service.spec.ts`). e2e SANS MinIO, stockage en mémoire
  (`nutrition-photos.e2e-spec.ts`) : métadonnées retirées, clé opaque, octets
  relus, 304, 404 indiscernable, 401, 415, 413, forme de l'envoi, remplacement,
  retrait idempotent, suppression du repas, panne du stockage puis balayage,
  suppression du compte, 429 ; dépôt retenu pendant qu'on supprime le repas
  ou le compte (404, ni ligne ni objet), photo restée sous un compte
  supprimé reprise par le balayage. e2e sur le VRAI MinIO, en CI seulement
  (`nutrition-photos-minio.e2e-spec.ts`) : objet dans le bucket privé et pas
  dans l'autre, lecture anonyme refusée (403), aucune politique sur le
  bucket, effacement avec le repas et avec le compte.
- e2e API (`nutrition.e2e-spec.ts`) : ajout rejoué sans doublon, fenêtre de
  journée bornée par le client, retrait doux, validation des calories.
- e2e API (`nutrition-foods.e2e-spec.ts`, jeu d'essai chargé par le chemin de
  la commande) : recherche (classement, accents et ligatures, bornes, 401),
  repas de la maquette calculé (390 kcal pour 320 g), macro inconnue,
  ambiguïtés, aliment inconnu nommé, verrou des totaux, recomposition,
  retrait de la composition, moment, lecture d'un repas (404 indiscernable),
  nouvelle version de la table (retrait, instantané intact, rejeu sans
  effet, simulation, garde-fou des retraits massifs).
- e2e API (`nutrition-meal-corrections.e2e-spec.ts`) : identifiants de ligne
  venus de l'appareil et stables (manquant, en double, aliment changé : 400 ;
  pris par un autre repas : 409) ; `meta.source` et `sourceVersion` sur les
  routes de repas ; totaux renvoyés à l'identique par le client déjà publié ;
  correction retenue par un VERROU pendant qu'une recomposition s'écrit
  (refusée, ou retrait qui emporte la nouvelle composition) ; après l'import
  d'une nouvelle version, corriger la quantité d'une ligne d'un repas qui
  contient un aliment retiré (200, instantanés v1 intacts, ligne neuve en v2).
- Écran de repas, mobile : règles pures (`meal_rules_test` : moment
  proposé borne par borne, aperçu des totaux de la maquette et macro
  inconnue, familles CIQUAL, fautes de saisie, forme de ce qui part) ; contrat
  HTTP corps entier (`nutrition_repository_http_test` : lecture tolérante
  d'un serveur plus ancien ou plus récent, création et correction saisies ou
  composées, composition gardée, base d'aliments vide) ; écran
  (`meal_editor_screen_test`, `meal_editor_states_test` : ajout à la main,
  moment proposé puis changé, repas composé en lecture seule, retrait d'un
  aliment et correction d'une quantité, dernier aliment retiré, repas ancien
  sans moment, date future refusée, erreurs de lecture et d'envoi avec le
  même identifiant au second essai, suppression confirmée, renoncée ou en
  échec, portes du journal, grand texte sur 320 points).
- Recherche d'aliments, mobile : contrôleur (`food_search_controller_test` :
  anti-rebond, moins de deux caractères, réponse lente jetée, requête en vol
  oubliée, résultats gardés pendant la suivante, base vide, échec puis
  « Réessayer ») ; feuille (`food_search_sheet_test` : résultat, quantité,
  ligne sous un UUID v4 envoyée telle quelle, mention et version en pied,
  quantité hors bornes, base vide, aucun résultat, hors connexion, panne,
  320 points en texte doublé).
- Photo du plat, mobile : préparation sur de VRAIS octets
  (`meal_photo_preparation_test`, une photo couchée écrite par Pillow avec
  EXIF orientation 6 et position GPS : trame stockée debout, aucune
  métadonnée, 1 600 px, sous la borne même sur du bruit, PNG transparent,
  octets illisibles) ; contrat HTTP (`meal_photo_http_test` : multipart
  exact, octets du GET, 404, 500, DELETE, rejeu après un 401 qui renvoie la
  photo entière) ; cache (`meal_photo_cache_test`) ; écran avec un faux
  appareil photo (`meal_photo_test` : prise et galerie, envoi après la
  création, préparation en cours, octets du serveur lus une fois, retrait,
  échec d'envoi signalé puis rejoué, hors connexion, accès refusé, image
  illisible, renoncement).
- Widgets mobile : ajout par l'écran de repas depuis le journal et depuis la
  tuile Calories de l'accueil (total mis à jour), suppression,
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
  (`nutrition_explanations_test`, qui lit `metabolism.calculator.ts`), intégrité
  du catalogue (titres uniques, aucune explication oubliée dans `toutes`), et
  les portes elles-mêmes (`explanation_doors_test` : chaque tuile,
  chaque ligne de macro et chaque bloc du hero ouvre SON explication et
  aucune autre, « J'ai compris » referme, l'annonce au lecteur d'écran donne
  la valeur avant le mot « Explication », et chaque porte dépasse la cible
  tactile).
- Hydratation : migration 3 → 4 non destructive (`app_database_migration_test`),
  lecture du compteur sur l'accueil, feuille ouverte au tapotement de la
  cellule et écriture réellement enregistrée dans le magasin.
