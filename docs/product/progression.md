# Profil de progression

Cinq axes, des points, un titre. Le tout dérivé des faits réels de
l'utilisateur, jamais accumulé dans un compteur.

Cible mobile : `apps/mobile/lib/features/progression/`
Manifeste et valeurs partagées : `apps/mobile/lib/core/brand/`

## Le score est DÉRIVÉ, jamais accumulé

Aucun compteur n'est incrémenté puis conservé. Le profil se recalcule à chaque
lecture, à partir de l'historique local des séances et des leçons abordées.

Ce choix règle trois problèmes d'un coup :

| Problème d'un compteur | Ce que la dérivation apporte |
| ---------------------- | ---------------------------- |
| Il dérive de la réalité au fil des bugs | Le score EST la réalité, par construction |
| Une synchronisation qui rejoue une opération compte deux fois | Rejouer ne change rien : on relit des faits |
| Il ne suit pas sur un nouvel appareil | Il se reconstruit seul depuis l'historique |

Le prix est assumé : supprimer une séance retire ses points. C'est la vérité,
et une vérité vaut mieux qu'un solde flatteur.

## Les cinq axes

Ce sont les valeurs du manifeste, et chacune répond à une question que
l'application sait trancher avec des faits qu'elle possède.

| Axe | Question | Fait mesuré | Barème |
| --- | -------- | ----------- | ------ |
| **Constance** | Reviens-tu ? | Semaines avec au moins une séance | 8 semaines observées, plein à 8/8 |
| **Maîtrise** | Comprends-tu ? | Leçons de l'Academy abordées | Rapport à une CIBLE FIXE (20 leçons), plein à la cible |

> **Pourquoi une cible fixe et non la taille du pack.** L'axe valait
> « leçons abordées ÷ taille du pack ». Étoffer l'Academy — ce que le produit
> demande, de 22 à ~80 leçons — aurait donc divisé cet axe par près de quatre
> chez chaque personne déjà inscrite, du jour au lendemain et sans qu'elle ait
> rien fait ; son titre Carlys aurait reculé avec. Un contenu qu'on enrichit ne
> reprend pas ce qui a été acquis. La cible vaut 20 et non 22 pour que la
> bascule ne puisse que faire MONTER le rapport (`n/20 ≥ n/22`) : personne ne
> perd un point au passage, et un test balaie les 22 états possibles pour le
> prouver. Si le pack tombait un jour sous la cible, c'est lui qui ferait foi —
> sinon l'axe serait plafonné pour tout le monde et « Icône » deviendrait
> inatteignable.
>
> Les RÉCOMPENSES de l'axe (« La moitié du pack », « Academy terminée »)
> restent rapportées au pack, elles : ce sont des jalons datés, inscrits une
> fois pour toutes dans un journal qui ne retire jamais rien. Qui a terminé le
> pack de 22 leçons garde son certificat ; finir un pack de 80 est un autre
> exploit, et c'est normal qu'il en demande plus.
| **Performance** | Progresses-tu ? | Volume des 4 dernières semaines contre les 4 précédentes | −20 % vide, maintien à mi-course, +20 % plein |
| **Discipline** | Tiens-tu tes rendez-vous ? | Séances closes sur séances commencées | Part des séances menées à leur terme |
| **Équilibre** | Récupères-tu ? | Séances par semaine sur 28 jours | Plein entre 2 et 4, dégressif des deux côtés |

Chaque axe vaut 200 points, soit 1000 au total.

### Deux barèmes qui méritent leur explication

**La performance mesure une TENDANCE, pas un total.** Un score au volume absolu
ferait gagner les plus lourds et les plus anciens d'avance, alors que la
promesse de la marque est de progresser depuis là où l'on est. Le maintien vaut
déjà la moitié des points : une sèche, une blessure ou un bloc léger ne vident
pas l'axe.

**L'équilibre pénalise les DEUX bords.** S'entraîner tous les jours coûte des
points. Un axe qui porte la récupération et qui récompenserait le volume
maximal contredirait la valeur qu'il mesure.

## Les titres

| Titre | Seuil |
| ----- | ----- |
| Apprenti | 0 |
| Architecte | 200 |
| Artisan | 420 |
| Maître | 650 |
| Icône | 860 |

Ils racontent un métier qui s'apprend, pas un niveau qui se farme. Le dernier
seuil reste sous le maximum : « Icône » doit être atteignable, sinon c'est une
carotte, pas un titre.

### Le titre porté, le titre gravé, le rang

Trois mots s'affichent et deux se confondent facilement.

- Le **titre porté** suit le score du moment. Le score étant dérivé, il
  redescend si la pratique s'arrête : c'est la vérité, et la masquer serait
  mentir.
- Le **titre gravé** est le plus haut jamais atteint (`highestTitleProvider`).
  C'est lui qui décide du cran de majesté et du sceau : **l'écrin ne se ternit
  jamais**, même quand les points redescendent. C'est la promesse la plus
  rassurante du système, et rien ne l'énonçait à l'utilisateur.
- Le **rang** est la position du palier sur l'échelle, la même chose écrite de
  deux façons : le chiffre romain frappé sur le sceau, et la fraction
  « n / 5 PALIERS » de la carte. Ce n'est pas un score, c'est un numéro d'ordre.

La feuille « Comprendre les titres » (`presentation/widgets/titles_explained_sheet.dart`,
ouverte depuis la carte de titre) dit tout cela à l'écran : les cinq paliers
avec leur seuil, leur sens, celui qu'on porte mis en évidence, et celui qui
reste gravé quand il est plus haut. Chaque palier ouvre son explication
complète par le mécanisme commun à toute l'application (`AppExplainable` :
la ligne entière répond, le glyphe n'est qu'un ornement).

Les identifiants d'énumération sont **gelés** : `reward_engine.dart` en dérive
les clés de journal (`titleRewardPrefix` + le nom). Renommer un titre pour le
rendre plus clair effacerait une récompense déjà obtenue. On explique les
libellés, on ne les renomme pas.

## Un seul score : la règle de non-concurrence

Le titre Carlys est le **seul score de progression personnelle**. Les ligues
(tranche 42) n’existent pas encore ; les niveaux Academy (tranche 37) sont
livrés et montrent comment tenir la règle : cinq jalons à seuils ABSOLUS
(indépendants de la taille du pack, donc jamais de recul quand le contenu
s’étoffe), un affichage sans récompense (le journal fête déjà ces
franchissements), aucun nombre que la personne « est ». Le jour où les
ligues arriveront, elles devront tenir de la même façon.

Ce n’est pas une affaire de goût. Le score est dérivé, jamais accumulé : il se
recalcule à chaque lecture depuis des faits, et ces faits sont en nombre fini.
Un deuxième système construit naïvement ne mesure donc pas autre chose, il
repèse les mêmes faits sur une autre échelle. Deux échelles pour un fait, ce
sont deux nombres à l’écran, et la personne en retient un troisième : celui de
sa propre confusion.

Deux cas sont déjà mesurables aujourd’hui.

**Un « niveau Academy » calculé sur le pack recompterait l’axe Maîtrise.**
L’axe rapporte les leçons répondues à une cible FIXE de 20, et le pack en
compte 58 (`assets/academy/pack.json`, version 4). À 20 leçons répondues,
quelqu’un lirait « Maîtrise 100 % » sur son profil de progression et « 34 % »
dans l’Academy, au même instant, pour le même travail. Pire : la cible fixe
existe justement pour qu’étoffer le pack ne reprenne rien à personne
(`n/20 ≥ n/22`, voir plus haut). Un niveau assis sur la taille du pack
réintroduirait exactement le défaut que cette cible a supprimé, puisque
doubler la taille du pack le diviserait par deux du jour au lendemain, sans
que personne ait rien fait.

**Une « ligue » assise sur la série de jours contredirait l’axe Constance.**
`computeStreakDays` (API, `modules/community/application/streak.calculator.ts`)
compte les JOURS CALENDAIRES consécutifs avec séance, dans le fuseau du
propriétaire, côté serveur. L’axe Constance compte les SEMAINES avec au moins
une séance sur les huit dernières, en local. Les deux ne réagissent pas au même
événement : trois jours sans séance ne retirent rien à l’axe tant que chaque
semaine garde la sienne, alors qu’ils remettent la série à zéro. Un classement
bâti sur la série ferait donc reculer la progression au moment précis où la
règle « aucun axe ne punit une absence » dit qu’elle ne bouge pas. Et il la
ferait reculer depuis le serveur, quand le profil est local et doit tenir hors
ligne.

### Ce que chacun a le droit d’être

| Système | Ce qu’il est | Ce qu’il lui est interdit d’être |
| ------- | ------------ | -------------------------------- |
| **Titre Carlys** | Le score de progression personnelle, dérivé des cinq axes | Il est le seul : rien d’autre ne résume la personne par un nombre |
| **Ligue** | Une comparaison SOCIALE bornée dans le temps : qui fait quoi sur une période qui se ferme, puis repart | Un état durable de la personne, un palier qui s’ajoute au titre, une échelle que l’on « monte » |
| **Niveau Academy** | Un repère de POSITION dans le contenu : où en est la lecture du pack | Une note, un pourcentage de la personne, une condition d’accès à un titre |

Les deux derniers ont le droit d’exister à côté du titre parce qu’ils ne
répondent pas à sa question. Le titre dit où en est la pratique. La ligue dit
qui fait quoi ce mois-ci. Le niveau Academy dit où en est la lecture d’un
contenu. Trois questions, un seul score.

### La règle opératoire

Quatre tests, à passer avant d’écrire le premier compteur. Un seul qui échoue
suffit à refuser l’écran.

1. **Le test du fait déjà compté.** Le fait est-il dans `ProgressionFacts`
   (jours de séance, séances commencées et terminées, volume, leçons
   répondues) ? S’il y est, un axe le pèse déjà. Le nouvel écran a le droit de
   le PRÉSENTER : le lister, le situer, le comparer. Il n’a pas le droit de le
   RENOTER.
2. **Le test de l’unité.** Un repère se dit dans l’unité de ce qu’il compte :
   « 12 leçons sur 58 », « 4 séances ce mois-ci », « 3e place sur 12 ».
   Amendement arbitré en septembre 2026 (décision produit, Academy) : un
   pourcentage a le droit d’ACCOMPAGNER ce compte quand il est une position
   dans un CONTENU et qu’il **nomme sa base** — « 63 % du pack », « 75 % du
   domaine ». C’est la base nommée qui le distingue d’une note : deux
   nombres qui disent sur quoi ils portent ne se concurrencent pas. Un
   pourcentage muet sur sa base, ou un pourcentage de la PERSONNE (« tu es à
   80 % »), reste interdit et se lit comme un score.
3. **Le test de la phrase.** Écrire la phrase que la personne lira. Si elle
   tient la forme « tu es 7 » ou « ton niveau est 12 », c’est un second score.
   « Tu es Artisan » existe déjà, et une fois suffit.
4. **Le test de la date de fin.** Une comparaison sociale porte une fenêtre qui
   se ferme, et ce qu’elle affiche meurt avec elle. Si le résultat d’une ligue
   survit à son mois et s’empile, ce n’est plus une comparaison, c’est un
   second titre.

Ce qui doit rester d’une période close relève du journal des récompenses, pas
d’un compteur parallèle : une ligue tenue se marque par une récompense datée,
gagnée une fois et jamais reprise, comme le reste de la vitrine.

### La contradiction à trancher avant d’écrire une ligue

[community.md](community.md) pose en principe non négociable que « la
progression des défis est collective, jamais un classement individuel », et le
code le tient : le serveur n’expose qu’une somme agrégée (`_sum.contribution`),
jamais la part d’une personne nommée. Or une ligue est par nature un classement
individuel, puisqu’elle ordonne des personnes.

Les deux ne se concilient pas à la rédaction. Soit le principe 5 est réécrit
pour ne porter que sur les DÉFIS, la ligue devenant un autre objet avec ses
propres garde-fous, soit la ligue ne se fait pas. Cette page ne tranche pas :
elle refuse seulement que la tranche 42 s’écrive comme si la contradiction
n’existait pas.

### Ce que « rang » désigne dans cette tranche

Le mot « rang » de la tranche 44 est la position du titre sur l'échelle, telle
qu'elle s'affiche déjà : le chiffre romain du sceau et la fraction
« n / 5 PALIERS ». **Ce n'est pas une sixième échelle.** Si une échelle de
rangs distincte devait naître un jour, elle tomberait sous la règle ci-dessus
et le compte de systèmes passerait de trois à quatre.

## Les maximes du jour

Le recueil vit dans `features/dashboard/data/quotes/<valeur>_quotes.dart` :
**cinq listes de texte, une par valeur de marque**, recomposées par
`entrelacer` dans `daily_quotes.dart`. La rotation sert une maxime de chaque
valeur, puis recommence, si bien que deux jours consécutifs n'en servent
jamais la même.

Cet ordre était tenu à la main dans une seule longue liste, et rien d'autre
qu'un commentaire n'empêchait d'y glisser une entrée isolée : l'alternance
serait tombée en silence, sur la fin du cycle seulement. `entrelacer`
**refuse** de composer des listes de longueurs inégales et dit lesquelles.
Les maximes s'ajoutent donc par cycles de cinq, une par valeur.

Rien n'est attribué à une personne réelle : ce sont des phrases maison.
Le ton est sous test (`daily_quotes_test.dart`) : quatre registres proscrits
— culpabilité, culte de la douleur, perfectionnisme, jugement du corps — avec
leurs mots-témoins. Contrainte de rédaction, pas de mise en page : la carte
d'accueil rétrécit le texte jusqu'à 15 pt puis le tronque, donc une maxime
tient en une phrase.

## Ce que la marque interdit ici

Un profil de progression est l'endroit où « exigeante mais bienveillante » se
trahit le plus facilement. Trois règles, tenues par les tests :

1. **Aucun axe ne punit une absence.** Les fenêtres glissent sur quatre à huit
   semaines : les points ne se perdent pas, ils se recalculent, et une reprise
   les fait remonter immédiatement.
2. **Aucun axe n'invente.** Sans fait, l'axe dit qu'il attend **et comment
   l'ouvrir**. Il n'affiche ni jauge vide ni « 0 », qui se lisent comme un
   échec alors qu'il n'y a simplement rien encore.
3. **Chaque axe explique son pourquoi.** Une phrase adossée à un fait
   accompagne chaque score : « 3 semaines avec séance sur les 8 dernières ».

## Où vivent les faits

Tout est **local et hors ligne**, délibérément : un profil qui disparaît dans
le métro ne vaut rien.

| Fait | Source |
| ---- | ------ |
| Séances terminées et abandonnées, volume par séance | Drift, via `watchHistory()` |
| Leçons abordées | Préférences locales, `AnsweredLessonsStore` |
| Taille du pack | Asset embarqué `assets/academy/pack.json` |

Les réponses de quiz partent déjà au serveur pour les défis culturels, mais cet
envoi est en **écriture seule** : aucun endpoint ne les relit. La copie locale
n'est donc pas un confort, c'est la seule source lisible. Le jour où l'API
exposera la lecture, ce dépôt deviendra un cache sans que le moteur de calcul
bouge, puisqu'il ne connaît qu'un nombre.

Le dépôt local retient l'identifiant de la leçon **et le choix retenu**, mais
jamais le nombre d'essais. Le choix ne sert QU'À L'AFFICHAGE : la même question
paraît sur l'accueil et dans sa catégorie de l'Academy, et rouvrir la carte doit
montrer la réponse qui a été donnée, pas la bonne — laisser croire à une
réussite après une erreur serait réécrire l'histoire du côté flatteur.

Le score, lui, ne connaît que le NOMBRE de leçons abordées. Ni la justesse, ni
les essais n'entrent dans le calcul : se tromper fait apprendre, et compter les
échecs transformerait l'Academy en carnet de mauvaises notes.

## Découpage

| Fichier | Rôle |
| ------- | ---- |
| `domain/progression.dart` | Les types : axes, titres, profil |
| `domain/progression_engine.dart` | Le barème, fonction PURE (le jour entre par paramètre) |
| `domain/progression_facts_builder.dart` | Historique local vers faits, fonction pure |
| `presentation/controllers/` | Le seul endroit qui lit l'horloge et les providers |
| `presentation/widgets/majesty.dart` | Les cinq crans de fabrication, sans leur contenu |
| `presentation/widgets/majesty_plate.dart` | La plaque : surface, filet, grain, équerres |
| `presentation/widgets/award_seal.dart` | Le sceau posé dans la page, à deux tailles |
| `presentation/widgets/seal_painter.dart` | Un peintre paramétré pour les cinq silhouettes |
| `presentation/widgets/seal_size.dart` | Les deux tailles et le seuil des ornements, tenus hors des deux |
| `presentation/widgets/award_cards.dart` | Les récompenses gagnées, en deux densités |
| `presentation/widgets/upcoming_award_row.dart` | Celle qui reste à gagner : une invitation |
| `presentation/widgets/progression_body.dart` | L'écran d'un compte qui a déjà travaillé |
| `presentation/widgets/first_steps_body.dart` | L'écran du premier jour |
| `domain/title_explanations.dart` | Ce que chaque titre VEUT DIRE : le contenu, jamais le calcul |
| `presentation/widgets/titles_explained_sheet.dart` | L'échelle entière, ouverte depuis la carte de titre |

Les explications de titres remplissent le gabarit partagé
`core/explanations/explanation.dart` (ce que c'est, d'où ça sort, ce que ça ne
dit pas) et s'ouvrent par `core/explanations/explanation_sheet.dart`, les
mêmes que la nutrition. Ce gabarit vivait sous `features/nutrition/` ; l'y
laisser aurait obligé la progression à dépendre d'une autre fonctionnalité, ou
pire, à s'en recopier une deuxième version.

Cette coupure permet de tester le barème sans base de données, et la lecture
sans barème.

## Les récompenses : la deuxième mémoire

Le profil est dérivé et **fluctue** : il monte quand on s'entraîne, il
redescend quand on s'arrête. C'est l'état du moment, et il doit rester
honnête.

Les récompenses, elles, forment un **journal**. Une médaille obtenue le reste
pour toujours, même après trois mois d'arrêt, même si le fait qui l'a value
est sorti de la fenêtre d'observation. La dérivation ne fait qu'**ajouter** :
elle ne retire jamais rien.

C'est la réponse exacte à la règle de marque « la progression doit rester
positive après une interruption ». Ce qui bouge est le présent ; ce qui est
gagné est l'histoire, et l'histoire ne se reprend pas.

| Forme | Ce qu'elle marque | Exemples |
| ----- | ----------------- | -------- |
| **Badge** | Un premier pas | Cinq leçons, dix séances, premier record |
| **Médaille** | Un cap tenu | Un mois sans lâcher, cinquante séances |
| **Certificat** | Un engagement long | Une saison entière, Academy terminée |
| **Record personnel** | Une charge jamais atteinte | Servis par l'API, affichés dans Progrès |
| **Titre** | Un palier du profil | Architecte, Artisan, Maître, Icône |

La **citation du jour** figurait dans ce tableau. Elle n'y avait pas sa place :
une récompense se gagne, s'inscrit au journal et ne se reprend pas, alors
qu'une maxime tourne pour tout le monde selon le jour civil. `RewardKind` ne
la connaît d'ailleurs pas (badge, médaille, certificat, record, titre), et
rien ne la journalise. Le recueil est décrit sous « Les maximes du jour ».

Le catalogue (`domain/reward_engine.dart`) compte **quinze paliers** — deux à
quatre par valeur de marque — auxquels s'ajoutent les **quatre titres**, qui
s'inscrivent au journal le jour où ils sont atteints.

Chaque récompense porte son **histoire** : une récompense sans phrase n'est
qu'une pastille.

### Deux garde-fous du catalogue

**La meilleure série est un RECORD, pas la série en cours.** Une série cassée
reste gagnée — c'est ce qui distingue une récompense d'un score.

**Un pack d'Academy vide n'accorde pas le certificat.** Zéro leçon sur zéro
vaut « tout fait » en arithmétique, et c'est faux : le pack n'est simplement
pas chargé.

### Le journal

`RewardLedger` (préférences locales, clé `progression.recompenses`) associe
chaque identifiant à sa date de **première** obtention. Il ne s'écrit qu'en
ajout. La date ne se réécrit jamais : regagner un cap ne réécrit pas
l'histoire.

Les identifiants sont **stables** : les renommer ferait disparaître une
récompense déjà obtenue, ce qui est interdit.

## La mise en scène

L'écran est **un atelier, pas un jeu**. Il montre ce que le travail a déposé :
un titre porté, des récompenses gagnées, cinq axes qui mesurent la pratique.
Pas de confettis, pas de « niveau 12 », pas de barre d'XP, pas de coffre.

### Les cinq crans de majesté

**La majesté monte avec le titre** (`Majesty`), et chaque cran ajoute un
élément de **fabrication**, jamais seulement une couleur :

| Cran | Titre | Fabrication ajoutée |
| ---- | ----- | ------------------- |
| I | Apprenti | Surface **nue**, aucune bordure. Total `—`, jauge en tirets |
| II | Architecte | **+ filet** : bordure blanc 7 %, jauge pleine |
| III | Artisan | **+ cadre gravé** : la surface passe en `surfaceAlt`, le nom prend le Display |
| IV | Maître | **+ coins et guillochage** : fond radial, équerres, jauge en dégradé |
| V | Icône | **+ plaque bordée** : bordure d'un pixel en dégradé, halo, quatre équerres |

La montée doit se lire d'un coup d'œil sur cinq plaques vides — d'où la
coupure entre `MajestyPlate` (la fabrication) et `TitleCard` (ce qu'on lit
dessus). Le premier cran ne brille pas : sinon il ne resterait rien à gagner.

Le cran suit le titre le plus haut **jamais atteint**, pas le titre courant :
personne ne doit voir son écran se ternir parce qu'il a été malade deux
semaines.

### Les cinq sceaux

Un sceau (`AwardSeal`) est une **silhouette**, pas une pastille colorée :
écu pour un badge, disque à ruban pour une médaille, feuille cachetée pour un
certificat, plaque pour un record, cartouche octogonale pour un titre. La
forme porte le sens ; distinguer les récompenses par leur teinte donnerait
cinq ronds qu'on ne saurait pas nommer.

Construction constante : la silhouette est remplie du dégradé, puis la MÊME
silhouette, insérée de deux points, est remplie de la surface — le filet naît
de la différence, comme sur un sceau frappé. Deux tailles seulement (56 et
34) ; à 34 les ornements internes disparaissent.

### Jamais une jauge vide, jamais un « 0 »

Un total nul s'écrit `—`, une piste sans remplissage passe en **tirets**, et
un axe sans donnée dit `EN ATTENTE` avec la phrase qui explique comment
l'ouvrir. Un zéro et une barre vide se lisent comme un échec là où il n'y a
que du temps devant soi.

### Une seule couleur d'accent par écran

L'orange n'apparaît **qu'une fois** : la pastille `NOUVEAU` sur un compte
avancé, le bouton d'amorce sur un compte neuf. Jamais les deux. Le magenta ne
sert qu'en fin de dégradé et comme cachet de certificat.

### Les quatre micro-animations

| Animation | Où | Règle |
| --------- | -- | ----- |
| **La frappe** | Une récompense nouvelle | Le sceau arrive trop grand, se resserre d'un coup sec, l'onde s'échappe (`EngravedSeal`). Ne rejoue JAMAIS : c'est le journal qui en décide |
| **La flamme** | Série de constance, accueil | Respire tant que la série tient, immobile sinon |
| **Le tracé** | Graphiques (`AppRevealSweep`) | La courbe se découvre du plus ancien vers aujourd'hui, par un clip et non une reconstruction |
| **Le cap franchi** | Nouveau titre | Un bandeau se déplie, une fois, le jour de l'inscription |

Toutes passent par `AppMotion.resolve` : la réduction d'animations système
les rend immobiles, sans rien retirer de l'information.

### Où le système se voit

| Écran | Ce qu'il montre |
| ----- | --------------- |
| **Accueil** | Le bloc compact : titre, points, jauge, sceau de la dernière récompense |
| **Progrès** | Le même bloc, puis la vitrine et les records |
| **Profil de progression** | Le cap franchi, la carte de titre, la vitrine, les cinq axes, le manifeste |

L'écran **Progrès** a lui aussi deux visages. Quand ses trois sources ont
répondu sans rien (aucune séance sur la période, aucun record, aucune
mesure), il rend un seul bloc d'amorçage (`ProgressFirstSteps`, sur le
modèle de `FirstStepsBody`) à la place de trois états vides empilés et de
deux tuiles à zéro : une séance à lancer, ou son poids à noter sans quitter
l'écran. Une période vide sur un compte actif garde son état vide, avec
« Lancer une séance » et sans tuiles dessous. Une seule mesure de poids
s'affiche comme un fait (« Une mesure de plus et la courbe apparaît. ») :
la courbe demande deux points, et le dit.

### La vitrine, en trois densités

Neuf lignes identiques devenaient un mur : personne ne lisait après la
troisième, et la neuvième médaille dévaluait la première. La plus récente
passe donc en **vedette** (`FeaturedAwardCard`, sceau 56), les deux suivantes
en **lignes** (`AwardRow`, sceau 34), et le reste se compte dans l'en-tête
(« Voir les 13 », qui ouvre une feuille).

Elle mélange **deux sources** : le journal local (`earnedRewardsProvider`) et
les **records du serveur**, réunis par `showcaseRewardsProvider`. Le journal
raconte les caps, les records racontent les gestes — un profil qui n'afficherait
que les caps dirait « cinq records battus » sans jamais dire lesquels. Hors
ligne, la vitrine se replie sur le journal seul et rien de gagné ne disparaît.

### Deux visages, une seule décision

Sans aucune récompense **et** sans le moindre point, l'écran rend l'atelier du
premier jour (`FirstStepsBody`) : trois blocs au lieu de cinq, une seule
action, aucune vitrine. Un compte neuf n'a rien à montrer, il a une porte à
ouvrir — l'écran du débutant doit donc être plus court, pas plus bavard.

Les **deux** conditions comptent : un compte arrêté trois mois retombe à zéro
point tout en gardant son journal, et lui servir l'écran du premier jour
effacerait son histoire.

## Le manifeste

`ManifestoScreen` (route `/manifeste`) affiche le texte de marque et les cinq
valeurs qu'il fonde. Il n'affiche **aucun point** : les valeurs y sont
expliquées, elles sont mesurées ailleurs. Un manifeste qui afficherait un score
cesserait d'être un manifeste.

Entrées : le profil (« Le manifeste ») et le bas du profil de progression
(`ManifestoTile` — « Le manifeste Carlys »). L'écran ferme ainsi sur la
question plutôt que sur un score.
