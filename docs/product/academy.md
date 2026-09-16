# Academy — le pack d'apprentissage

L'Academy enseigne ce que l'application fait pratiquer. Son contenu est
**éditorial et embarqué** (`apps/mobile/assets/academy/pack.json`, version
4, 58 leçons — la fournée de septembre 2026 en a ajouté 20, écrites puis
relues en adversaire sous deux angles, faits et forme) — pas une donnée
serveur : il voyage avec l'application, comme les vignettes de muscles.

## Les douze domaines

Dans l'ordre des sections, du geste quotidien vers le spécialisé :
Nutrition, Musculation, Cardio, Mobilité & stretching, Mental & discipline,
Sommeil & récupération, Blessures & prévention, Comprendre son corps,
Mythes du fitness, Hyrox, Running / Marathon, Calisthenics.

Quatre existaient déjà sous d'autres libellés : `technique` s'appelait
« Technique », `anatomie` « Anatomie », `recuperation` « Récupération ».
Seuls les LIBELLÉS ont changé — jamais les noms de l'énumération, qui sont
la clé du pack et des réponses déjà enregistrées : les renommer effacerait
la progression de chacun.

### Naviguer entre eux

Une barre de pastilles en tête d'écran, « Tous » d'abord et par défaut.
« Tous » déroule les douze sections avec leurs en-têtes : c'est la lecture
de découverte, celle qui fait tomber sur une leçon qu'on ne cherchait pas.
Une pastille active n'affiche que son domaine, et l'en-tête de section
disparaît alors — la pastille le dit déjà, le répéter ne ferait que pousser
la première leçon vers le bas.

Le domaine choisi est un état LOCAL de l'écran, pas un provider : c'est une
préférence d'affichage propre à la visite, que rien d'autre ne lit.

L'illustration n'est obligatoire que pour **Comprendre son corps**, où le
schéma porte l'information : on ne situe pas un muscle sans le voir.
Ailleurs elle est facultative, et `LessonIllustration` rend alors un
dégradé et l'icône du domaine. Exiger une image de chaque leçon aurait
voulu dire bloquer l'écriture derrière la production d'illustrations, ou
recycler des schémas sans rapport avec le propos.

## Le modèle d'une leçon

```
id, category, title, body          — le socle (inchangé depuis la v1)
points[]                           — « À retenir » : 3 idées actionnables max
muscleGroups[]                     — slugs du catalogue (anatomie) : le pont
                                     vers la bibliothèque d'exercices
image                              — assets/academy/<id>.webp (repli sinon)
question{prompt, choices,          — une question à choix unique ; son
         answerIndex, explanation}   explication s'affiche TOUJOURS après la
                                     réponse, juste ou fausse
```

Le chargeur (`academy_pack.dart`) tolère l'absence des champs optionnels :
une leçon minimale reste valide.

## Le chapitre Anatomie

**Une fiche par groupe musculaire du catalogue — les 12, sans exception**
(un test d'intégrité le garantit, contre les 12 slugs de la source de
vérité du catalogue, `catalog-data.ts` côté API). Chaque fiche déroule :
l'illustration, le rôle du muscle, l'essentiel à retenir, la question —
puis **« Voir les exercices de ce muscle »**, qui ouvre la bibliothèque
déjà filtrée (`/exercises?groupe=<slug>` ; le filtre s'applique DANS
l'écran, jamais avant la navigation — les providers de la bibliothèque
sont auto-disposés).

Apprendre → se tester → pratiquer, sans jamais chercher son chemin.

## Les illustrations

Chaque leçon déclare son image (`assets/academy/<id>.webp`). Repli en
cascade tant qu'elle n'est pas livrée — jamais un trou : l'illustration
dédiée, sinon la vignette du muscle enseigné (déjà embarquée), sinon le
dégradé de marque et l'icône du domaine. La direction artistique et les
prompts de génération vivent dans `apps/mobile/assets/academy/README.md`.

## Une question, deux endroits

La question du jour paraît sur l'**accueil** et dans sa catégorie de
l'Academy. C'est la même : y répondre une fois se voit des deux côtés,
sinon elle semblerait revenir, et on la reposerait à quelqu'un qui vient
d'y répondre.

Ce qui le permet est `AnsweredLessonsStore` (préférences locales, clé
`academy.lecons_repondues`) : identifiant de leçon vers l'index du choix
retenu, lu par `answeredLessonsProvider`, que les deux écrans observent.
Le **choix** est conservé, pas seulement le fait d'avoir répondu — afficher
la bonne réponse sans montrer celle qui a été donnée laisserait croire à
une réussite après une erreur.

La **première réponse gagne** : rouvrir une leçon ne réécrit rien, sans quoi
le score dérivé du profil de progression compterait deux fois la même
question. Des préférences illisibles rendent une ardoise vierge plutôt
qu'une erreur : le pire d'une lecture ratée est de reposer une question.

L'envoi aux défis culturels part **ensuite**, en meilleur effort : la marque
locale doit tenir hors ligne, une panne de réseau ne fait pas perdre la
trace d'une question abordée.

## Couverture

- `test/features/academy/answered_lessons_test.dart` : idempotence de la
  marque locale, résistance aux préférences abîmées, carte de quiz rouverte
  déjà remplie avec le choix RÉELLEMENT fait.
- `test/features/academy/academy_pack_test.dart` : validité de chaque
  leçon, unicité des identifiants, points/illustrations déclarés, anatomie
  couvrant exactement les 12 groupes du catalogue, reprise après échec de
  lecture.
- `test/features/academy/academy_flow_test.dart` : sections par domaine,
  dépliage, explication affichée juste ou faux, remontée des réponses aux
  défis culturels, et le parcours « fiche d'anatomie → bibliothèque
  filtrée sur le muscle ».

- Avancement (`academy_progress_test.dart`) : décompte par domaine, leçon
  retirée du pack qui ne compte pas, domaine vide jamais « bouclé »,
  célébration qui ne se déclenche qu'au franchissement, et les six
  récompenses de l'Academy décidées sans lire le titre atteint ni
  l'historique des séances.
- Écran (`academy_flow_test.dart`) : la carte « Où tu en es » affiche le
  compte et un pourcentage qui NOMME sa base (« 0 % du pack »), l'en-tête de
  domaine porte son « 0 / 4 · 0 % » même en vue filtrée, et le bandeau de
  domaine bouclé se ferme.
- Niveaux et pourcentages (`academy_level_test.dart`,
  `academy_progress_card_test.dart`) : barème strictement croissant, seuils
  absolus tous atteignables, aucun niveau avant la première leçon, jamais de
  recul, pourcentage TRONQUÉ (100 ne se dit qu'au contenu réellement
  bouclé — l'arrondi entier est tué par mutation), et la carte qui tait le
  niveau à zéro leçon puis dit le prochain pas comme une direction.
- Quiz de domaine (`domain_quiz_test.dart`) : seules les questions du
  domaine, une à la fois, explication puis pas suivant, score affiché puis
  remis à zéro par « Refaire », état vide sur domaine inconnu, affordance
  de l'en-tête réservée au domaine bouclé.
- Parcours (`academy_journey_test.dart`, `journey_flow_test.dart`) : voir
  la section « Le Parcours ».

## Où en est la lecture — un repère, jamais un second score

L'Academy n'affichait aucun chiffre d'avancement, et ses trois récompenses de
maîtrise ne paraissaient que sur les écrans de progression : on pouvait
boucler le pack sans jamais le voir dit là où on l'avait fait.

Elle compte désormais, **dans l'unité de ce qu'elle compte** : « 24 leçons sur
58 » en tête, « 3 / 4 » sous chaque titre de domaine, une jauge par domaine.
Un pourcentage accompagne le compte depuis l'arbitrage produit de septembre
2026, à une condition qui n'est pas négociable : **il nomme sa base** — « 63 %
du pack », « 75 % du domaine ». C'est ce que la règle de non-concurrence
protégeait réellement : l'axe « Maîtrise » du profil rapporte ces mêmes
leçons à une cible fixe de 20, et deux nombres SANS base annoncée pour le
même travail se contrediraient à l'écran. Deux nombres qui disent chacun sur
quoi ils portent ne se contredisent pas. Un « % » resté muet sur sa base est
toujours un défaut, et un test l'épingle.

- **« Abordée », pas « réussie ».** Le moteur de progression a déjà tranché
  dans ce sens et l'a documenté : se tromper fait apprendre, et n'ouvrir
  l'axe qu'aux bonnes réponses transformerait l'Academy en examen. Compter
  autrement ici contredirait une règle écrite.
- **La pastille d'un domaine bouclé porte un trophée**, pas son compte :
  douze pastilles allongées d'un « 4/5 » transforment la barre en couloir. Le
  compte se lit sous le titre de section, où il y a la place.
- **Une réponse à une leçon retirée du pack ne compte pas.** Le magasin local
  garde les réponses par identifiant ; les compter ferait dépasser le total.

### Les récompenses, décidées SANS le reste de l'application

Six sceaux s'affichent dans l'Academy : les trois de maîtrise (cinq leçons,
la moitié du pack, le pack entier) et trois nouveaux qui récompensent
d'avoir fait le TOUR d'un sujet (un domaine, la moitié, tous).

Trois paliers et non un badge par domaine : douze récompenses de plus
noieraient la vitrine, et « Hyrox terminé » après deux questions vaudrait
autant qu'« Academy terminée ». Le domaine précis, lui, se célèbre dans
l'Academy au moment où il se boucle, par un bandeau qui reprend la grammaire
du franchissement de titre.

L'état des sceaux se calcule **depuis les seuls faits de l'Academy**, jamais
depuis `earnedRewardsProvider` : ce provider lit l'historique des séances et
le profil dérivé, et le brancher rendrait l'Academy dépendante de la base
d'entraînement pour afficher SES badges, alors que tout son contenu est
embarqué et qu'elle doit tenir hors ligne. Un test vérifie qu'aucune des six
règles ne lit le titre atteint, plutôt que de le supposer.

Côté moteur, `RewardFacts` ne reçoit que **deux entiers** — domaines bouclés,
domaines servis. Lui passer l'énumération des domaines ferait dépendre la
progression de l'Academy, alors qu'un compte suffit à décider d'un palier.

### La célébration se déclenche au franchissement, pas à l'état

Le bandeau compare l'avant et l'après d'une réponse. Lire l'état final
rejouerait la fête à chaque ouverture d'un écran déjà terminé, et une fête
qui revient ne célèbre plus rien.

### Ce qui reste, et pourquoi

Un seul morceau de la tranche attend encore (niveaux, Parcours et quiz de
domaine sont livrés — sections suivantes) :

| Morceau | Ce qu'il faut trancher |
| --- | --- |
| **Persistance serveur** | Les réponses partent au serveur mais ne se relisent pas : la progression ne survit pas à un changement d'appareil |

## Le quiz de domaine

« Quiz de chapitre » est arbitré : le chapitre, c'est le DOMAINE. L'en-tête
d'un domaine BOUCLÉ propose « Quiz du domaine »
(`domain_quiz_screen.dart`) : ses questions rejouées d'un trait, une à la
fois, avec la même `QuizCard` que partout — seule l'invite change, puisque
ce quiz se rejoue à volonté.

Avant la fin du domaine, pas de quiz : il poserait des questions jamais
lues, un examen d'entrée là où l'Academy fait des répétitions. Le score
s'affiche à la fin puis meurt avec l'écran, PAR CONSTRUCTION : l'écran ne
lit que le pack et n'écrit nulle part. Un score conservé serait une note de
la personne (règle de non-concurrence) ; les réponses aux leçons, elles,
sont déjà notées à la première lecture, et rejouer ne les réécrit pas.

## Le Parcours

Six étapes guidées (`academy_journey.dart`) : Débutant → Nutrition →
Entraînement → Récupération → Discipline → Optimisation. Le choix éditorial
attendu est fait : une TRAVERSÉE généraliste de 32 leçons — les fiches
d'anatomie (référence à consulter) et les filières spécialisées (Hyrox,
running, calisthenics) restent en exploration libre, sinon le parcours
imposerait le marathon à qui fait de la musculation.

Ce qui a été tranché, et pourquoi :

- **Un ordre de lecture, pas un verrou.** Chaque étape s'ouvre librement ;
  le conflit annoncé avec l'onglet « Tous » est résolu en ne verrouillant
  RIEN. La reprise automatique dit simplement où l'on en est
  (`JourneyEntryCard` sur l'écran Academy : étape courante, « Reprendre »).
- **Une leçon lue hors parcours compte dans le parcours.** La réponse est
  la même donnée (`answeredLessonsProvider`) : rien à stocker côté
  parcours, donc rien à désynchroniser.
- **La validation d'une étape se constate au franchissement**, comme le
  domaine bouclé : un bandeau, une fois, décidé AVANT l'écriture (relire le
  provider juste après l'invalidation ferait la course avec la lecture
  asynchrone du magasin).
- **Une leçon retirée du pack ne bloque jamais une étape** : le calcul
  ignore les identifiants que le pack ne sert plus, et un test d'intégrité
  interdit au manifeste de référencer une leçon inexistante.

Couverture : `academy_journey_test.dart` (manifeste intègre, reprise,
étape passée, leçon hors pack, leçon lue hors parcours) et
`journey_flow_test.dart` (six étapes sans verrou, ordre du manifeste,
validation au franchissement et jamais avant, carte d'entrée Commencer /
Reprendre / Terminé). Le filtre du pack et le franchissement sont tués par
mutation.


## Les niveaux ne notent pas, ils situent

Les niveaux sont livrés (`academy_level.dart`), et ils tiennent la règle par
construction. Cinq jalons de lecture — Découverte (1 leçon), Exploration (5),
Assiduité (12), Profondeur (20), Érudition (30) — dont les noms disent un
RAPPORT au contenu, pas une valeur de la personne : « Assiduité » décrit une
habitude de lecture, là où « Expert » noterait.

Trois choix portent la règle :

- **Des seuils ABSOLUS, pas proportionnels au pack.** L'axe Maîtrise a sa
  cible fixe de 20 pour qu'étoffer le pack ne reprenne rien à personne ; un
  niveau assis sur la taille du pack ramènerait ce défaut, puisque doubler
  le pack le diviserait par deux sans que personne ait rien fait. Les
  seuils absolus ont la même propriété : le pack grandit, personne ne
  recule. Un test parcourt 0 à 60 leçons et vérifie que le rang ne descend
  jamais.
- **Un affichage, pas des récompenses.** Le journal des récompenses fête
  déjà ces franchissements (« maitrise-5 », « maitrise-moitie »,
  « maitrise-pack ») : créer une récompense par niveau compterait le même
  fait deux fois.
- **Aucun niveau avant la première leçon.** Un « niveau zéro » d'office se
  lirait comme une note d'échec ; la carte parle d'elle-même (« 0 leçons sur
  58 ») et le niveau arrive avec la lecture. Le prochain pas se dit comme
  une direction (« encore 3 leçons avant Profondeur »), jamais en creux.

Le pourcentage qui accompagne le compte suit l'arbitrage rappelé plus haut :
il nomme sa base (« du pack », « du domaine »), il est TRONQUÉ pour que
« 100 % » ne se dise qu'au contenu réellement bouclé, et il reste une
position dans un contenu — jamais un pourcentage de la personne. La règle
complète et ses quatre tests vivent dans [progression.md](progression.md).
