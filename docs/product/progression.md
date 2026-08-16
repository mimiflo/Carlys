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
| **Maîtrise** | Comprends-tu ? | Leçons de l'Academy abordées | Part du pack, plein au pack entier |
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
| **Citation** | Le mot du jour | Une par jour, adossée à une des cinq valeurs |

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

**La majesté monte avec le titre** (`TitleRegalia`) : liseré, dégradé de
marque, halo, puis couronne au dernier palier. Le premier palier ne brille
pas — sinon il ne resterait rien à gagner.

Elle suit le titre le plus haut **jamais atteint**, pas le titre courant :
personne ne doit voir son écran se ternir parce qu'il a été malade deux
semaines.

### Les quatre micro-animations

| Animation | Où | Règle |
| --------- | -- | ----- |
| **La gravure** | Une récompense nouvelle | Le trait se trace, le sceau se remplit. Ne rejoue JAMAIS : c'est le journal qui en décide |
| **La flamme** | Série de constance, accueil | Respire tant que la série tient, immobile sinon |
| **Le tracé** | Graphiques (`AppRevealSweep`) | La courbe se découvre du plus ancien vers aujourd'hui, par un clip et non une reconstruction |
| **Le cap franchi** | Nouveau titre | Un bandeau se déplie, une fois, le jour de l'inscription |

Toutes passent par `AppMotion.resolve` : la réduction d'animations système
les rend immobiles, sans rien retirer de l'information.

### Où le système se voit

| Écran | Ce qu'il montre |
| ----- | --------------- |
| **Accueil** | Le titre porté, les points, la dernière récompense — dans son écrin |
| **Progrès** | La même carte, puis les trois dernières récompenses et les records |
| **Profil de progression** | Le cap franchi, le titre, la vitrine entière, les cinq axes |

## Le manifeste

`ManifestoScreen` (route `/manifeste`) affiche le texte de marque et les cinq
valeurs qu'il fonde. Il n'affiche **aucun point** : les valeurs y sont
expliquées, elles sont mesurées ailleurs. Un manifeste qui afficherait un score
cesserait d'être un manifeste.

Entrées : le profil (« Le manifeste ») et le bas du profil de progression
(« Pourquoi ces cinq axes »).
