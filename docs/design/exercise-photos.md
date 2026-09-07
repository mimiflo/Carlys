# Refonte des photos d’exercices — travail en cours

Objectif : remplacer les 155 images existantes et compléter les 15 exercices sans photo (170 exercices au total).

## État du brouillon

Seul `developpe-couche.webp` est remplacé dans le seed et la démonstration. Son export 1254 × 1254 possède un vrai canal alpha ; les deux copies sont identiques. Aucun code de rendu ni aucun autre visuel n’est modifié. La série n’est pas terminée et ce brouillon ne doit pas être fusionné en l’état.

Les essais de développé incliné haltères, pompes, écarté poulie et développé incliné ont été générés mais rejetés : le damier est intégré dans des fichiers RGB, même après plusieurs demandes de détourage. Ils ne sont pas intégrés.

## Direction artistique

Même personnage gris anatomique que les catégories du projet, short anthracite, chaussures grises, mouvement et matériel spécifiques à chaque exercice. Muscles principaux en rouge de référence des fessiers (`#EA4E45`), avec relief. Personnage et matériel complets, aucun fond et aucune inscription : le titre est rendu par l’application. Une génération ImageGen intégrée par image indépendante.

## Intégration restant à effectuer

- Terminer les 169 autres visuels et vérifier poses, matériel, cadrage et alpha.
- Harmoniser le rouge sur toute la série.
- Relancer `pnpm --filter @carlys/api demo:catalog` après ajout des photos manquantes.
- Donner aux nouveaux médias du seed une URL liée au contenu : actuellement l’identifiant dépend seulement du slug alors que le cache est immutable, ce qui peut conserver les anciennes images après remplacement.
- Vérifier la suite de tests et les affichages avant fusion. Le déploiement réel nécessite aussi la publication des médias au stockage objet par le seed.

## Prompt commun


Créer une illustration 3D indépendante pour Carlys. Même athlète masculin anatomique gris que les images de catégories, short et chaussures anthracite, muscles principaux ciblés en rouge des fessiers. Illustrer précisément le mouvement du catalogue et son matériel, avec une seule pose lisible, tout le corps et le matériel dans le cadre. PNG RGBA réellement transparent, sans décor, damier, sol, ombre au sol ni texte. Le nom et les consignes de chaque exercice ci-dessous proviennent de `catalog.ts` via le catalogue exporté.

## Inventaire

| Exercice | Groupe | État |
|---|---|---|
| Développé couché (`developpe-couche`) | pectoraux | Premier visuel détouré intégré au brouillon |
| Développé incliné haltères (`developpe-incline-halteres`) | pectoraux | À remplacer |
| Pompes (`pompes`) | pectoraux | À créer |
| Écarté à la poulie vis-à-vis (`ecarte-poulie-vis-a-vis`) | pectoraux | À remplacer |
| Développé incliné (`developpe-incline`) | pectoraux | À remplacer |
| Développé décliné (`developpe-decline`) | pectoraux | À remplacer |
| Développé couché haltères (`developpe-couche-halteres`) | pectoraux | À remplacer |
| Développé décliné haltères (`developpe-decline-halteres`) | pectoraux | À remplacer |
| Chest press machine (`chest-press-machine`) | pectoraux | À remplacer |
| Chest press incliné machine (`chest-press-incline-machine`) | pectoraux | À remplacer |
| Écarté à la poulie incliné (`ecarte-poulie-incline`) | pectoraux | À remplacer |
| Écarté à la poulie décliné (`ecarte-poulie-decline`) | pectoraux | À remplacer |
| Pec deck (`pec-deck`) | pectoraux | À remplacer |
| Écarté couché haltères (`ecarte-couche-halteres`) | pectoraux | À remplacer |
| Tractions (`tractions`) | dos | À remplacer |
| Rowing barre buste penché (`rowing-barre`) | dos | À remplacer |
| Tirage vertical à la poulie (`tirage-vertical-poulie`) | dos | À remplacer |
| Rowing haltère unilatéral (`rowing-halteres-unilateral`) | dos | À remplacer |
| Tractions prise neutre (`tractions-prise-neutre`) | dos | À remplacer |
| Tractions lestées (`tractions-lestees`) | dos | À remplacer |
| Tractions assistées (`tractions-assistees`) | dos | À remplacer |
| Tirage vertical prise serrée (`tirage-vertical-prise-serree`) | dos | À remplacer |
| Tirage vertical en supination (`tirage-vertical-supination`) | dos | À remplacer |
| Tirage vertical prise neutre (`tirage-vertical-prise-neutre`) | dos | À remplacer |
| Tirage vertical unilatéral (`tirage-vertical-unilateral`) | dos | À remplacer |
| Rowing barre en supination (Yates) (`rowing-barre-supination`) | dos | À remplacer |
| Pendlay Row (`pendlay-row`) | dos | À remplacer |
| Rowing T-Bar (`rowing-t-bar`) | dos | À remplacer |
| Meadows Row (`meadows-row`) | dos | À remplacer |
| Rowing haltères au banc incliné (`rowing-halteres-banc-incline`) | dos | À remplacer |
| Seal Row (`seal-row`) | dos | À remplacer |
| Rowing assis à la poulie basse (`rowing-assis-poulie-basse`) | dos | À remplacer |
| Rowing poulie basse prise neutre (`rowing-poulie-basse-prise-neutre`) | dos | À remplacer |
| Rowing poulie basse prise large (`rowing-poulie-basse-prise-large`) | dos | À remplacer |
| Rowing poulie basse unilatéral (`rowing-poulie-basse-unilateral`) | dos | À remplacer |
| Rowing machine appui poitrine (`rowing-machine-appui-poitrine`) | dos | À remplacer |
| Low Row machine (`low-row-machine`) | dos | À remplacer |
| High Row machine (`high-row-machine`) | dos | À remplacer |
| Rowing convergent machine (`rowing-convergent-machine`) | dos | À remplacer |
| Rowing unilatéral machine (`rowing-unilateral-machine`) | dos | À remplacer |
| Face Pull à la poulie (`face-pull`) | epaules | À remplacer |
| Reverse Pec Deck (`reverse-pec-deck`) | epaules | À remplacer |
| Pull-over haltère (`pull-over-haltere`) | dos | À remplacer |
| Pull-over à la poulie haute (`pull-over-poulie`) | dos | À remplacer |
| Pull-over machine (`pull-over-machine`) | dos | À remplacer |
| Shrugs à la barre (`shrugs-barre`) | dos | À remplacer |
| Shrugs haltères (`shrugs-halteres`) | dos | À remplacer |
| Shrugs machine (`shrugs-machine`) | dos | À remplacer |
| Soulevé de terre (`souleve-de-terre`) | lombaires | À remplacer |
| Soulevé de terre sumo (`souleve-de-terre-sumo`) | lombaires | À remplacer |
| Rack Pull (`rack-pull`) | lombaires | À remplacer |
| Extensions lombaires au banc (`extensions-lombaires`) | lombaires | À remplacer |
| Développé militaire (`developpe-militaire`) | epaules | À remplacer |
| Élévations latérales (`elevations-laterales`) | epaules | À remplacer |
| Oiseau (élévations buste penché) (`oiseau-halteres`) | epaules | À remplacer |
| Développé militaire haltères (`developpe-militaire-halteres`) | epaules | À remplacer |
| Arnold Press (`arnold-press`) | epaules | À remplacer |
| Push Press (`push-press`) | epaules | À remplacer |
| Développé épaules à la machine (`developpe-epaules-machine`) | epaules | À remplacer |
| Développé épaules debout à la machine (`developpe-epaules-debout-machine`) | epaules | À remplacer |
| Développé épaules au banc incliné (barre) (`developpe-epaules-incline-barre`) | epaules | À remplacer |
| Développé épaules au banc incliné (haltères) (`developpe-epaules-incline-halteres`) | epaules | À remplacer |
| Développé épaules unilatéral (`developpe-epaules-unilateral`) | epaules | À remplacer |
| Landmine Press (`landmine-press`) | epaules | À remplacer |
| Z-Press (`z-press`) | epaules | À remplacer |
| Élévations frontales à la barre (`elevations-frontales-barre`) | epaules | À remplacer |
| Élévations frontales haltères (`elevations-frontales-halteres`) | epaules | À remplacer |
| Élévations frontales à la poulie (`elevations-frontales-poulie`) | epaules | À remplacer |
| Élévations frontales au disque (`elevations-frontales-disque`) | epaules | À remplacer |
| Élévations latérales à la poulie (`elevations-laterales-poulie`) | epaules | À remplacer |
| Élévations latérales à la machine (`elevations-laterales-machine`) | epaules | À remplacer |
| Élévations latérales machine unilatérales (`elevations-laterales-machine-unilateral`) | epaules | À remplacer |
| Élévations latérales au banc incliné (`elevations-laterales-banc-incline`) | epaules | À remplacer |
| Élévations latérales unilatérales (`elevations-laterales-unilateral`) | epaules | À remplacer |
| Élévations latérales coude fléchi (`elevations-laterales-coude-flechi`) | epaules | À remplacer |
| Élévations latérales à l’élastique (`elevations-laterales-elastique`) | epaules | À remplacer |
| Élévations latérales penché (Leaning Raise) (`elevations-laterales-penche`) | epaules | À remplacer |
| Élévations latérales à la poulie, penché (`elevations-laterales-poulie-penche`) | epaules | À remplacer |
| Cable Y-Raise (`cable-y-raise`) | epaules | À remplacer |
| Tirage menton à la barre (`tirage-menton-barre`) | epaules | À remplacer |
| Tirage menton haltères (`tirage-menton-halteres`) | epaules | À remplacer |
| Tirage menton prise large (`tirage-menton-prise-large`) | epaules | À remplacer |
| Élévations arrière au banc incliné (`elevations-arriere-banc-incline`) | epaules | À remplacer |
| Élévations arrière à la poulie (`elevations-arriere-poulie`) | epaules | À remplacer |
| Élévations arrière unilatérales (`elevations-arriere-unilateral`) | epaules | À remplacer |
| Reverse Fly à la poulie croisée (`reverse-fly-poulie-croisee`) | epaules | À remplacer |
| Reverse Fly à l’élastique (`reverse-fly-elastique`) | epaules | À remplacer |
| Rear Delt Row (`rear-delt-row`) | epaules | À remplacer |
| Tirage horizontal buste penché (`tirage-horizontal-buste-penche`) | epaules | À remplacer |
| Face Pull à la barre (`face-pull-barre`) | epaules | À remplacer |
| Curl biceps haltères (`curl-biceps-halteres`) | biceps | À remplacer |
| Curl barre (`curl-barre`) | biceps | À remplacer |
| Curl à la barre EZ (`curl-ez-barre`) | biceps | À remplacer |
| Curl alterné (`curl-alterne`) | biceps | À remplacer |
| Curl incliné haltères (`curl-incline-halteres`) | biceps | À remplacer |
| Curl concentration (`curl-concentration`) | biceps | À remplacer |
| Curl au pupitre (`curl-pupitre`) | biceps | À remplacer |
| Curl au pupitre haltère (`curl-pupitre-halteres`) | biceps | À remplacer |
| Curl spider (`curl-spider`) | biceps | À remplacer |
| Curl inversé (`curl-inverse`) | biceps | À remplacer |
| Curl à la poulie barre droite (`curl-poulie-barre-droite`) | biceps | À remplacer |
| Curl à la poulie corde (`curl-poulie-corde`) | biceps | À remplacer |
| Tractions supinées (`tractions-supinees`) | biceps | À remplacer |
| Curl marteau (`curl-marteau`) | biceps | À remplacer |
| Dips (`dips`) | triceps | À remplacer |
| Extension triceps à la poulie (`extension-triceps-poulie`) | triceps | À remplacer |
| Développé incliné prise serrée (`developpe-incline-prise-serree`) | triceps | À remplacer |
| Dips buste penché (`dips-buste-penche`) | triceps | À remplacer |
| Dips sur banc (`dips-sur-banc`) | triceps | À remplacer |
| Dips à la machine (`dips-machine`) | triceps | À remplacer |
| Pompes en diamant (`pompes-diamant`) | triceps | À remplacer |
| Pompes prise serrée (`pompes-prise-serree`) | triceps | À remplacer |
| Barre au front (barre droite) (`barre-au-front-barre-droite`) | triceps | À remplacer |
| Barre au front (barre EZ) (`barre-au-front-ez`) | triceps | À créer |
| Extensions allongé haltères (`extensions-allonge-halteres`) | triceps | À remplacer |
| Extension allongé unilatérale (`extension-allonge-unilaterale`) | triceps | À remplacer |
| Extension au-dessus de la tête (haltère) (`extension-au-dessus-tete-haltere`) | triceps | À remplacer |
| Extension au-dessus de la tête (barre EZ) (`extension-au-dessus-tete-barre-ez`) | triceps | À remplacer |
| Extension au-dessus de la tête (poulie) (`extension-au-dessus-tete-poulie`) | triceps | À remplacer |
| Extension corde au-dessus de la tête (`extension-corde-au-dessus-tete`) | triceps | À remplacer |
| Pushdown à la barre droite (`pushdown-barre-droite`) | triceps | À remplacer |
| Pushdown à la barre en V (`pushdown-barre-v`) | triceps | À remplacer |
| Pushdown prise inversée (`pushdown-prise-inversee`) | triceps | À remplacer |
| Pushdown unilatéral (`pushdown-unilateral`) | triceps | À remplacer |
| Kickback haltère (`kickback-haltere`) | triceps | À remplacer |
| Kickback à la poulie (`kickback-poulie`) | triceps | À remplacer |
| Tate Press (`tate-press`) | triceps | À remplacer |
| JM Press (`jm-press`) | triceps | À remplacer |
| Squat barre (`squat-barre`) | quadriceps | À créer |
| Squat gobelet (`squat-gobelet`) | quadriceps | À créer |
| Fentes marchées (`fentes-marchees`) | quadriceps | À créer |
| Presse à cuisses (`presse-a-cuisses`) | quadriceps | À créer |
| Soulevé de terre roumain (`souleve-de-terre-roumain`) | ischio-jambiers | À créer |
| Leg curl à la machine (`leg-curl-machine`) | ischio-jambiers | À créer |
| Good Morning (`good-morning`) | ischio-jambiers | À remplacer |
| Hip thrust (`hip-thrust`) | fessiers | À créer |
| Pont fessier (`pont-fessier`) | fessiers | À créer |
| Extensions mollets debout (`mollets-debout`) | mollets | À créer |
| Planche (`planche`) | abdominaux | À remplacer |
| Crunch (`crunch`) | abdominaux | À remplacer |
| Relevé de jambes suspendu (`releve-de-jambes-suspendu`) | abdominaux | À remplacer |
| Burpees (`burpees`) | quadriceps | À créer |
| Mountain climbers (`mountain-climbers`) | abdominaux | À remplacer |
| Crunch incliné (`crunch-incline`) | abdominaux | À remplacer |
| Crunch décliné (`crunch-decline`) | abdominaux | À remplacer |
| Crunch à la poulie (`crunch-poulie`) | abdominaux | À remplacer |
| Sit-up décliné (`sit-up-decline`) | abdominaux | À remplacer |
| Toe touch (`toe-touch`) | abdominaux | À remplacer |
| V-up (`v-up`) | abdominaux | À remplacer |
| Dragon Flag (`dragon-flag`) | abdominaux | À remplacer |
| Relevés de jambes au sol (`releves-de-jambes-au-sol`) | abdominaux | À remplacer |
| Reverse crunch (`reverse-crunch`) | abdominaux | À remplacer |
| Relevés de genoux suspendu (`releves-de-genoux-suspendu`) | abdominaux | À remplacer |
| Flutter kicks (`flutter-kicks`) | abdominaux | À remplacer |
| Bicycle crunch (`bicycle-crunch`) | abdominaux | À remplacer |
| Cross body crunch (`cross-body-crunch`) | abdominaux | À remplacer |
| Relevés de genoux latéraux suspendu (`releves-de-genoux-lateraux`) | abdominaux | À remplacer |
| Russian Twist (`russian-twist`) | abdominaux | À remplacer |
| Woodchopper à la poulie (`woodchopper`) | abdominaux | À remplacer |
| Pallof press (`pallof-press`) | abdominaux | À remplacer |
| Gainage latéral (`gainage-lateral`) | abdominaux | À remplacer |
| Hollow body hold (`hollow-body-hold`) | abdominaux | À remplacer |
| Gainage sur ballon (`gainage-sur-ballon`) | abdominaux | À remplacer |
| Plank shoulder tap (`plank-shoulder-tap`) | abdominaux | À remplacer |
| Plank jack (`plank-jack`) | abdominaux | À remplacer |
| Rouleau abdominal (à genoux) (`rouleau-abdominal`) | abdominaux | À remplacer |
| Rouleau abdominal (debout) (`rouleau-abdominal-debout`) | abdominaux | À remplacer |
| Balancier kettlebell (swing) (`balancier-kettlebell`) | fessiers | À créer |
| Étirement chat-vache (`etirement-chat-vache`) | lombaires | À créer |
| Étirement des ischio-jambiers debout (`etirement-ischio-debout`) | ischio-jambiers | À créer |
