# Nutrition — métabolisme et journal alimentaire

Deux moitiés, jamais confondues :

- l'**objectif** — calculé côté serveur depuis le profil métabolique
  (Mifflin-St Jeor : BMR, TDEE, objectif calorique, macros, hydratation) ;
- le **consommé** — saisi par l'utilisateur dans le journal alimentaire.

L'accueil affiche « consommé / objectif » (ex. « 654 / 2 759 ») **uniquement
quand les deux existent**. Journal non chargé : l'objectif seul, jamais un
zéro inventé. Journal vide : un VRAI zéro (« 0 / 2 759 »), qui est un fait.

## Journal alimentaire (`/api/v1/nutrition/meals`)

| Méthode | Chemin | Rôle |
| --- | --- | --- |
| POST | `/` | Ajouter un repas — id UUID généré sur l'appareil, création idempotente et rejouable |
| GET | `/?from&to` | Repas entre deux instants UTC |
| DELETE | `/:id` | Retirer (suppression douce, idempotente) |

Règles :

- **Le serveur ne découpe jamais les journées.** `eatenAt` est un instant
  UTC ; le client calcule les bornes de SA journée locale et les envoie
  (`from` inclus, `to` exclu). Un repas à 23 h 30 heure locale appartient au
  jour local, quel que soit le fuseau.
- **Mêmes garanties que les séances** : id client (rejouable), suppression
  douce idempotente, 404 indiscernable pour la donnée d'autrui.
- Un repas porte `name`, `kcal` (1 à 10 000) et `proteinG` facultatif.

## Hydratation — la seule mesure qui reste sur l'appareil

L'objectif d'eau (`waterMl`) vient du même calcul serveur que les calories et
les macros. Le **consommé**, lui, ne quitte jamais le téléphone : une table
Drift à une ligne par jour (`LocalWaterIntakes`, clé primaire = le jour local,
schéma 4), lue en flux par `consumedWaterTodayProvider`.

Ce choix est délibéré, et c'est l'exception à la règle du dépôt :

- un verre d'eau n'a **rien à raconter** à un autre appareil, contrairement à
  une séance ou à une mesure corporelle — pas de records à recalculer, pas de
  statistique à servir ;
- une file de synchronisation idempotente pour un entier remis à zéro chaque
  nuit coûterait bien plus qu'elle ne rapporte, schéma et endpoint compris ;
- l'écriture est bornée dans la transaction elle-même (0 à 20 L), et non par
  l'appelant : un total négatif ou absurde ne peut pas être écrit, quelle que
  soit la porte d'entrée.

La saisie passe par une **feuille** (`showWaterSheet`) ouverte depuis la
cellule Hydratation de l'accueil : `+ 25 cl`, `+ 50 cl`, et un retrait d'un
verre désactivé à zéro plutôt que borné en silence — un bouton qui ne fait
rien quand on le presse est pire qu'un bouton éteint.

## Mobile

- Écran Nutrition : section « Journal du jour » (liste, total en en-tête
  face à l'objectif, feuille d'ajout nom/kcal/protéines, retrait) entre le
  rapport métabolique et le profil.
- Accueil : la tuile Nutrition du « Résumé du jour » montre le consommé réel
  face à l'objectif (`consumedKcalTodayProvider`), et la cellule Hydratation
  ouvre la feuille d'eau (`waterStoreProvider`).
- Démo : deux repas pré-saisis et un compteur d'eau à mi-parcours, pour que
  « consommé / objectif » vive dès l'ouverture.

## Couverture

- Unitaires API (`meals.service.spec.ts`) : idempotence, conflit d'id
  d'autrui, retraits idempotents, 404 opaque.
- e2e API (`nutrition.e2e-spec.ts`) : ajout rejoué sans doublon, fenêtre de
  journée bornée par le client, retrait doux, validation des calories.
- Widgets mobile : ajout par la feuille (total mis à jour), suppression,
  « 0 / objectif » sur journal vide et « 654 / objectif » avec repas.
- Hydratation : migration 3 → 4 non destructive (`app_database_migration_test`),
  lecture du compteur sur l'accueil, feuille ouverte au tapotement de la
  cellule et écriture réellement enregistrée dans le magasin.
