# Conformité à la maquette Claude Design

La refonte de l'interface mobile est traduite depuis la maquette **« Carlys —
refonte complète »** produite par Claude Design (10 écrans, 390×844). Ce
document sert de référence quand un écart est constaté entre l'application et
la maquette : il distingue ce qui est **conforme**, ce qui est **volontairement
différent**, et ce qui **attend une fonctionnalité serveur**.

## Source de vérité

La maquette est livrée sous forme de **HTML à styles en ligne** dans le paquet
de handoff (`handoff/reference/Carlys Refonte v2.dc.html`), accompagné de
`design-tokens.md`, `components.md`, `screens.md` et `animations-3d.md`.

Ordre de priorité en cas de divergence :

1. le **code source de la maquette** (valeurs explicites : couleur, graisse,
   rayon, espacement, texte exact) ;
2. `screens.md` et `components.md` pour l'intention ;
3. les captures PNG — utiles pour l'ensemble, mais dépendantes du rendu (une
   police d'icônes non chargée y affiche les noms de glyphes en clair).

Le rendu des captures de référence exige de vendoriser Inter, JetBrains Mono et
Material Symbols Rounded : sans elles, la maquette tombe en serif et devient
trompeuse.

## Rendre la référence : deux pièges

Les captures de référence ne valent que si la maquette s'affiche vraiment.
Deux erreurs donnent une référence **fausse mais crédible** :

1. **Polices non chargées** — la maquette tombe en serif et affiche les noms de
   glyphes en clair (« check_circle »). Il faut vendoriser Inter, JetBrains Mono
   et Material Symbols Rounded et intercepter les requêtes Google Fonts.
2. **Scènes 3D absentes** — les modules ES sont bloqués par CORS en `file://`
   (le cœur et l'hélice ne se dessinent alors pas du tout, ne laissant que le
   halo violet du CSS). Il faut **servir le dossier en HTTP** et lancer Chromium
   avec WebGL logiciel :
   `--use-gl=angle --use-angle=swiftshader --enable-unsafe-swiftshader`.

Pour comparer à pose égale, activer la réduction d'animations des deux côtés
(`page.emulateMedia({ reducedMotion: 'reduce' })` côté maquette) : les scènes
rendent alors une image unique à t = 0, comme les captures Flutter.

## Les scènes 3D

Le cœur et l'hélice sont des portages **fidèles** de `pulse-heart.js` et
`dna-helix.js` : mêmes géométries, mêmes matériaux, mêmes lumières.
`lib/design_system/scenes/scene3d.dart` reproduit le modèle d'éclairage de
three.js — métallique/rugosité, spéculaire GGX, tone mapping ACES filmique,
sortie sRGB — de sorte que les couleurs tombent aux mêmes valeurs qu'en WebGL.

Deux limites assumées :

- l'éclairage est calculé **par sommet** (Flutter n'expose pas de varyings aux
  shaders de fragment) : les reflets sont un peu plus doux que dans la
  référence, d'où un maillage volontairement dense (120 × 160 pour le cœur) ;
- l'ordre des calques compte. Dans la maquette, le dégradé violet de lisibilité
  est la **première** couche CSS, donc la plus haute : posé sous
  l'assombrissement, il rend la zone nettement plus terne.

### Les particules du cœur

Ajout produit, absent de la maquette : de petites particules blanches dérivent
autour du cœur et devant lui (`lib/design_system/scenes/heart_specks.dart`).
Un point clair et son halo, rien de plus — même famille que le flux sanguin
déjà en orbite dans la scène, dont elles se distinguent en passant *de temps en
temps* et en traversant le cadre au lieu de tourner. Trois règles les tiennent :

- **un accent, pas une nuée** : chacune ne vit qu'un tiers du cycle, si bien
  qu'à un instant donné quatre ou cinq flottent au plus, sur un vivier de
  quatorze ;
- **aucun aléatoire**, comme pour le flux sanguin : tout état dérive de
  `sceneNoise`, donc le rendu est reproductible d'une image et d'un test à
  l'autre ;
- **jamais dans la masse du cœur** : la bande de profondeur qu'il occupe est
  interdite, ce qui permet de trancher entre « devant » et « derrière » par une
  simple passe avant et une passe après le maillage — un rendu sans tampon de
  profondeur ne saurait pas départager les cas intermédiaires.

Une première version leur donnait la forme d'un cristal de givre à six
branches ; écartée au profit du point blanc, qui appartient à la scène.

### Le temps des scènes

Le cœur avance désormais sur un **temps monotone** (`Ticker`), et non plus sur
un `AnimationController` rebouclé. La boucle de trente secondes ramenait le
temps à zéro alors qu'aucune période de la scène ne divise le tour — rotation
(0,22 rad/s), ballant (0,45) et battement (57 bpm, soit 28,5 battements) :
tout sautait ensemble une fois par tour. Mesuré sur la planche de contrôle
avant correction, entre la dernière image d'un tour et la première du suivant :
**6 106 pixels** changeaient d'un coup, dont **1 974** sur la silhouette même
du cœur. Un test de non-régression garde le sens du temps.

`tool/screenshots/heart_frames_test.dart` rend la scène à des instants choisis :
c'est le seul moyen de voir ce qu'une capture d'écran cache — la dérive des
particules, leur apparition en fondu, la continuité au rebouclage.

**Reste à faire** : l'hélice d'ADN (`DnaHelix`, écran Nutrition) garde le même
défaut en plus discret. Son cycle de 28,56 s vaut exactement un tour de
rotation, mais la respiration (`sin(t × 0,65)`) et la pulsation des barreaux
(`sin(t × 1,4)`) ne bouclent pas avec lui : les barreaux sautent d'un tiers de
leur cycle de luminosité une fois toutes les 28 secondes. Même correctif à
appliquer.

## Traduction, pas copie

La maquette est du **React DOM (web)**. L'application est en Flutter : le code
n'est pas réutilisable tel quel, il est *traduit*. Deux conséquences :

- les valeurs visuelles passent toutes par le design system
  (`AppColors`, `AppTypography`, `AppRadius`, `AppSpacing`, `AppMotion`,
  `AppIcons`) — jamais en dur dans un écran ;
- les formats de nombres et de dates de la maquette (« 1 840 », « 6,4 t »,
  « 82,5 », « IL Y A 4 JOURS », « LUN. 11 NOV. · 54 MIN ») sont centralisés dans
  `lib/core/utilities/formatting.dart`.

## La palette a changé : violet électrique, accent orange

Écart **assumé et global** avec la maquette d'origine, décidé au produit. La
maquette posait un indigo `#5B5BF6` et un accent lime `#C6F432` ; l'application
est passée au violet électrique `#9B30FF` et à l'orange `#FF7A45`. Le reste de
la maquette — géométrie, typographie, espacements — est inchangé.

Trois règles rendent la palette tenable, et elles sont écrites en tête de
`AppColors` :

- **l'orange est l'accent unique** — une action ou une métrique clé par écran ;
- **le magenta `#ED35A9` n'existe jamais à plat**, seulement comme transition
  à l'intérieur d'un dégradé. Posé seul, c'est lui qui fait basculer un écran
  du côté « rose » : c'est la leçon d'une première tentative où la couleur
  d'accent avait été remplacée à l'identique partout ;
- **`primaryFlash #B44DFF` ne porte jamais de texte** — mesuré à 3,86 sous du
  blanc, sous le seuil AA. Il est réservé à ce qui se remplit.

Contrastes mesurés sur le fond `#08050E` : orange 7,82 (et 8,12 sous du texte
noir), violet clair 8,28, violet primaire 4,10, texte principal 18,11.

Deux corrections sont venues de la mesure, pas de l'œil :

- les scènes 3D **codaient le lime en dur** (`0xC6F432`, huit occurrences dans
  `design_system/scenes/`), en violation de la règle « aucune valeur visuelle
  en dur » : l'hélice ADN serait restée verte après le changement de palette ;
- le dégradé de marque **n'atteignait jamais l'orange**. À parts égales, le
  magenta central occupe la moitié de la course et la dernière couleur
  n'apparaît que dans les tout derniers pixels — mangés par l'arrondi du
  bouton de bienvenue, qui finissait donc en rose. D'où les arrêts explicites
  `[0, .45, .9]`, qui donnent à l'orange un dixième de course en aplat.

## La bibliothèque a deux étages

Écart **voulu**, hors maquette : la bibliothèque s'ouvre sur une **grille des
groupes musculaires**, et la liste des mouvements ne s'affiche qu'une fois le
groupe choisi.

La maquette posait une rangée de pastilles de texte qui défilait. Douze groupes
n'y tenaient pas : trois se voyaient, les neuf autres se devinaient. La grille
les montre tous, avec pour chacun le muscle sollicité en image.

Trois règles tiennent l'écran :

- **la recherche court-circuite les deux étages** — chercher un nom ne suppose
  pas de savoir quel muscle il travaille, et aucune barre de retour n'apparaît
  alors : on n'est venu d'aucun groupe ;
- **« Tous les mouvements » existe** — la grille ne doit pas enfermer
  l'utilisateur dans un muscle pour voir un mouvement ;
- **un étage sans retour serait un cul-de-sac** : la barre au-dessus de la
  liste ramène aux groupes. `muscle_group_grid_test.dart` l'éprouve.

### Les images des groupes

Détourages anatomiques fournis par le produit (générés), embarqués dans
`assets/muscles/` : douze fichiers WebP à canal alpha, 165 Ko en tout. Ils sont
**embarqués et non servis** — ils sont douze, fixes, et doivent s'afficher hors
ligne. Les images PAR EXERCICE suivront un autre chemin : elles seront des
centaines et modifiables depuis l'admin, donc servies par le serveur.

Le nom du groupe est écrit **par l'application**, jamais gravé dans l'image :
il vient du référentiel de l'API, il se traduit, et il reste net à toutes les
tailles. L'image ne porte que l'anatomie.

**Manque aux images : `ischio-jambiers`.** La planche fournie couvre onze des
douze groupes ; elle contient une vue de face des cuisses (quadriceps) mais
aucune vue arrière. La carte s'affiche donc sans image, avec son nom — jamais
avec celle d'un autre muscle : une anatomie fausse enseignerait une erreur.

## Règle sur les données

La maquette est peuplée de données d'exemple. L'application n'affiche que des
**données réelles** : un bloc dont la donnée n'existe pas dans le domaine est
**omis**, jamais rempli d'une valeur inventée. Le mode démo (`CARLYS_FLAVOR=demo`)
fait exception, et lui seul : ses dépôts en mémoire (`lib/demo/`) servent un jeu
d'exemple pour visiter l'app sans serveur.

## La page de marque, hors maquette

La toute première ouverture affiche une **page de marque**
(`features/onboarding/presentation/screens/welcome_screen.dart`) *avant* la
première question d'onboarding : on dit qui l'on est avant de demander quoi que
ce soit. Elle ne vient pas de la maquette « refonte complète » mais d'un
**handoff Claude Design dédié**, dont les valeurs sont recopiées dans
[`welcome-screen-spec.md`](welcome-screen-spec.md) — c'est ce fichier qui fait
foi, pas le code.

Trois particularités qui ne valent **que là** :

- un **dégradé de signature** (`AppColors.signature`, violet → magenta → rose
  saumon) relevé sur le logo, déjà déclaré dans
  `packages/design-tokens/src/tokens.json` sous `color.brand.signature*`. Il
  est réservé aux surfaces de marque — il ne remplace jamais `primary`/`accent`
  dans l'application — et, sur la page, il ne peint que **deux** choses : le
  bouton et une barre du motif de progression ;
- un bouton dédié, `AppBrandButton`, qui porte ce dégradé. Ailleurs, l'action
  principale reste `AppButton` en accent — deux boutons « principaux » de
  couleurs différentes dans un même écran annuleraient la hiérarchie ;
- **Inter en graisse 300**, uniquement pour le mot CARLYS.

Toutes les autres couleurs de la spécification existaient déjà à l'identique
dans le design system (`darkBackground` `#08050E`, `darkSurface` `#15101F`,
`darkBorder` `#12FFFFFF`, `darkTextSecondary` `#9A9AAE`, `darkTextTertiary`
`#7A7A8C`, `primary` `#9B30FF`) : rien n'a été ajouté aux tokens.

Les quatre vignettes (App, Academy, Events, Wear) sont **une présentation, pas
une navigation** : seule l'application existe aujourd'hui, et les rendre
cliquables promettrait des écrans qui n'existent pas. Le motif à cinq barres
sous le credo est **purement graphique** : il ne mesure rien.

L'étape correspondante, `FirstRunStep.welcome`, précède `onboarding` dans
l'énumération : le parcours ne pouvant qu'avancer, la page ne se rejoue jamais.

### Quatre pièges de traduction CSS → Flutter

Chacun donne un rendu **faux mais crédible** — la page reste jolie, elle cesse
seulement d'être la maquette. Les trois premiers sont verrouillés par
`test/features/onboarding/welcome_fidelity_test.dart`.

1. **Sens de la perspective.** CSS pose `m[3][2] = -1/d` : un point ramené vers
   l'œil GRANDIT. L'idiome Flutter courant écrit `1/d`, qui inverse la
   profondeur. Recopié tel quel, le slogan rétrécissait vers la droite au lieu
   de s'élargir — 11 % de largeur en moins, mesuré.
2. **Ordre des ombres de texte.** CSS empile les `text-shadow` de haut en bas
   (la première déclarée est la plus haute) ; Flutter les peint dans l'ordre,
   la dernière par-dessus. La liste doit donc être **inversée**, sans quoi la
   teinte la plus sombre recouvre les autres et l'extrusion vire au noir au
   lieu de s'éclaircir près des lettres.
3. **Dégradés radiaux.** Flutter dessine un CERCLE (rayon × plus petit côté) là
   où CSS inscrit une ELLIPSE dans la boîte. Dans un cadre allongé, le halo se
   contracte en pastille. D'où `EllipticGradient`, une `GradientTransform` qui
   étire l'axe long autour du centre du dégradé.
4. **Lueurs (`drop-shadow`).** Une `BoxShadow` dessine l'ombre du CADRE : sur
   une image détourée, elle produit un rectangle coloré. La lueur fidèle est
   une copie floutée et teintée de l'image, posée dessous — elle suit l'alpha.
   C'est ce que fait `BrandGlowImage`. Les rayons de la référence sont des
   `blur-radius` CSS : l'écart-type gaussien en vaut la **moitié**.

### Le cadrage de la photographie : trois valeurs de la spec écartées

La spécification donne à la photographie `width: 62%`, `height: 100%` et
`object-position: 22% top`. Ces valeurs ont été validées sur des planches au
rapport largeur/hauteur **0,59** ; un téléphone fait **0,46**.

`BoxFit.cover` agrandit le cliché jusqu'à couvrir son cadre, en se réglant sur
la hauteur dès que le cadre est plus étroit — proportion gardée — que le cliché.
À hauteur égale, l'écran le plus étroit agrandit donc davantage et montre
**moins** de la personne : 43 % de la largeur du cliché contre 55 % sur la
planche. On y perdait la silhouette, et le logo dans le dos sortait du cadre.

La spécification tranche pourtant elle-même, au §6 : « le logo dans le dos de
l'athlète doit rester visible ». On garde donc **les exigences**, et on
reformule les valeurs en fractions d'**écran** — le seul repère qui se
transpose d'un format à l'autre, et accessoirement ce qu'on voit :

| Relevé sur la planche | Valeur |
| --- | --- |
| Part du cliché montrée en largeur | 0,55 |
| Position du logo dorsal | 0,928 de la largeur d'écran |
| Longueur du fondu du bord gauche | 0,186 de la largeur d'écran |

`AthletePhotoFraming` en déduit la largeur du cadre, le cadrage horizontal et
les bornes du fondu, pour chaque taille d'écran. Vérification après coup sur le
rendu : logo à 0,930 (planche 0,928), personne descendant jusqu'à 0,699
(planche 0,694).

**La personne passe DERRIÈRE le texte, et c'est voulu.** Le fondu avait été
reporté à 0,62 pour qu'elle ne le touche pas ; à ce compte elle disparaissait
aux deux tiers et n'était plus un grand élément de fond mais une vignette
confinée à droite. La lisibilité vient de la **plaque sombre** (couche 7) et du
**voile horizontal** (couche 4), pas de l'effacement de la photographie : les
bornes du fondu sont donc celles de la planche.

Un écart demeure, irréductible : le logo dorsal occupe 7,5 % de la largeur ici
contre 5,8 % sur la planche. C'est le rapport 0,59 / 0,46 = 1,29, exactement —
sur un écran plus étroit, à hauteur égale, tout est relativement plus large.

`welcome_fidelity_test.dart` vérifie sur cinq tailles d'écran que le logo
dorsal reste visible, que le cadrage reste un portrait, et que le fondu est
éteint partout où le texte s'écrit.

### Limite du harnais de capture

`tool/screenshots` ne sait pas choisir les graisses : `FontLoader` n'expose
aucun poids, donc la première fonte chargée sert à tous les poids et les autres
sont simulées. Les captures **sous-rendent le gras** — « TON PARCOURS. » en
24/w700 y mesure 192 px contre ~211 sur un appareil réel. Un écart de graisse
entre une capture et la référence n'est donc pas, en soi, un défaut de l'appli.

## Écarts assumés

| Écran | Écart | Raison |
| ----- | ----- | ------ |
| Tous | Barre de statut simulée (9:41, batterie) absente | Fournie par l'OS |
| Tous | **Six onglets au lieu de cinq** : Coach s'insère entre Exercices et Progrès | Écart VOULU, hors maquette : demandé au produit. Position centrale — la plus atteignable au pouce, et la fonctionnalité qu'on veut voir. L'ordre des branches du routeur EST celui de `appBottomBarItems` ; `coach_tab_test.dart` tape chaque onglet pour interdire un décalage d'index |
| Bienvenue | Écran entier absent de la maquette | Écart VOULU : planche de marque fournie par le produit, montrée avant l'onboarding |
| Accueil | Pastilles « 57 BPM » et « 7H20 » remplacées par des faits d'entraînement | Aucune donnée de santé dans le domaine |
| Accueil, Abonnement, Onboarding | **Particules blanches** dérivant autour du cœur et devant lui | Écart VOULU, hors maquette : demandé au produit ; réglé pour rester un accent (quatre ou cinq à la fois, 2 à 5 points de diamètre) |
| Accueil | **Citation du jour** en carte compacte À GAUCHE du cœur, à son niveau ; l'indice de forme est descendu près de « Ta semaine » | Écart VOULU, hors maquette : ce qu'on lit en ouvrant l'app doit motiver, pas mesurer — et le cœur, signature de l'app, ne se laisse rien poser sur sa masse |
| Accueil | **Série de constance** (L M M J V S D, flamme sur les jours tenus) sous la zone haute | Écart VOULU, hors maquette : demandé au produit, alimenté par les séances réellement terminées |
| Accueil | **Résumé du jour** en grille 2×2 : entraînement, nutrition, protéines, volume | Écart VOULU : la référence y met aussi sommeil et hydratation, que le domaine ignore — on garde la forme, jamais des chiffres inventés |
| Accueil | Maxime du jour en **Oswald SemiBold** (troisième famille, usage unique) | Écart VOULU : Inter est neutre par vocation ; la grotesque condensée des affiches de salle porte une phrase courte avec l'autorité attendue, et loge plus de signes par ligne — donc s'affiche plus grande à surface égale |
| Accueil | Pas de « prochaine séance » planifiée à une heure donnée | Aucune planification côté serveur : la carte annonce la séance du jour, pas un rendez-vous |
| Accueil | Carte « séance du jour » sans pastilles descriptives ni durée prévue | Pas de module programmes |
| Nutrition | Macros affichées en objectif, sans « consommé / objectif » | Pas de suivi des apports |
| Nutrition | Section « Repas » absente | Pas de journal alimentaire |
| Progression | Tuile « Assiduité » remplacée si la période ne permet pas le calcul | Historique insuffisant |
| Historique | Colonne « KCAL » des cartes de séance absente | Pas de dépense estimée par séance |
| Fiche exercice | Tuiles séries/répétitions/repos remplacées par les records réels | Pas de prescription par exercice |
| Fiche exercice | Jauges « muscles sollicités » = principal/secondaire | L'API expose `isPrimary`, pas un pourcentage |
| Abonnement | Cartes d'offre (annuel/mensuel), badge « 2 mois offerts » et CTA d'achat absents | Aucun catalogue de prix côté serveur |
| Profil | Lignes repos par défaut, unités, rappels, export absentes | Réglages inexistants |
| Onboarding | 3 objectifs au lieu de 4 | `NutritionGoal` n'a pas d'équivalent « gagner en force » |

## Ce qu'il faudrait côté serveur pour fermer les écarts

- **Programmes** : séance planifiée (nom, durée estimée, exercices, groupes
  musculaires ciblés) — débloque la carte « séance du jour » complète.
- **Journal alimentaire** : repas et aliments consommés — débloque la section
  « Repas » et les macros « consommé / objectif ».
- **Catalogue d'offres** : identifiants produits store, libellés, prix et devise
  localisés, mention d'économie — débloque les cartes d'offre et l'essai gratuit.
- **Données de santé** : import HealthKit / Health Connect (fréquence au repos,
  sommeil) — débloque les pastilles santé de l'accueil.
- **Dépense énergétique par séance** : estimation serveur — débloque la colonne
  KCAL de l'historique.
- **Métadonnées d'exercice** : prescription (séries/répétitions/repos) et
  activation musculaire chiffrée — enrichit la fiche exercice.
- **Projection utilisateur** : date de création du compte (« membre depuis »),
  total de séances « depuis toujours ».

## Vérifier la conformité

```bash
# 1. Rendre les cadres de référence (nécessite les polices vendorisées)
node shots.mjs                       # dans le paquet de handoff

# 2. Régénérer les captures de l'app
cd apps/mobile
flutter test tool/screenshots --update-goldens
```

Les captures de l'app sont dans `apps/mobile/tool/screenshots/goldens/` ; elles
ne sont **pas** comparées en CI (le rendu varie entre versions du moteur) et
servent uniquement à l'inspection visuelle.
