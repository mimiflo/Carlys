# Les 4 profils Carlys

Quatre **identités d'usage** que la personne choisit — et qui ne sont **pas
des niveaux** : un débutant peut être Stratège, un sportif avancé Challenger,
et l'on évolue d'un profil à l'autre à tout moment.

| Profil | Devise | Pour |
| ------ | ------ | ---- |
| **Le Constructeur** | « Je commence à construire. » | Découvrir l'application et le sport, reprendre progressivement, se maintenir en bonne santé, développer sa culture sportive. |
| **Le Challenger** | « Je veux aller plus loin. » | Se dépasser, sortir de sa zone de confort, progresser physiquement et intellectuellement. |
| **L'Athlète** | « Je me prépare pour quelque chose. » | Les personnes pratiquant régulièrement, ayant un objectif précis, les objectifs nécessitant discipline et constance. |
| **Le Stratège** | « Je veux comprendre avant d'agir. » | Les personnes qui veulent apprendre, comprendre le corps, l'entraînement et la nutrition, planifier avant d'agir. |

## Côté serveur

- `UserProfile.carlysProfile` (enum `CarlysProfile`, **nullable** — aucun
  défaut imposé), migration `20260812090000_carlys_profiles`.
- Choix par `PATCH /users/me { carlysProfile }` — le champ voyage dans
  `AuthUser` (contrat partagé), rejouable à volonté.
- e2e : null au départ, choix, changement, valeur inconnue refusée (400).

## Côté mobile

- Feature `lib/features/carlys_profile/` : enum + dépôt (`PATCH /users/me`),
  actions (choisir **puis** rafraîchir l'utilisateur — la sélection affichée
  vient toujours de `AuthUser.carlysProfile`, une seule source de vérité,
  démo comprise).
- Écran `/profil-carlys` : quatre cartes (illustration, titre, description,
  chevron) fidèles à la maquette ; le profil actuel porte un badge « Ton
  profil ». Chaque carte ouvre sa fiche (`showAppSheet`) : devise, publics
  (« Pour »), bouton « Choisir ce profil ».
- Entrée : onglet Profil → groupe « Profil Carlys » (« À choisir » tant que
  rien ne l'est).
- Un échec de choix s'affiche (SnackBar) et ne change rien — jamais un état
  silencieusement faux.

## Illustrations

Attendues dans `apps/mobile/assets/profiles/` (`constructeur.webp`,
`challenger.webp`, `athlete.webp`, `stratege.webp` — voir le README du
dossier). Tant qu'un fichier manque, la carte pose un **repli de marque**
(dégradé violet + icône du profil) : déposer les fichiers suffit, aucun
changement de code.

## Couverture

- e2e API (`test/auth.e2e-spec.ts`) : cycle complet du champ.
- Widgets mobile (`test/features/carlys_profile/`) : les 4 cartes et le badge
  du profil actuel, la fiche et le choix (badge qui suit, fiche « profil
  actuel »), l'échec hors ligne visible, la remontée du choix dans l'onglet
  Profil.
