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

**Cadence adaptative** (`SceneCadence`) : la scène vise 30 i/s — au-delà, le
battement ne gagne rien de perceptible — mais sur un téléphone modeste, tenir
30 i/s faisait saccader toute la page. Le peintre rapporte le coût de chaque
image ; si la scène déborde de son budget de temps (un quart du fil
d'interface), la cadence descend à 20 puis 15 i/s, et remonte — avec marge —
quand l'appareil respire. Sur un téléphone à l'aise, rien ne change jamais.
La boucle de sommets projette par ailleurs **sans allocation**
(`SceneCamera.projectInto`) : la version précédente créait un objet par sommet,
soit des centaines de milliers d'allocations par seconde offertes au
ramasse-miettes.

**Pause au défilement** (`SceneScrollActivity`) : même à cadence réduite,
chaque image de scène vole quelques millisecondes au fil d'interface — juste
assez pour faire accrocher un défilement sur un téléphone modeste, exactement
là où la scène est visible. Les écrans à scène (accueil, nutrition,
abonnement) posent donc ce coordinateur autour de leur vue défilante : pendant
qu'on fait défiler, cœur et hélice se figent ; à l'arrêt, ils reprennent — et
le temps de scène reste monotone à travers les pauses (testé). L'**éclairage
différé** complète : seuls les sommets d'une face réellement dessinée sont
éclairés — la moitié arrière du maillage, toujours éliminée, était éclairée
pour rien à chaque image.

**Calcul en isolate** (`heart_frame.dart` + `heart_engine.dart`) : la moitié
chère du cœur — déformation, projection, tri et éclairage de ~12 000 sommets —
est une fonction **pure** (`computeHeartFrame`) exécutée dans un isolate
dédié, sur un autre cœur du processeur. Le fil d'interface ne fait plus que
dessiner des tampons prêts (`drawVertices`), soit une fraction du coût
d'avant : le défilement ne partage plus son budget avec la scène. Les demandes
se coalescent (seule la plus récente attend) : un appareil lent met le
maillage à jour moins souvent, sans jamais accumuler de retard. Le peintre
garde un **repli synchrone** — la même fonction, appelée sur place — pour la
toute première image, les tests et la planche de contrôle : mêmes
mathématiques, mêmes pixels, quel que soit le fil (testé, déterminisme
compris).

**Corrigé depuis** : l'hélice d'ADN (`DnaHelix`, écran Nutrition) avait le même
défaut en plus discret. Son cycle vaut un tour de rotation (0,22 rad/s, soit
28,56 s), mais la respiration (`sin(t × 0,65)`) et la pulsation des barreaux
(`sin(t × 1,4)`) faisaient 2,95 et 6,36 cycles par tour au lieu d'un compte
entier. Mesuré au rebouclage : la respiration sautait de **0,85 %** d'échelle
et les barreaux de **1,13 %**, d'un seul coup, toutes les 28 secondes.

Le correctif accorde les deux allures sur le tour — 3 et 6 cycles exactement —
ce qui déplace la respiration de +1,5 % et la pulsation de −5,7 %, deux écarts
qu'aucun œil ne relève. La durée du cycle n'est plus une constante recopiée
mais se déduit de la vitesse de rotation, sans quoi l'arrondi rouvrait le même
saut par la petite porte. Le tout vit dans `DnaAnimation`, séparé du rendu pour
être vérifiable : `test/design_system/scenes/dna_animation_test.dart` compare la
pose de fin de tour à celle du départ, et vérifie que les deux allures restent
des harmoniques entières — la propriété qui garantit le rebouclage si la
vitesse change un jour.

## Traduction, pas copie

La maquette est du **React DOM (web)**. L'application est en Flutter : le code
n'est pas réutilisable tel quel, il est *traduit*. Deux conséquences :

- les valeurs visuelles passent toutes par le design system
  (`AppColors`, `AppTypography`, `AppRadius`, `AppSpacing`, `AppMotion`,
  `AppIcons`) — jamais en dur dans un écran. La règle n'est plus confiée à la
  relecture : `apps/mobile/test/features/raw_colors_test.dart` balaie
  `lib/features/**` et refuse tout `Color(0x…)`, `Color.fromARGB`,
  `Color.fromRGBO` ou `Colors.<nom>`. Seul `Colors.transparent` est admis —
  ce n'est pas une couleur, c'est son absence, et le design system ne nomme
  pas le vide ;
- les formats de nombres et de dates de la maquette (« 1 840 », « 6,4 t »,
  « 82,5 », « IL Y A 4 JOURS », « LUN. 11 NOV. · 54 MIN ») sont centralisés dans
  `lib/core/utilities/formatting.dart`.

## La palette a changé : violet électrique, accent orange

Écart **assumé et global** avec la maquette d'origine, décidé au produit. La
maquette posait un indigo `#5B5BF6` et un accent lime `#C6F432` ; l'application
est passée au violet électrique `#9B30FF` et à l'orange `#FF7A45`. Le reste de
la maquette — géométrie, typographie, espacements — est inchangé.

Quatre règles rendent la palette tenable, et elles sont écrites en tête de
`AppColors` :

- **l'orange est l'accent unique** — une action ou une métrique clé par écran ;
- **le magenta `#ED35A9` n'existe jamais à plat**, seulement comme transition
  à l'intérieur d'un dégradé. Posé seul, c'est lui qui fait basculer un écran
  du côté « rose » : c'est la leçon d'une première tentative où la couleur
  d'accent avait été remplacée à l'identique partout ;
- **`primaryFlash #B44DFF` ne porte jamais de texte** — mesuré à 3,86 sous du
  blanc, sous le seuil AA. Il est réservé à ce qui se remplit ;
- **le rose `affection #FF5C9D` porte les CŒURS, et eux seuls** — l'icône
  qui signe un encouragement reçu. Un cœur n'est pas une action à faire : il
  sort de l'accent orange, qui reste la couleur des gestes de la communauté
  (ajouter un ami, encourager) comme partout ailleurs. Jamais sur une
  surface, un texte, ni un autre motif.

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

**Trois colonnes**, et non deux : à deux, six cartes seulement tenaient dans
l'écran et il fallait défiler pour découvrir la moitié du catalogue — la grille
reproduisait le défaut qu'elle corrigeait. À trois, douze des treize entrées se
voient d'un seul coup d'œil, et la vignette reste au-dessus du timbre-poste.
Le nom passe alors au corps « label » : en « subheading »,
« Ischio-jambiers » se tronquait.

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
`assets/muscles/` : **treize** fichiers WebP à canal alpha, 596 Kio en tout
(`du -sb apps/mobile/assets/muscles` — le chiffre de 165 Ko annoncé ici
auparavant était faux d'un facteur quatre, et le compte de douze d'une unité).
Ils sont **embarqués et non servis** — ils sont en nombre fixe et doivent
s'afficher hors ligne.

Ce sont des images 640 × 640, affichées à une centaine de points dans la
grille : `MuscleIllustration` reçoit donc une largeur de décodage
(`decodeWidth`) et ne matérialise plus treize bitmaps de pleine résolution
pour un rendu vingt fois plus petit. Les images PAR EXERCICE suivront un autre chemin : elles seront des
centaines et modifiables depuis l'admin, donc servies par le serveur.

**Le détourage, en trois passes.** La planche est fournie en JPEG sur fond
blanc, sans canal alpha. Un seuil binaire ne suffit pas : mesurée sur un bord,
la transition s'étale sur **six pixels** (253 → 230 → 185 → 157 → 114 → 89), et
couper au milieu garde une frange laiteuse. D'où :

1. **alpha continu** sur la bande qui borde le fond — repérée par remplissage
   depuis les bords, pour ne pas trouer un reflet clair au milieu d'une épaule ;
2. **décontamination** : le pixel observé vaut `C = α·F + (1−α)·blanc`, on
   retire la part de blanc pour retrouver `F`. Sans elle, le contour reste
   laiteux même avec le bon alpha ;
3. **extinction de la lumière de contour** : les sujets sont éclairés POUR un
   fond blanc, et ce halo se lit comme un trait sur fond sombre. Les quatre
   derniers pixels s'assombrissent progressivement — on éteint la lumière au
   lieu de découper, la silhouette reste douce.

Contrôle : sur onze des douze images, les pixels de bord sont désormais **aussi
sombres ou plus sombres** que le cœur du sujet. Le douzième (`triceps`) est à
+12 de luminance, invisible à la taille d'affichage.

Le nom du groupe est écrit **par l'application**, jamais gravé dans l'image :
il vient du référentiel de l'API, il se traduit, et il reste net à toutes les
tailles. L'image ne porte que l'anatomie.

**Plus aucun groupe sans image.** `ischio-jambiers` a longtemps manqué — la
planche d'origine n'avait qu'une vue de face des cuisses, pas de vue arrière —
et la carte s'affichait alors sans image, avec son seul nom : jamais avec celle
d'un autre muscle, parce qu'une anatomie fausse enseignerait une erreur. La
vue arrière a été livrée depuis ; `MuscleGroupCard.illustrated` liste le slug,
et `assets/muscles/ischio-jambiers.webp` existe. Ce que le code sait, et qui
fait foi contre ce paragraphe :

```bash
ls apps/mobile/assets/muscles/*.webp | wc -l
grep -c "'" apps/mobile/lib/features/exercises/presentation/widgets/muscle_group_card.dart
```

## Règle sur les données

La maquette est peuplée de données d'exemple. L'application n'affiche que des
**données réelles** : un bloc dont la donnée n'existe pas dans le domaine est
**omis**, jamais rempli d'une valeur inventée. Aucune exception : depuis le
retrait du mode démo, les seuls jeux d'exemple vivent dans les doublures de
test (`test/support/`), qui n'entrent jamais dans un binaire livré.

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
  bouton et une barre du motif de progression. Le bouton porte un texte : il
  prend donc, depuis le 24 septembre 2026, la variante `signatureInk`
  (magenta et orange assombris pour que le blanc tienne AA — voir « Contraste
  AA de tout texte clair ») ; la barre du motif garde la signature d'origine ;
- un bouton dédié, `AppBrandButton`, qui porte ce dégradé. Ailleurs, l'action
  principale reste `AppButton` en accent — deux boutons « principaux » de
  couleurs différentes dans un même écran annuleraient la hiérarchie ;
- **Inter en graisse 300**, uniquement pour le mot CARLYS.

Toutes les autres couleurs de la spécification existaient déjà à l'identique
dans le design system (`darkBackground` `#08050E`, `darkSurface` `#15101F`,
`darkBorder` `#12FFFFFF`, `darkTextSecondary` `#9A9AAE`, `darkTextTertiary`
`#7A7A8C` à l'époque du handoff — remonté depuis pour tenir AA, la valeur
courante vit dans `tokens.json`, `primary` `#9B30FF`) : rien n'a été ajouté
aux tokens.

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

## Les écrans d'entrée, refondus sur maquette (septembre 2026)

La connexion et l'inscription suivent une maquette dédiée, postérieure à la
refonte complète, et partagent la MÊME composition : le cœur de la marque en
décor haut-droite (`AuthBackdrop`), signature de marque compacte à gauche,
champs à icône intégrée et texte d'aide, bouton violet à flèche (dégradé
`cta`), entrées sociales sous un séparateur « OU ». Les deux écrans sont des
**surfaces de marque** : `AuthScaffold`
leur impose le thème sombre ENTIER — fond et textes ensemble — quel que
soit le réglage de thème ; les écrans utilitaires du même gabarit (mot de
passe oublié, changement, suppression de compte) suivent, eux, le thème
ambiant (`auth_scaffold_theme_test.dart` garde les deux règles).

Deux ajouts aux tokens pour cette maquette, gardés par
`design_tokens_test.dart` :

- le groupe **`color.vendor`** (`googleBlue/Red/Yellow/Green`), les couleurs
  officielles du « G » de Google, dessiné par `GoogleGlyph` aux angles du
  logotype — des constantes de charte TIERCE, qui ne peignent rien d'autre
  dans l'application ;
- **`color.brand.ctaStart/ctaEnd`** (`#9943FC → #7029D2`), le dégradé du
  bouton des écrans d'entrée. Les deux bornes ont été relevées AU PIXEL sur
  la maquette (bornes gauche et droite du bouton), mais **`ctaStart` ne vaut
  plus la valeur relevée** (`#A355FC`) : sous un libellé blanc, elle ne
  tenait que 3,99:1, sous le seuil AA de 4,5. Arbitrage du propriétaire, le
  24 septembre 2026 : elle a été assombrie à teinte et saturation identiques
  (HSL 268°, 96,5 %, luminosité 66,1 → 62,4 %), et tient 4,60 ; le dégradé
  ne fait que s'assombrir jusqu'à `ctaEnd` (7,15). À l'œil, le départ du
  bouton est un cran plus dense que la maquette. C'est le violet demandé par
  le produit pour « Se connecter » et « Créer mon compte », devenu celui de
  toute surface qui porte un libellé blanc (bouton principal, onglet choisi,
  avatar, médaillon des popups, bandeaux du Mentor) ; la page de bienvenue
  garde, elle, le dégradé de signature — dans sa variante sous un texte,
  `signatureInk` (voir plus bas) — : `AppBrandButton` prend le dégradé en
  paramètre plutôt que d'en imposer un ;
- **`color.brand.fieldIcon`** (`#FF9ECF`), le rose clair des icônes de
  préfixe des champs de ces écrans (enveloppe, cadenas, personne) — demandé
  par le produit, distinct du rose des cœurs (`affection`), qui reste
  réservé aux encouragements (`entry_field_icons_test.dart` le garde sur
  les deux écrans réels).

## Les métaux des ligues (arbitrage du 23 septembre 2026)

Le thème reste violet partout ; **une seule exception, bornée** : les cinq
divisions de ligue (Bronze, Argent, Or, Platine, Diamant) ont leurs couleurs de
métal. Arbitrage produit : une division porte le nom d'un métal et se reconnaît
à sa couleur avant de se lire. Jusque-là, les peindre aurait voulu dire cinq
valeurs visuelles en dur dans un écran ; ce sont désormais des jetons, gardés
par `design_tokens_test.dart` :

- le groupe **`color.league`** de `tokens.json`, reflété à la main dans
  `AppColors.league*`, **réservé au blason de division et aux couronnes du
  podium** — jamais une surface, un texte, un en-tête ni une autre
  récompense. La réserve est écrite dans les deux fichiers ;
- **trois tons par métal**, du plus clair au plus sombre : le reflet
  (`…Light`), le corps, l'ombre (`…Dark`). Un métal se peint par sa lumière ;
  en aplat, l'or n'est qu'un jaune. Le test compare les deux ENSEMBLES de clés
  (un jeton sans reflet, ou un reflet sans jeton, échoue) et vérifie que
  chaque métal s'assombrit bien du reflet à l'ombre ;
- **le corps tient 3:1 sur `darkSurface`**, le seuil d'un élément graphique
  non textuel (WCAG 1.4.11). Mesuré à la création : bronze 5,47, argent 9,14,
  or 9,34, platine 10,93, diamant 8,82 — et encore 4,61 au plus bas (bronze)
  sur `surfaceIcon`, la plus claire des surfaces sombres. L'ombre, elle,
  n'est pas garantie : sur `darkSurface` elle va de 2,05 (bronze, sous le
  seuil) à 4,04 (platine) — argent 3,04, or 3,48, diamant 3,12 —, et sur
  `surfaceIcon` seul le platine tient 3:1 (3,40). Elle ne se pose donc jamais
  seule sur le fond : elle creuse l'intérieur du blason. Un ton qui change se
  re-mesure.

Les clés sont en anglais, comme tout `tokens.json` ; `LeagueDivision` parle
français (argent = `silver`, or = `gold`, platine = `platinum`, diamant =
`diamond`). L'admin ne les recopie pas : aucun de ses écrans ne montre de
ligue, et `packages/ui/scripts/build-css.mjs` n'émet pas ce groupe, pas plus
que `color.vendor`.

## Les popups (arbitrage du 24 septembre 2026)

Demande du propriétaire, mot pour mot : « La popup du défi on peut pas faire un
vrai truc une popup qui apparaît au milieu de l’écran dans le thème de
l’application pour toutes les popup ». Il visait le bandeau clair qui
annonçait une notification reçue application ouverte (capture
`35d-notification-recue`) ; la règle vaut pour TOUTES les popups.

- **Ce qui devient une popup centrée** : les messages passagers (succès,
  erreurs, validations, notification reçue), les boîtes de dialogue Material
  (confirmations de suppression, clôture de séance, déconnexion d'un
  appareil, saisies de nom) et les confirmations présentées en feuille du bas.
- **Ce qui reste une feuille** : les menus d'options et les formulaires ou
  sélecteurs. Ce ne sont pas des popups.
- **Le thème** : une seule carte, `AppPopupCard` — surface sombre, liseré
  violet discret, halo violet sous un médaillon rond au dégradé `cta`, titre
  et message centrés, boutons du design system empilés. Violet par règle
  (CLAUDE.md, règle 9) : jamais le dégradé de marque `signature`. Le rouge
  `danger` ne teinte le médaillon que pour une ERREUR ; une question avant
  une suppression reste violette, son bouton `destructive` dit le danger.
- **Trois jetons ajoutés**, gardés par `design_tokens_test.dart` :
  `color.surface.darkScrim` (`rgba(8,5,14,0.72)`, le fond de l'application à
  72 %), le voile posé derrière une popup qui attend un CHOIX (question,
  saisie, notification avec action) — reflété dans `AppColors.darkScrim` ;
  `color.surface.darkScrimSoft` (`rgba(8,5,14,0.4)`), le voile LÉGER et
  purement visuel d'un simple message, qui détache la carte des cartes de
  l'écran et laisse passer le toucher (`AppColors.darkScrimSoft`) ;
  et `color.semantic.dangerStrong` (`#DC2626`), le rouge qui REMPLIT le
  bouton `destructive` (`AppColors.dangerStrong`). Blanc sur `danger` ne tenait que
  3,76:1, sous l'AA d'un libellé de 15 points : chaque « Supprimer »,
  « Retirer », « Quitter » des popups l'était. `dangerStrong` en tient 4,83 ;
  `danger` reste le rouge des textes et des icônes d'erreur. L'admin, qui ne
  reprend (à la main, gardé par `globals-tokens.test.ts`) que les couleurs
  qu'il peint, recopie `dangerStrong` depuis le 24 septembre 2026 : ses
  boutons de suppression avaient le même défaut (voir la section suivante).
- **Mesuré** (`app_popup_test.dart`) : titre, message et bouton de
  renonciation tiennent AA sur la surface de la carte ET au plus fort de son
  halo (`primaryBadgeBg` sur `darkSurface`), dans les deux thèmes — la carte
  impose le thème sombre à son contenu, sans quoi le bouton fantôme prendrait
  le violet vif du thème clair ; le libellé du bouton d'action, principal ou
  destructif, tient AA sur ce qui est peint sous lui (le dégradé `cta` lu aux
  deux bords du libellé, ou le rouge `dangerStrong`) ; rien ne déborde à
  `textScaler` 2 sur 320 points, pas même la pastille de constat de la
  clôture de séance (`AppPill` passe désormais à la ligne plutôt que de
  déborder d'une largeur trop étroite).

Le détail des portes (`AppNotices`, `showAppConfirm`, `showAppPrompt`,
`showAppDialog`) et de leurs règles est dans `docs/architecture/mobile.md` ;
`scripts/check_mobile_popups.sh` refuse, en local et en CI, toute popup
ouverte hors du design system, qu'elle passe par une fonction
(`showDialog`, `showCupertinoModalPopup`…) ou par une route poussée à la main
(`DialogRoute`, `RawDialogRoute`, `CupertinoDialogRoute`…).

## Contraste AA de tout texte clair sur un fond coloré (24 septembre 2026)

Demande du propriétaire : tout texte clair posé sur un fond coloré de
l'application tient l'AA de WCAG 2.2 — 4,5:1 pour un texte de taille normale,
3:1 pour une icône. Un audit, mesuré au pixel sur les captures puis revérifié,
a confirmé une trentaine de paires sous le seuil. Toutes les corrections
passent par les jetons ; les ratios sont avant → après, au pire point.

**Mobile.**

- **`ctaStart` assombri**, `#A355FC → #9943FC` (voir « Les écrans
  d'entrée ») : 3,99 → 4,60. Il suffit à lui seul pour les boutons
  principaux dont le libellé s'approche du bord clair : « Participer »
  (4,31 → 4,88), les boutons des états vides (4,26–4,39 → 4,84–4,94),
  « Créer mon compte » à l'échelle de texte iOS xxLarge (4,45 → ≥ 4,60).
- **La signature ne porte plus de texte.** Sur `signature`, AUCUN libellé ne
  tient d'un bord à l'autre : blanc 4,36 sur le magenta et 2,59 sur l'orange,
  texte sombre 3,20 sur le violet de départ. Aucune couleur de libellé ne
  pouvait donc sauver le bouton de bienvenue ni les bandeaux de
  célébration, et les repeindre en violet leur aurait retiré l'identité que
  la règle 9 de `CLAUDE.md` leur réserve. D'où une variante,
  **`gradient.signatureInk`** (`#7B1FFF → #C123DE → #D73D00`, mêmes arrêts
  `[0, .45, .9]`), assombrie par la méthode de `ctaStart` — teinte et
  saturation identiques — : blanc ≥ 4,60 sur chaque arrêt, donc sur toute
  la course. Elle devient le défaut d'`AppBrandButton` (« COMMENCER MON
  PARCOURS » : 2,70 → 4,60) et le fond des bandeaux « Nouveau titre »
  (explication 2,25 → 4,60, icône 2,59 → 4,61) et « Domaine bouclé » (croix
  2,59 → 4,61). La signature d'origine reste au logo, au motif et au fil de
  chargement, qui ne portent aucun texte. L'orange de fin du bouton de
  bienvenue est plus brûlé : **à valider sur capture** par le propriétaire.
- **Blanc PLEIN sur tout dégradé coloré.** Les surtitres et sous-titres à
  80–85 % d'opacité (Mentor, « Visite terminée », « Préparer mon
  programme », bandeaux de célébration) tombaient entre 2,25 et 3,45 ; en
  blanc plein, ≥ 4,60. La hiérarchie tient par la taille et la graisse.
- **Pastille de l'objectif** (« Préparer mon programme ») : son voile blanc à
  16 % éclaircissait le fond sous le libellé (3,38) ; elle prend l'aplat
  `ctaEnd` (7,15).
- **Voiles d'état SOMBRES.** `FilledButton.styleFrom` dérive son voile de
  survol, de focus et d'appui de la couleur du libellé : blanc, il
  éclaircissait le fond sous un texte blanc. `AppButton` principal et
  destructif prennent `overlayColor: darkBackground` (focus, avant : 3,46
  sur l'ancien départ du dégradé, 4,32 sur le rouge) ; `AppBrandButton` pose
  à l'appui un voile sombre de 8 % SOUS le libellé, au lieu d'un voile blanc
  par-dessus (4,07 avant). Les ratios d'après se lisent dans
  `contrast_pairs_test.dart`, qui les calcule état par état.
- **`AppCtaButton`, l'appel à l'action d'une barre ou d'une carte.** La
  recette « dégradé `cta` peint dans un `DecoratedBox`, `FilledButton`
  transparent dessus » vivait en CINQ copies : celle d'`AppButton`, corrigée
  ci-dessus, et quatre écrites à la main dans les écrans — « Ajouter à la
  séance » (fiche d'exercice), « Valider la série » (saisie de série),
  « Lancer » (carte de modèle), « Enregistrer » (éditeur de modèle) —,
  toutes SANS voile d'état : au bord clair du dégradé, le libellé tombait à
  4,10 au survol, 3,95 au focus et à l'appui, 3,42 sous l'éclaboussure. La
  mécanique est désormais UNE : `app_gradient_action.dart`, interne au
  design system, que partagent `AppButton` principal et le nouveau
  composant `AppCtaButton` (icône, libellé gras, halo, toute la largeur,
  hauteur réglable, état de chargement). Les quatre écrans l'emploient,
  apparence au repos inchangée : les captures `04-fiche-exercice` et
  `05-seance-active` sont identiques au pixel avant et après ; la carte et
  l'éditeur de modèle, absents de la galerie, reçoivent les mêmes réglages
  que la saisie de série. Désactivé, il retombe sur la plaque de
  la surface ; en chargement, l'indicateur de l'éditeur, peint en
  `darkBackground` sur cette plaque sombre (1,08:1), prend l'encre violette
  du thème — du thème SOMBRE, que la barre en verre impose à son contenu
  (voir « Ce qui est peint en sombre » ci-dessous) : sous le réglage Clair,
  la plaque était sinon BLANCHE sur la barre sombre.
- **Le disque « play » de l'accueil** : un `InkWell` posé à la main sur un
  `Material` transparent, au-dessus du dégradé `cta`, sans voile à lui. Il
  prenait les voiles gris CLAIRS du thème, qui pâlissaient le disque sous
  son icône blanche à l'appui (2,55 au bord du disque en clair, 2,99 en
  sombre, sous le seuil de 3:1 d'une icône). Il prend
  `AppButton.stateOverlay`, le voile sombre des boutons violets, état par
  état.
- **`AppButton` contour et fantôme, thème clair** : leur libellé en violet
  vif (`primary`) tombait sous son propre voile d'état — survol 4,22,
  focus et appui 4,08, éclaboussure 3,55 sur la page. Il s'écrit en
  `primaryDark`, et le voile devient le violet CLAIR (`primaryLight`) dans
  les deux thèmes — celui que Material dérivait déjà du thème sombre. Un
  voile tiré du violet profond ne suffisait pas : 4,20 sous l'éclaboussure.
  Ce violet profond est celui d'une page CLAIRE ; sur ce que l'application
  peint en sombre, voir le point suivant.
- **Ce qui est peint en sombre porte le thème sombre.** L'application est
  sombre par dessin : ses écrans peignent leur fond en `darkBackground`, ses
  feuilles en `darkSurface` ou `darkSurfaceAlt`, ses barres basses un verre
  sombre — sous le réglage Clair aussi. Ce qui s'y posait lisait pourtant le
  thème AMBIANT : sous le Clair, le libellé violet profond d'un « Réessayer »
  tombait à 3,35 sur la page sombre (2,53 sous l'éclaboussure), 3,09 dans
  une feuille. Choisir l'encre selon le thème ne peut pas suffire : aucun
  violet ne tient 4,5:1 à la fois sur la page claire et sur la page sombre.
  C'est donc le thème qui dit ce qui est peint : `AppDarkTheme` impose le
  thème sombre sous le réglage Clair — et ne touche à rien sous un thème
  sombre ou OLED —, et l'enveloppent tout ce qui peint en sombre :
  `AppDarkScaffold` (le `Scaffold` de chaque écran sombre, fond ET thème ;
  un balai refuse un `Scaffold` peint en `darkBackground` à la main),
  `showAppSheet`, `AppTranslucentBar`, `AppPopupCard`. Les écrans qui SUIVENT
  le réglage (connexion utilitaire, sessions, détail d'une séance) gardent
  un `Scaffold` ordinaire. Sous le réglage Clair, les cartes et barres
  d'application de ces écrans sombres, jusqu'ici claires sur fond sombre,
  deviennent sombres elles aussi.
- **`AppSegmentedTabs` et `AppInitialAvatar`** passent de `violetRamp`
  (réservé à ce qui se remplit, 3,86 à son bord clair) à `cta` : « Ligue »
  sur 360 points 4,49 → ≥ 4,60, le « W » d'une initiale 4,46 → ≥ 4,60.
- **`AppBottomBar`, onglets inactifs** : le libellé de 9 points portait la
  couleur de l'icône (3,95). La barre étant translucide, elle se mesure
  au-dessus de tout ce qui peut passer dessous — fond sombre, page claire du
  thème clair, photo blanche : libellé `darkTextSecondary`, icône
  `textMuted` (là où `iconInactive` tombait à 2,79 au-dessus d'une page
  claire). Le pire cas des deux est la photo blanche ; ses ratios ne sont
  pas recopiés ici, `contrast_pairs_test.dart` les calcule (ligne
  « AppBottomBar »).
- **`AppBadge`, thème clair** : la variante `primary` écrit en `primaryDark`
  sur une teinte à 10 % (3,85 → 5,01 sur le fond de page, 4,76 au pire sur
  la surface alternée), la variante `warning` en `neutral950` (1,83 →
  16,66). Le thème sombre est inchangé.
- **`AppButton` en chargement** : l'indicateur prenait `onPrimary`, sombre
  sur une carte sombre (1,05). Hors variante principale, un bouton en
  chargement est désactivé et n'a plus de fond à lui : l'indicateur prend
  l'encre violette du thème, mesurée sur ce qui est réellement peint — le
  pire cas est le voile gris d'un bouton plein désactivé, en thème clair,
  au-dessus du seuil de 3:1 d'une icône. Le ratio se lit dans le test, pas
  ici : ce document en a recopié un faux.

**Admin** (`globals.css`, recopié de `tokens.json`) : une ENCRE n'est plus un
APLAT. `--primary-ink` (`primaryDark` en clair, `primaryLight` en sombre : le
violet des liens tombait à 3,78 sur les surfaces sombres) et `--danger-ink`
(`dangerStrong` en clair, `danger` en sombre : 3,61 sur le fond clair)
écrivent ; `--primary` et `--danger` remplissent. `--danger-strong` remplit
les boutons de suppression sous du blanc (3,76 → 4,83), sans survol par
opacité ; `--on-accent` écrit sur la pastille « Premium », devenue un aplat
orange (2,36 → 7,46). `--muted` passe à `neutral.600` (4,04 → 6,96), et
l'indicatif des champs le prend (3,36 → 6,96). Les lignes d'exercices
supprimés et de signalements résolus ne pâlissent plus par opacité (2,17) :
elles se barrent, ou le disent dans leur colonne d'état.

**Design system web** (`packages/ui/src/styles/components.css`, rendu dans
les aperçus de `.design-sync/`) : il gardait intactes les paires corrigées
côté application et admin. Il prend la même séparation encre / aplat, par
des variables de thème tirées des jetons. Ratios au pire point, sur la
page, une carte ou la surface alternée : `--carlys-primary-ink`
(`primaryDark` en clair, `primaryLight` en sombre) écrit le bouton
secondaire (3,58 → 7,23, survol sombre) et la pastille violette, posée sur
`--carlys-primary-tint` (3,67 → 4,76 en clair, 3,17 → 5,70 en sombre) ;
`--carlys-warning-ink` écrit la pastille ambre (`neutral.950` en clair :
1,75 → 15,91) ; `--carlys-danger-ink` écrit l'erreur d'un champ
(`dangerStrong` en clair : 3,61 → 4,63) ; le bouton destructif se remplit de
`dangerStrong` (3,76 → 4,83) ; `--carlys-text-muted` passe à `neutral.600`
en clair (4,04 → 6,96 sur la page et une carte, 3,83 → 6,61 sous le
survol du bouton fantôme).

**Ce qui le garde.** `contrast_pairs_test.dart` est une TABLE : chaque ligne
pose un composant du design system dans un état (thème clair, sombre, OLED ;
repos, survol, focus, appui, éclaboussure, chargement), lit les couleurs
qu'il peint et mesure chaque paire — le bouton principal et `AppCtaButton`
contre les DEUX bords de leur dégradé, libellé et icône. Le voile d'un état
est lu sur l'`InkWell` du bouton, où Material a déjà résolu le style du
widget, celui du thème et ses défauts : un voile que personne n'a écrit est
mesuré comme les autres. Il échoue avec l'ancien `ctaStart` (3,99:1 au bord
gauche), sans le voile sombre (3,95 au focus), avec l'ancien indicateur de
l'éditeur (1,08) et avec l'encre vive du contour en clair (4,08). Sa
mécanique vit dans `test/support/contrast_table.dart`, que partage
`dark_surfaces_test.dart` : dans chaque thème, il pose le contour, le
fantôme et l'appel à l'action en chargement sur chaque surface peinte en
sombre (écran, feuille formulaire et sélecteur, barre en verre) et les
mesure contre ce qu'elle PEINT — il échoue sans `AppDarkTheme` (3,35 sur la
page sombre en clair) —, vérifie qu'`AppDarkTheme` ne touche à rien sous
un thème sombre, et refuse un `Scaffold` peint en sombre hors du design
system. `app_cta_button_test.dart` y ajoute la plaque de l'éditeur,
sombre dans les trois thèmes.
`ink_on_gradients_test.dart` pose les bandeaux des écrans et le disque
« play » de l'accueil, et mesure tout ce qu'ils écrivent contre chaque arrêt
de leur dégradé, voile d'appui compris pour le disque ; ses balais y
refusent un texte en blanc translucide sur un dégradé coloré, la signature
d'origine dans un fichier qui écrit du texte, et, hors du design system,
tout voile d'état posé SUR une boîte peinte au violet `cta` (ou à l'un de
ses arrêts) sans `overlayColor` : un bouton stylé à la main (`FilledButton`,
`ElevatedButton`, `TextButton`, `OutlinedButton`, `ButtonStyle`), ou un
`InkWell` sur un `Material` au-dessus du dégradé. La recette du bouton ne
vit plus qu'en un endroit. `app_colors_test.dart` garde les bornes
de `cta` et de `signatureInk` ; `design_tokens_test.dart` leur miroir. Côté
admin, `contrast.test.ts` mesure chaque paire employée dans les deux thèmes
et refuse les classes qui la contourneraient (`text-primary`, `text-danger`,
`text-accent`, blanc sur `bg-danger`, survol par opacité). Côté design
system web, `packages/ui/src/contrast.test.ts` lit chaque règle de
`components.css` — son encre, son fond, les variables du thème, les
jetons — et mesure la paire dans les trois thèmes : l'ancienne feuille y
échoue sur 52 paires. Côté mobile, les formules vivent dans
`test/support/contrast.dart`.

## Écarts assumés

| Écran | Écart | Raison |
| ----- | ----- | ------ |
| Tous | Barre de statut simulée (9:41, batterie) absente | Fournie par l'OS |
| Tous | **Six onglets au lieu de cinq (maquette)** : Accueil, Training, Nutrition, Progrès, Academy, Communauté | Écart VOULU. Histoire en deux temps, à ne pas confondre : le sixième onglet d'origine était le **Coach**, retiré en août 2026 parce qu'il vit dans le hub Training — cette décision-là TIENT. Le sixième onglet actuel est la **Nutrition**, ajoutée en septembre 2026 : elle était une page poussée sous Academy, donc un pilier quotidien rangé derrière « comprendre », alors que manger se décide trois fois par jour. `coach_tab_test.dart` fige les six libellés, tape chaque onglet pour interdire un décalage d'index, et vérifie dans le même test que le coach n'en est toujours pas un |
| Bienvenue | Écran entier absent de la maquette | Écart VOULU : planche de marque fournie par le produit, montrée avant l'onboarding |
| Accueil | Pastilles « 57 BPM » et « 7H20 » remplacées par des faits d'entraînement | Aucune donnée de santé dans le domaine |
| Accueil, Abonnement, Onboarding | **Particules blanches** dérivant autour du cœur et devant lui | Écart VOULU, hors maquette : demandé au produit ; réglé pour rester un accent (quatre ou cinq à la fois, 2 à 5 points de diamètre) |
| Accueil | **Citation du jour** en carte compacte À GAUCHE du cœur, à son niveau ; l'indice de forme est descendu près de « Ta semaine » | Écart VOULU, hors maquette : ce qu'on lit en ouvrant l'app doit motiver, pas mesurer — et le cœur, signature de l'app, ne se laisse rien poser sur sa masse |
| Accueil | **Série de constance** (L M M J V S D, flamme sur les jours tenus) sous la zone haute | Écart VOULU, hors maquette : demandé au produit, alimenté par les séances réellement terminées |
| Accueil | **Résumé du jour** en grille 2×2 : entraînement, nutrition, protéines, volume | Écart VOULU : la référence y met aussi sommeil et hydratation, que le domaine ignore — on garde la forme, jamais des chiffres inventés |
| Accueil | Maxime du jour en **Oswald SemiBold** (troisième famille, usage unique) | Écart VOULU : Inter est neutre par vocation ; la grotesque condensée des affiches de salle porte une phrase courte avec l'autorité attendue, et loge plus de signes par ligne — donc s'affiche plus grande à surface égale |
| Accueil | Pas de « prochaine séance » planifiée à une heure donnée | Aucune planification côté serveur : la carte annonce la séance du jour, pas un rendez-vous |
| Accueil | Carte « séance du jour » sans pastilles descriptives ni durée prévue | ÉCART FERMÉ côté serveur (module programmes livré) ; la carte reste à enrichir |
| Progression | Tuile « Assiduité » remplacée si la période ne permet pas le calcul | Historique insuffisant |
| Historique | Colonne « KCAL » des cartes de séance absente | Pas de dépense estimée par séance |
| Fiche exercice | Tuiles séries/répétitions/repos remplacées par les records réels | Pas de prescription par exercice |
| Fiche exercice | Jauges « muscles sollicités » = principal/secondaire | L'API expose `isPrimary`, pas un pourcentage |
| Abonnement | ÉCART FERMÉ : offres servies par `GET /subscriptions/offers`, achat par Stripe Checkout, gestion par le portail de facturation | Voir `subscription-purchase.md` |
| Profil | Lignes repos par défaut, unités, rappels, export absentes | Réglages inexistants |
| Profil (maquette du 23 septembre 2026) | « Mes contenus sauvegardés » absent, « Bronze » retiré de « Mes badges », pourcentage de l'objectif suivi de sa base (« du programme »), flèche de retour au lieu de la barre d'onglets | Écarts VOULUS, détaillés dans `profile.md` : aucune sauvegarde de contenu dans le domaine ; une ligue ne se reporte jamais dans le profil ; un pourcentage nomme sa base ; le profil s'ouvre en plein écran depuis l'avatar |
| Communauté, onglet Ligue (maquette du 23 septembre 2026) | Initiales au lieu de photos ; « Encore 35 points pour entrer dans le top 5 » et une jauge vers le score du 5e au lieu de « Encore 260 points pour passer Argent » sur « 240 / 500 pts » ; une ligne de barème en plus (« Et 10 pts par bonne réponse du jour à l’Academy ») ; la loupe filtre l’onglet ouvert au lieu de chercher des personnes | Écarts VOULUS, détaillés dans `community.md` : Carlys n’a pas de photo de profil ; la montée se joue au rang, aucun seuil de points n’existe ; le serveur compte aussi l’Academy ; la Communauté n’énumère personne (principes 2 et 3) |
| Défi entre amis (maquette du 23 septembre 2026) | « +150 points » remplacé par la durée ; bloc « Récompense » remplacé par « Comment ça se joue » ; pas de bouton « Ajouter des amis » ; pas de repère « Suivi en temps réel » ; initiales au lieu de photos ; statuts « À l’origine / Dans le défi / En attente » au lieu de « Initiateur / Accepté / En attente » ; photo d’haltères remplacée, en attendant, par une haltère en filigrane | Écarts VOULUS, détaillés dans `community.md` : un défi entre amis ne rapporte rien (principe 5) ; les invités se choisissent à la création ; le classement se relit, il n’est pas poussé ; pas de photo de profil ; des statuts qui ne genrent personne ; la photo n’est pas encore fournie |
| Onboarding | 3 objectifs au lieu de 4 | `NutritionGoal` n'a pas d'équivalent « gagner en force » |
| Connexion, Inscription | Le **cœur de la marque** en décor des deux écrans : à la place de la sphère de la maquette (inscription) et de la photographie d'athlète (connexion) ; devise « L'ART DE DEVENIR » conservée | Demandé (le cœur partout, même composition sur les deux écrans) ; l'identité de marque établie prime sur les éléments génériques de la planche |
| Connexion, Inscription, et tout bouton principal | Départ du dégradé violet en `#9943FC` au lieu du `#A355FC` relevé sur la maquette | Arbitrage du 24 septembre 2026 : sous un libellé blanc, la valeur relevée ne tenait que 3,99:1 (AA : 4,5). Même teinte, même saturation, un cran plus dense : 4,60 |
| Bienvenue | Bouton au dégradé `signatureInk` : orange de fin `#D73D00` au lieu de `#FF7A45`, magenta `#C123DE` au lieu de `#C42EE0` ; à l'appui, voile sombre sous le libellé au lieu de `brightness 1.08` | Aucun libellé ne tient AA sur la signature d'origine (2,59:1 sur son orange). Le logo et le motif la gardent. À valider sur capture |
| Connexion, Inscription | **Apple et Google seulement**, sans Discord — et leur toucher annonce que le fournisseur « arrive bientôt » | Demandé (deux fournisseurs) ; l'API ne propose que l'e-mail (Étape 2) : un bouton qui simulerait une connexion sociale mentirait |

## Ce qu'il faudrait côté serveur pour fermer les écarts

- ~~**Programmes**~~ — **livré** : `/api/v1/programs` et les écrans mobiles ;
  reste à enrichir la carte « séance du jour » de l'accueil.
- ~~**Journal alimentaire**~~ — **livré** : `/api/v1/nutrition/meals`, section
  « Repas » de l'écran Nutrition et kcal consommées réelles sur l'accueil.
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
