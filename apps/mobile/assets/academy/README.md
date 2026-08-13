# Academy — contenu et illustrations

`pack.json` est le contenu ÉDITORIAL de l'Academy (leçons, points à retenir,
questions). Les illustrations des leçons sont attendues ici, en `.webp`
paysage (~800 × 450, qualité 80), nommées par identifiant de leçon :

```
assets/academy/<id-de-leçon>.webp     ex. anatomie-pectoraux.webp
```

Tant qu'un fichier manque, la carte pose un repli en cascade — jamais un
trou : l'illustration dédiée, sinon la vignette du muscle enseigné
(`assets/muscles/`), sinon le dégradé de marque et l'icône du domaine.
Déposer les fichiers suffit : aucun changement de code.

## Direction artistique commune (à coller en tête de chaque prompt)

> Illustration cinématographique sombre pour une application de musculation
> premium. Fond noir violacé profond (#08050E), éclairage dramatique
> bicolore : violet électrique (#9B30FF) et orange incandescent (#FF7A45).
> Rendu semi-réaliste détaillé, atmosphère de studio, légère brume
> lumineuse. Format paysage 16:9. Aucun texte, aucun logo.

## Prompts — Anatomie (figure « écorché » : corps graphite, muscle illuminé)

Pour les 12 fiches d'anatomie, ajouter après la direction artistique :

> Figure anatomique humaine semi-réaliste, style écorché élégant et moderne :
> le corps entier en graphite sombre mat, presque silhouette, et UNIQUEMENT
> le muscle cible illuminé de l'intérieur en dégradé violet-orange
> incandescent, ses fibres visibles.

puis la spécificité :

| Fichier | Spécificité du prompt |
| ------- | --------------------- |
| `anatomie-pectoraux.webp` | Torse vu de face ; le grand pectoral illuminé en éventail, ses fibres convergeant de la clavicule et du sternum vers l'épaule. |
| `anatomie-dos.webp` | Dos vu de trois quarts arrière ; grand dorsal en V et trapèzes illuminés. |
| `anatomie-epaules.webp` | Buste de trois quarts ; le deltoïde illuminé en trois faisceaux distincts (avant, côté, arrière). |
| `anatomie-biceps.webp` | Bras fléchi de profil ; le biceps contracté illuminé, avant-bras en supination. |
| `anatomie-triceps.webp` | Bras tendu vu de l'arrière ; le triceps illuminé dessinant son fer à cheval. |
| `anatomie-avant-bras.webp` | Avant-bras et main serrant une barre olympique ; fléchisseurs et extenseurs illuminés. |
| `anatomie-abdominaux.webp` | Torse vu de face ; grand droit et obliques illuminés, sangle abdominale gainée. |
| `anatomie-lombaires.webp` | Bas du dos vu de dos ; les érecteurs du rachis illuminés en deux colonnes le long de la colonne vertébrale. |
| `anatomie-fessiers.webp` | Hanches vues de trois quarts arrière, position de hip thrust ; grand et moyen fessiers illuminés. |
| `anatomie-quadriceps.webp` | Cuisse vue de face en fente avant ; les quatre chefs du quadriceps illuminés. |
| `anatomie-ischio-jambiers.webp` | Arrière de cuisse, jambe tendue en soulevé de terre roumain ; les trois ischio-jambiers illuminés. |
| `anatomie-mollets.webp` | Mollet de profil sur demi-pointe ; gastrocnémien et soléaire illuminés en deux couches. |

## Prompts — Technique, Nutrition, Récupération (scènes)

Direction artistique commune, puis :

| Fichier | Spécificité du prompt |
| ------- | --------------------- |
| `technique-progression.webp` | Barre olympique chargée en gros plan, un disque supplémentaire en lévitation prêt à se poser ; fine courbe lumineuse montante en arrière-plan. |
| `technique-amplitude.webp` | Silhouette athlétique en squat très profond, de profil ; l'arc complet du mouvement tracé en traînée lumineuse violet-orange. |
| `technique-repos.webp` | Athlète assis sur un banc de salle sombre, serviette sur la nuque, respiration posée ; chronomètre holographique violet flottant à côté. |
| `technique-echauffement.webp` | Silhouette en mouvement dynamique d'échauffement ; vagues de chaleur orange montant des épaules et des jambes. |
| `nutrition-proteines.webp` | Nature morte premium sur table sombre : œufs, filet de poisson, viande maigre, légumineuses, éclairés en violet et orange. |
| `nutrition-calories.webp` | Balance stylisée en équilibre : d'un côté une flamme orange (dépense), de l'autre une assiette violette (apports). |
| `nutrition-hydratation.webp` | Verre d'eau en gros plan, éclaboussure figée et gouttes en suspension, reflets violets et orange. |
| `recuperation-sommeil.webp` | Silhouette endormie paisible vue de haut ; lune violette et particules lumineuses régénérantes descendant sur le corps. |
| `recuperation-courbatures.webp` | Fibres musculaires en très gros plan, micro-lésions en cours de réparation avec des lueurs de soudure orange. |
| `recuperation-frequence.webp` | Calendrier hebdomadaire stylisé flottant dans l'obscurité ; jours d'entraînement illuminés en alternance violet/orange. |

## Conversion

ChatGPT rend du PNG : convertir en webp avant de déposer —
`cwebp -q 80 image.png -o anatomie-pectoraux.webp` (ou équivalent).
