# Les citations Carlys

Une maxime s'affiche chaque jour sur l'accueil, dans la zone haute, à gauche
du cœur. Ce document dit **d'où elle vient**, **ce qui la choisit** et
**pourquoi elle ne peut pas mentir**.

## Le recueil : soixante maximes de rotation, plus les contextuelles

Les maximes sont du **contenu éditorial de l'application**, pas une donnée
serveur : elles vivent dans `apps/mobile/lib/features/dashboard/data/quotes/`,
une liste par valeur Carlys. C'est ce qui garantit qu'une maxime s'affiche
hors ligne, dès le premier lancement, sans appel réseau.

Aucune n'est attribuée à quiconque : ce sont des maximes maison. Prêter une
phrase inventée à un athlète ou à un auteur serait une citation fabriquée,
donc un mensonge affiché.

Une entrée du recueil (`QuoteEntry`) porte son texte et un **ensemble
d'étiquettes** :

| Étiquettes | Nature | Quand elle sort |
| ---------- | ------ | --------------- |
| vide | maxime de **rotation** | un jour sur soixante, quoi qu'il arrive |
| non vide | maxime **contextuelle** | seulement quand l'un de ses faits est vrai |

La rotation reste ce qu'elle était : `entrelacer()` compose un cycle par
valeur (constance, maîtrise, performance, discipline, équilibre) et lève si
les cinq listes de maximes **sans contexte** divergent. Les maximes
étiquetées, elles, s'ajoutent librement — elles ne passent jamais par la
rotation, donc ne peuvent pas la déséquilibrer.

## Le défaut que cette séparation ferme, et qui était LIVRÉ

Trois maximes de la rotation d'origine parlaient d'un état qu'elles ne
vérifiaient pas :

- « Sauter une séance ne défait rien… »
- « Après une pause, reprends plus léger… »
- « Une séance abandonnée en cours… »

Elles s'affichaient donc **à tout le monde un jour sur soixante**, y compris
à quelqu'un qui s'entraîne depuis six mois sans en manquer une. Le premier
geste de cette tranche n'a pas été d'ajouter des maximes, mais de sortir
celles-là de la rotation en les étiquetant.

Deux gardes tiennent la réparation, dans `daily_quotes_test.dart` :

- le garde **structurel** — aucune maxime servie par la rotation ne porte
  d'étiquette, sur deux tours complets ;
- le garde **lexical** — aucune maxime de rotation ne contient un marqueur
  qui AFFIRME un état (« après une pause », « ta première séance »,
  « objectif atteint »…). Les marqueurs affirment, ils n'évoquent pas : « Le
  plus dur n'est pas la première séance, c'est la troisième semaine » est une
  maxime générale, et elle a le droit de tourner.

## Les douze contextes

`QuoteContext` (`domain/entities/quote_context.dart`) :

| Contexte | Le fait |
| -------- | ------- |
| `premiereSeance` | aucune séance terminée |
| `retourApresPause` | une séance **aujourd'hui**, après un écart d'au moins 10 jours |
| `pauseEnCours` | au moins 4 jours sans séance, et **aucune** aujourd'hui |
| `serieEnCours` | 3 jours d'affilée ou plus |
| `recordBattu` | un record daté d'aujourd'hui ou d'hier |
| `objectifAtteint` | une cible du jour atteinte |
| `seanceAbandonnee` | la dernière tentative a été abandonnée |
| `plateau` | le volume de la semaine est sous 90 % de la précédente |
| `surcharge` | 6 séances ou plus dans la semaine |
| `semaineCreuse` | aucune séance cette semaine, et on est jeudi ou plus tard |
| `recuperation` | entre 20 h et 72 h depuis la dernière séance, rien aujourd'hui |
| `apprentissage` | l'axe Maîtrise attend encore des faits |

Une maxime porte **plusieurs** étiquettes quand elle sert plusieurs états.
Sans ça, il faudrait douze variantes quasi identiques de la même phrase,
c'est-à-dire douze listes concurrentes — exactement ce que la tranche
cherchait à éviter.

`retourApresPause` et `pauseEnCours` sont des **miroirs exacts** : la
première exige une séance aujourd'hui, la seconde exige qu'il n'y en ait pas.
Sans la première condition, on dirait « content de te revoir » à qui n'est
pas revenu ; sans la seconde, à qui n'est jamais parti. Les deux erreurs
s'écrivent en oubliant une ligne, et `quote_selection_test.dart` prouve
qu'elles ne sont jamais vraies ensemble.

## La priorité : le premier contexte vrai gagne

Le principe qui engendre l'ordre, et qu'on relit avant d'y toucher : *un
moment de bascule bat une célébration ; une célébration bat une fragilité ;
une fragilité du jour bat une tendance de la semaine ; une tendance bat un
état ordinaire.*

```
premiereSeance → retourApresPause → surcharge → recordBattu →
objectifAtteint → serieEnCours → seanceAbandonnee → semaineCreuse →
pauseEnCours → plateau → recuperation → apprentissage
```

Deux exceptions à ce principe, toutes deux motivées par une règle de marque
écrite ailleurs :

- **`surcharge` passe devant `serieEnCours`**, alors que les deux sont vrais
  ensemble dès six jours d'affilée. Féliciter une série de sept jours
  contredirait la valeur Équilibre — « le repos fait partie de
  l'entraînement ». La santé passe avant la félicitation.
- **`retourApresPause` bat `recordBattu`.** Qui revient après trois semaines
  est celui qui risque le plus de repartir ; et le record est **déjà dit
  ailleurs sur le même écran** (la carte de titre le remonte, le Mentor le
  fête dans « Pour toi »). Il n'est pas perdu — il serait dit trois fois.

La règle et le recueil vivent dans deux couches distinctes, et ce n'est pas
un détail de rangement : `domain/quote_selection.dart` dit **quels contextes
sont vrais et dans quel ordre** sans connaître une seule phrase, et
`data/daily_quotes.dart` choisit la phrase (`contextualQuote`). Le domaine ne
descend jamais vers les données — `test/architecture/feature_layers_test.dart`
le vérifie, et l'a d'ailleurs attrapé une fois dans cette tranche.

Un contexte **sans maxime rédigée se saute sans bruit**, et la priorité
continue : c'est ce qui permet d'ajouter un contexte avant son corpus sans
casser l'accueil. Un test garde tout de même qu'aucun des douze n'est muet —
douze contextes sans phrases rendraient la tranche décorative.

## Les faits, et d'où ils viennent

`buildQuoteFacts()` est une fonction **pure** : ni horloge, ni base, ni
réseau. Elle reçoit le jour de référence et l'historique local, et rend une
structure plate que le sélecteur lit. Le choix d'une citation devient donc
éprouvable au cas par cas, comme `progression_facts_builder.dart` l'a fait
pour le profil.

Dix faits sur douze sont **locaux**, et c'est délibéré : le recueil est
offline-first, son contexte doit l'être aussi. Les deux exceptions :

- `recentRecordAt` vient de `GET /progress/records` ;
- `goalReached` vient des cibles du rapport métabolique.

Hors ligne, les deux valent faux, `recordBattu` et `objectifAtteint` sont
silencieusement inactifs, et le repli reprend la main. Personne ne lit une
félicitation fausse — mais il faut le savoir en lisant le code.

Deux précautions de calcul méritent d'être dites :

- **Les écarts se comptent en jours CIVILS locaux**, par les composantes de
  date, jamais par une différence d'heures : deux séances à 23 h et 1 h sont
  à deux heures l'une de l'autre et pourtant à un jour d'écart, et c'est le
  jour qui compte.
- **`gapBeforeLast` regarde l'écart AVANT la dernière séance**, pas le temps
  écoulé depuis elle. C'est le seul moyen de reconnaître un retour : le temps
  depuis la dernière séance vaut deux heures le jour où on revient.

## Le contrat de stabilité a changé de forme, pas de nature

Ce n'était pas « la même phrase toute la journée » par hasard : c'est ce qui
empêche la maxime de papillonner à chaque reconstruction. La garantie
devient : **la même TANT QUE LES FAITS NE CHANGENT PAS**. Terminer une séance
à 18 h change légitimement la citation — c'est tout l'objet de l'affichage
contextuel. À faits constants, deux appareils de la même personne lisent la
même phrase, et la sélection reste déterministe.

## Ce que les tests prouvent

| Fichier | Ce qu'il ferme |
| ------- | -------------- |
| `daily_quotes_test.dart` | le recueil, sa rotation, son ton, et les deux gardes anti-régression du défaut ci-dessus |
| `quote_selection_test.dart` | le balayage sur 60 jours, les miroirs, la priorité, la construction des faits |

**Le balayage sur soixante jours est le cœur du dispositif.** Une assertion
sur un seul jour passerait par chance cinquante-neuf fois sur soixante, et la
CI serait verte cinquante-neuf jours sur soixante — c'est-à-dire exactement
aussi verte qu'elle l'était pendant que le défaut était livré. Le balayage
fait tourner un profil « s'entraîne tous les jours » sur un cycle complet et
vérifie qu'il ne lit **jamais** qu'il s'est arrêté ; une assertion
complémentaire garde qu'il lit bien une maxime contextuelle, sans quoi le
balayage passerait aussi si la sélection n'en servait plus aucune.
