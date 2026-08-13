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
- Entrées : la **première question de l'onboarding** (« Quel Carlys es-tu ? »,
  étape 1/5 — se reconnaître est l'accroche du parcours, avant les questions
  métaboliques), puis l'onglet Profil → groupe « Profil Carlys » (« À
  choisir » tant que rien ne l'est) pour changer à tout moment.
- À l'onboarding, le choix suit le même chemin différé que les réponses
  métaboliques : enregistré immédiatement si une session existe, sinon
  conservé localement (`profilCarlys` dans les réponses stockées) et reporté
  dès la création du compte.
- Un échec de choix s'affiche (SnackBar) et ne change rien — jamais un état
  silencieusement faux.

## Ce que le profil change dans l'application

`null` signifie « pas de personnalisation », jamais un profil par défaut.

- **Accueil** : la carte « Ton cap » (sous la séance du jour) oriente chaque
  identité vers la partie de l'application qui sert sa devise — Constructeur
  → Académie, Challenger → défis de la communauté, Athlète → programmes,
  Stratège → progression. Copie et destinations vivent dans
  `dashboard/presentation/widgets/profile_focus_card.dart` (le contenu
  éditorial des profils, lui, ignore la navigation).
- **Amorces du coach** (côté client) : une puce par identité s'ajoute aux
  amorces calculées depuis l'état réel (`coach_suggestions.dart`).
- **Coach IA** (côté serveur) : le tour envoyé au modèle porte un briefing
  d'angle par profil — voir `docs/product/coach-ia.md`, section « Prompt et
  mise en cache ».

## Illustrations

Attendues dans `apps/mobile/assets/profiles/` (`constructeur.webp`,
`challenger.webp`, `athlete.webp`, `stratege.webp` — voir le README du
dossier). Tant qu'un fichier manque, la carte pose un **repli de marque**
(dégradé violet + icône du profil) : déposer les fichiers suffit, aucun
changement de code.

## Couverture

- e2e API (`test/auth.e2e-spec.ts`) : cycle complet du champ ;
  (`test/coach.e2e-spec.ts`) : le briefing part avec le tour, le préfixe de
  cache reste identique pour tous.
- Widgets mobile (`test/features/carlys_profile/`) : les 4 cartes et le badge
  du profil actuel, la fiche et le choix (badge qui suit, fiche « profil
  actuel »), l'échec hors ligne visible, la remontée du choix dans l'onglet
  Profil.
- Onboarding (`test/features/onboarding/`) : l'identité en première étape,
  le report différé du choix à la création du compte, l'aller-retour de
  stockage. Accueil (`test/features/dashboard/profile_focus_card_test.dart`) :
  la carte par profil, sa navigation, et son absence sans profil.
