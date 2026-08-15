# Écran de démarrage

L'application s'ouvre sur sa marque : le sceau Carlys, le mot, la devise, un
halo violet et un fil de lumière qui se remplit. L'écran tient l'affiche
**2,6 secondes** avant de céder la place.

Cible : `apps/mobile/lib/features/onboarding/presentation/screens/splash_screen.dart`

## Un plancher, jamais une addition

`splashHold` (2600 ms) est un **minimum d'affichage**, pas un délai ajouté.
La restauration de session et la lecture des préférences courent pendant ce
temps ; l'application s'ouvre quand les deux conditions sont réunies :

| Situation | Attente réelle |
| --------- | -------------- |
| Téléphone rapide, tout est prêt en 200 ms | 2,6 s (le plancher commande) |
| Téléphone lent, restauration en 4 s | 4 s (la restauration commande) |
| Réduction d'animations activée | aucune |

Ce plancher existe parce que la restauration est presque instantanée : sans
lui, le logo passerait en un battement de cil et l'écran ne servirait à rien.
Il reste court : au-delà, une page de démarrage n'est plus une signature mais
une porte fermée.

## Qui décide de l'ouverture

Trois pièces, chacune avec un rôle net :

| Pièce | Rôle |
| ----- | ---- |
| `splashGateProvider` | Le plancher est-il écoulé ? Dit ce qu'on a le droit de MONTRER. |
| `firstRunStepProvider` | Où en est le parcours ? Dit ce que l'application SAIT. |
| `authControllerProvider` | La session est-elle restaurée ? |

Le routeur retient sur `/splash` tant que l'un des deux premiers n'est pas
satisfait. Les garder séparés est délibéré : les fondre rendrait « étape
inconnue » ambigu, puisqu'elle signifierait tantôt « en cours de lecture »,
tantôt « on préfère attendre ».

La scène appelle `open()` quand son animation se termine, ce qui évite de
tenir deux durées synchronisées à la main.

## Accessibilité

Sous réduction d'animations système, le plancher tombe à zéro et la scène ne
joue pas : qui demande moins d'animations ne demande pas d'attendre plus
longtemps devant un logo.

## La scène ne boucle pas

Un seul contrôleur mène toute l'entrée, découpé en intervalles (sceau,
signature, fil de lumière). **Aucune boucle d'ambiance** : toute la suite de
tests monte l'application par cet écran, et une animation sans fin ferait
tourner `pumpAndSettle` jusqu'à son délai de garde. Ce serait une panne
générale, pas un détail — `splash_screen_test.dart` garde ce point.

Le fil de lumière se remplit plutôt que de tourner : la durée étant connue,
« ça arrive » est plus juste que « ça travaille ».

## Conséquence pour les tests et la galerie

Tout ce qui monte l'application complète traverse désormais cet écran. Deux
façons de le franchir :

- couper les animations (`FakeAccessibilityFeatures.allOn`), ce que font déjà
  les tests dont les écrans portent des scènes 3D ;
- avancer l'horloge de `splashHold`, ce que fait `passSplash` dans le harnais
  de captures.
