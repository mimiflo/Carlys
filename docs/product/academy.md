# Academy — le pack d'apprentissage

L'Academy enseigne ce que l'application fait pratiquer : anatomie,
technique, nutrition, récupération. Son contenu est **éditorial et
embarqué** (`apps/mobile/assets/academy/pack.json`, version 2) — pas une
donnée serveur : il voyage avec l'application, comme les vignettes de
muscles.

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
(un test d'intégrité le garantit, contre les slugs du catalogue de
démonstration, généré depuis le seed de l'API). Chaque fiche déroule :
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
