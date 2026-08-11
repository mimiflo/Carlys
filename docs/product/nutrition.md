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

## Mobile

- Écran Nutrition : section « Journal du jour » (liste, total en en-tête
  face à l'objectif, feuille d'ajout nom/kcal/protéines, retrait) entre le
  rapport métabolique et le profil.
- Accueil : la tuile Nutrition du « Résumé du jour » montre le consommé réel
  face à l'objectif (`consumedKcalTodayProvider`).
- Démo : deux repas pré-saisis pour que « consommé / objectif » vive dès
  l'ouverture.

## Couverture

- Unitaires API (`meals.service.spec.ts`) : idempotence, conflit d'id
  d'autrui, retraits idempotents, 404 opaque.
- e2e API (`nutrition.e2e-spec.ts`) : ajout rejoué sans doublon, fenêtre de
  journée bornée par le client, retrait doux, validation des calories.
- Widgets mobile : ajout par la feuille (total mis à jour), suppression,
  « 0 / objectif » sur journal vide et « 654 / objectif » avec repas.
