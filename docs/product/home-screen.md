# Écran d'accueil

L'accueil répond à une seule question : **qu'est-ce que je fais aujourd'hui,
et où j'en suis ?** C'est le premier écran après l'ouverture et le plus vu de
tous — refondu en août 2026 d'après le handoff de design.

## Trois surfaces, et rien d'autre

La version précédente empilait neuf cartes de densité quasi identique,
séparées du même écart : un mur où rien ne ressortait, et où l'action
principale arrivait au quatrième bloc, sous le pli.

L'écran ne garde désormais que **trois surfaces** — l'état du jour, la séance
à lancer, ce que Carlys a retenu pour toi. Tout le reste vit **à même le
fond**, ouvert par une barre de titre dont le filet court jusqu'au bord droit.

| Ordre | Section | Surface | Composant |
| ----- | ------- | ------- | --------- |
| 1 | Zone haute : cœur, en-tête, citation | non | `HomeHero` |
| 2 | Série de constance | non | `ConsistencyStreak` |
| 3 | Aujourd'hui, ou son amorçage | **oui** | `TodayGrid` / `TodayPrimer` |
| 4 | Séance du jour | **oui** | `TodayWorkoutCard` |
| 5 | Ton titre | non | `TitleSummary` |
| 6 | Pour toi | **oui** | `ForYouCard` |
| 7 | Question du jour | non | `QuizCard` |
| 8 | Forme du jour | non | `DailyFormBlock` |

Rythme vertical de 26 entre sections, gouttière latérale de 22.

### La barre de titre se MESURE

`SectionTitleBar` mesure son libellé avant de composer sa rangée. Ce n'est pas
de la coquetterie : rendus tous deux flexibles, le libellé et le filet se
partagent l'espace libre à parts égales et « SÉRIE DE CONSTANCE » se tronque
alors qu'il reste de la place à côté. Pris à sa taille naturelle, le libellé
déborde dès qu'une police de repli est plus large que la nôtre. On mesure donc
le texte, on lui donne ce qu'il demande dans la limite du disponible, et le
filet prend le solde.

## Un seul aplat orange

Le **disque de lecture** de la séance du jour, et lui seul. Les autres signes
d'accent — la flamme de la série, le cran courant de l'échelle de forme —
restent des points, jamais des surfaces. La règle de marque « une seule
couleur d'accent par écran » était violée trois fois par la version
précédente.

Le disque est un **nœud de sémantique à part entière** (`container: true`) :
sans cela son annotation se fond dans le bloc de texte de la carte, et le
lecteur d'écran ne propose plus de bouton à activer.

## Aujourd'hui : ce qui est fait, ce qui était visé, ce qu'il reste

Une valeur seule ne dit rien — « 654 kcal » n'est ni bon ni mauvais tant qu'on
ignore la cible. Chaque cellule affiche donc les trois, et la règle qui en
découle : **une mesure sans cible connue n'affiche pas de jauge remplie**.
Elle passe en tirets, comme un axe de progression sans fait.

| Mesure | Fait | Cible | Provenance |
| ------ | ---- | ----- | ---------- |
| Calories | journal du jour | métabolisme | serveur |
| Protéines | journal du jour | métabolisme | serveur |
| Hydratation | compteur du jour | métabolisme | **local** (Drift) |
| Volume | historique local | **semaine précédente** | local |

Trois arbitrages méritent leur explication.

**Une journée qui commence n'est pas une journée en retard.** À zéro, la note
n'annonce pas ce qu'il « reste » : le reste vaut alors la cible entière, et le
répéter sous la jauge sonne comme un reproche avant l'effort. La cellule
montre « 0 / 2 759 kcal » et dit « à toi de jouer ». Ce n'est pas une nuance
de copie : c'est la différence entre un tableau de bord qui accuse et un
tableau de bord qui attend.

**L'eau bue se compte sur l'appareil, et nulle part ailleurs.** La cible vient
du serveur (`MetabolismTargets.waterMl`), le consommé d'une table Drift à une
ligne par jour (`LocalWaterIntakes`, schéma 4). Aucune synchronisation : un
verre d'eau n'a pas d'histoire à raconter à un autre appareil, et une file de
synchronisation pour un entier remis à zéro chaque nuit coûterait plus qu'elle
ne rapporte. La cellule est la seule de la grille à être **tapotable** : elle
ouvre une feuille (`+ 25 cl`, `+ 50 cl`, retrait d'un verre) plutôt que
d'incrémenter sous le doigt — ajouter de l'eau par mégarde depuis l'accueil
serait pénible à défaire, et le retour arrière doit être aussi accessible que
l'ajout.

**La cible de volume est la semaine précédente.** Aucun objectif de tonnage
n'existe dans le domaine, et il n'y a pas de barème universel. La seule
référence que l'application possède — et la seule qui ait un sens — est
soi-même la semaine d'avant. Sans semaine précédente, la cellule montre le
volume et sa portée, sans jauge remplie.

### Sans profil, la grille cède la place

Tant qu'aucun métabolisme n'est calculé, trois cellules sur quatre n'ont pas
de cible : la grille ne montrerait que des tirets — quatre fois la même
absence, sans jamais dire comment en sortir. `TodayPrimer` prend alors sa
place : une invitation unique, qui nomme ce qui manque et mène au profil
nutritionnel. Le bloc disparaît de lui-même dès que le profil est rempli ;
c'est un état de départ, pas une carte de plus.

## La forme du jour n'est pas une mesure de santé

C'est la part de l'objectif hebdomadaire déjà faite, dite en français. Un
« 40 » en chiffres de 62 points ne disait ni sur quoi il portait, ni s'il
était bon.

L'échelle graduée le remplace : vingt crans, dont **un seul est allumé** — le
cran courant, plus haut que les autres. Trois bandes nommées le situent
(repos, charge juste, surcharge), et une phrase dit d'où vient la lecture. La
copie ne promet jamais autre chose que ce que l'application sait : des
séances terminées, comptées.

## La citation n'est plus une carte

Un cadre autour d'une phrase en faisait une rubrique de plus, à moitié vide
les jours où la maxime est courte. Un simple **filet vertical** suffit à dire
« ceci est une citation » — la marque du bloc cité, vieille comme la
typographie, et qui ne creuse jamais. Le corps s'ajuste entre 15 et 21 : les
maximes vont du simple au double en longueur.

## Le cœur ne se touche pas

La scène 3D de la zone haute reste **exactement** ce qu'elle était : 330 × 330
posée à 64 du haut, débordant de 126 à droite, opacité 0,90, fondu vertical
aux arrêts 0 / 16 / 46 / 76 %. Le handoff la remplaçait par un cœur SVG :
c'était un bouche-trou de maquette, le navigateur ne sachant pas rendre la
scène de l'application.

Seuls ses **voiles** ont bougé, pour que le texte tienne le contraste AA
par-dessus : le voile vertical s'assombrit plus tôt, le latéral s'étend plus
loin.

## Ce que l'écran fait payer au démarrage

L'accueil lit désormais les **modèles de séance** (pour en donner le nombre)
et les **records personnels** (pour nommer la dernière récompense). Ces
lectures partent au réseau : tout harnais de test qui rend l'accueil doit donc
fournir ses dépôts factices, sinon un minuteur reste en vol après la fin du
test.

C'est un piège qui s'est déjà refermé trois fois sur ce dépôt. L'écran étant
plus dense qu'avant, la liste paresseuse atteint des sections qu'elle
n'atteignait pas — et réveille des lectures qui dormaient.

## Découpage

| Fichier | Rôle |
| ------- | ---- |
| `presentation/screens/home_screen.dart` | L'ordre des sections, et rien d'autre |
| `presentation/widgets/section_title_bar.dart` | La barre de titre mesurée |
| `presentation/controllers/dashboard_controllers.dart` | Constance, sous-titre, lecture de forme |
| `presentation/controllers/today_metrics.dart` | Les quatre mesures, prêtes à afficher |
| `presentation/widgets/today_grid.dart` | La grille 2×2 et ses cellules |
| `presentation/widgets/today_gauge.dart` | La jauge d'une cellule (pleine, ou en tirets) |
| `presentation/widgets/today_primer.dart` | L'amorçage, tant qu'aucune cible n'existe |

Les contrôleurs formatent : l'écran ne calcule ni n'arrondit rien.
