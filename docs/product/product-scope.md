# Périmètre produit

> **Statut.** Document de cadrage produit. L'Étape 1 (fondation technique) est
> faite ; toutes les fonctionnalités utilisateur décrites ici sont **cibles**
> et arrivent par tranches verticales (Étapes 2 à 7 — voir la
> [correspondance en fin de document](#correspondance-étapes-1-7--périmètre)).
> Rien dans ce document ne doit être lu comme « déjà disponible » sauf mention
> explicite « Étape 1 — fait ».

## Vision

Carlys est une **plateforme fitness premium multiplateforme** : une application
mobile Flutter (iOS et Android d'abord) au design soigné, adossée à une API
NestJS et à un back-office d'administration Next.js, le tout en monorepo.

Trois convictions structurent le produit :

- **Le terrain d'abord.** Une séance de musculation se passe en salle, souvent
  sans réseau. L'app est **offline-first** : tout ce qui compte (démarrer une
  séance, enregistrer une série) fonctionne hors ligne, la synchronisation est
  une optimisation (Étape 4).
- **Premium par la qualité, pas par la surenchère.** Peu de fonctionnalités,
  mais irréprochables : design system complet dès l'Étape 1 (thèmes
  clair/sombre/OLED, respect de la réduction d'animations, accessibilité),
  états de chargement/vide/erreur systématiques, performances.
- **Le serveur décide.** Les droits d'accès (entitlements d'abonnement) sont
  évalués côté serveur ; le client affiche, il n'autorise jamais (Étape 6).

## Les cinq valeurs Carlys

Ce que le produit défend, et ce sur quoi son discours s'aligne d'un écran à
l'autre :

| Valeur | Ce qu'elle veut dire | Où elle se voit |
| --- | --- | --- |
| **Dépassement** | Aller chercher la répétition d'après | Records personnels, cible affichée pendant la séance |
| **Connaissance** | Comprendre ce qu'on fait, et pourquoi | Fiches d'exercice, mesures et statistiques |
| **Maîtrise** | La qualité du mouvement avant la charge | Séries prévues (tempo, repos), consignes de la fiche |
| **Constance** | Ce qu'on répète devient ce qu'on est | Série de constance de l'accueil, « Ta semaine » |
| **Équilibre** | Le repos et la nutrition font partie de l'entraînement | Récupération, métabolisme, onglet Nutrition |

Elles ordonnent aussi la **maxime du jour** de l'accueil : le recueil
(`apps/mobile/lib/features/dashboard/data/daily_quotes.dart`) est entrelacé par
valeur, donc deux jours consécutifs n'en servent jamais la même.

Deux règles s'y attachent, à ne pas contourner :

- les maximes sont **du contenu d'application**, embarqué : une phrase doit
  s'afficher hors ligne dès le premier lancement, comme le reste des libellés ;
- aucune n'est **attribuée à une personne réelle**. Prêter une phrase inventée
  à un athlète ou à un auteur serait une citation fabriquée.

## Utilisateurs cibles

| Public | Horizon | Besoin principal |
|---|---|---|
| **Pratiquants de musculation / fitness** | MVP | Suivre leurs séances (séries, poids, répétitions), progresser, visualiser records et statistiques — y compris sans réseau en salle |
| **Coachs** | Extension future (post-MVP) | Créer et vendre des programmes, suivre leurs clients via un espace web dédié |
| **Équipe interne (support, contenu)** | Étapes 3 et 7 | Administrer le catalogue d'exercices, les utilisateurs et les abonnements via `apps/admin` |

Le MVP est **exclusivement centré sur le pratiquant individuel**. Tout ce qui
concerne les coachs est préparé par l'architecture (voir
[Extensions futures](#extensions-futures)) mais n'est pas construit.

## Fonctionnalités du MVP

Liste complète du périmètre MVP, avec la tranche verticale qui la livre :

| Fonctionnalité | Description | Étape |
|---|---|---|
| Inscription / connexion | E-mail + mot de passe (Argon2id), validation d'e-mail, mot de passe oublié ; JWT access court + refresh rotatif hashé, sessions par appareil, détection de réutilisation de refresh token | 2 |
| Profil utilisateur | Informations de base, objectifs, unités (kg/lb) | 2 |
| Onboarding | Premier parcours guidé après inscription (objectifs, niveau, préférences) | 2 |
| Bibliothèque d'exercices + recherche | Catalogue seedé (30+ exercices), recherche et filtres (groupe musculaire, équipement), cache Redis côté API | 3 |
| Création de programme | Programmes d'entraînement personnels : semaines, jours, modèles de séances | 4 |
| Séances d'entraînement | Séance active avec séries / poids / répétitions, notes ; identifiants UUID générés côté client pour le rejeu hors ligne | 4 |
| Minuteur de repos | Chronomètre de repos entre séries, intégré à la séance active | 4 |
| Historique | Liste des séances passées et détail d'une ancienne séance | 4 |
| Hors ligne + synchronisation | Base locale Drift/SQLite, file de synchronisation **idempotente** vers l'API (rejeu sans doublon) | 4 |
| Records personnels | Détection et affichage des records (charges, volume) | 5 |
| Statistiques simples | Volume, fréquence, tendances — graphiques (fl_chart) | 5 |
| Premium de base + paywall | Abonnement Premium (mensuel/annuel, essai), écran d'abonnement, entitlements décidés côté serveur, webhooks signés et idempotents | 6 |
| Paramètres | Thème, langue (fr/en), notifications, gestion des appareils/sessions | 2 (base), enrichi ensuite |
| Suppression de compte | Suppression définitive depuis l'app (exigence des stores), suppression logique côté serveur (`deletedAt`) puis purge | 2 |
| Admin minimal | Back-office `apps/admin` : statut de la plateforme (Étape 1 — fait), gestion du catalogue (Étape 3), puis rôles/permissions/audit (Étape 7) | 1, 3, 7 |

## Écrans Flutter du MVP

### État actuel (Étape 1 — fait)

Deux écrans existent aujourd'hui, avec les routes GoRouter correspondantes
(`lib/app/router/app_routes.dart`) : **Splash** (`/`,
`features/onboarding/presentation/screens/splash_screen.dart`) et **Accueil**
provisoire (`/home`, `features/dashboard/presentation/screens/home_screen.dart`).
Tous les autres écrans ci-dessous sont la **spécification cible** ; ils
arrivent avec leur tranche verticale, dans les dossiers de fonctionnalités déjà
scaffoldés (`lib/features/*`).

### Liste complète (spécification)

| Écran | Fonctionnalité (`lib/features/`) | Étape (indicative) |
|---|---|---|
| Splash | `onboarding` | 1 — fait |
| Mise à jour obligatoire (éventuelle) | transverse (`app/` + `core/`) | posée avec le client API |
| Connexion | `authentication` | 2 |
| Inscription | `authentication` | 2 |
| Mot de passe oublié | `authentication` | 2 |
| Validation e-mail | `authentication` | 2 |
| Onboarding | `onboarding` | 2 |
| Accueil | `dashboard` | 1 (squelette — fait), enrichi à chaque étape |
| Bibliothèque d'exercices | `exercises` | 3 |
| Détail d'un exercice | `exercises` | 3 |
| Programmes | `programs` | 4 |
| Détail d'un programme | `programs` | 4 |
| Créateur de programme | `workout_builder` | 4 |
| Préparation de séance | `workout_session` | 4 |
| Séance active | `workout_session` | 4 |
| Sélection d'exercice (en séance) | `workout_session` | 4 |
| Minuteur de repos | `workout_session` | 4 |
| Résumé de séance | `workout_session` | 4 |
| Historique | `workout_history` | 4 |
| Détail d'une ancienne séance | `workout_history` | 4 |
| Progression | `progress` | 5 |
| Records personnels | `progress` | 5 |
| Profil | `profile` | 2 (base), 5 |
| Abonnement (paywall) | `subscriptions` | 6 |
| Paramètres | `settings` | 2 (base), enrichi ensuite |
| Gestion des appareils | `settings` / `authentication` | 2 |
| Suppression du compte | `settings` | 2 |

### Contrat de qualité par écran

**Chaque écran** du MVP gère explicitement les six dimensions suivantes —
c'est un critère d'acceptation, pas une recommandation :

1. **Chargement** — `AppLoadingIndicator`, jamais d'écran figé sans retour ;
2. **Succès** — contenu nominal ;
3. **Vide** — `AppEmptyState` avec action de sortie (ex. « Créer un
   programme ») quand la liste est vide ;
4. **Erreur** — `AppErrorState` avec message actionnable et bouton réessayer,
   jamais d'erreur technique brute ;
5. **Hors ligne** — comportement défini : soit l'écran fonctionne sur les
   données locales (Drift, Étape 4), soit il annonce clairement la
   dégradation ;
6. **Accessibilité et responsive** — cibles tactiles suffisantes, labels
   sémantiques, respect de la réduction d'animations système (`AppMotion`),
   adaptation aux window size classes (`AppBreakpoints`), `SafeArea`
   systématique.

Les composants cités viennent du design system
(`lib/design_system/`), qui reflète les tokens de
`packages/design-tokens/src/tokens.json` (primaire `#9B30FF`, accent
`#FF7A45`).

## Ce qui n'est PAS construit immédiatement

Volontairement **hors périmètre MVP** — mais l'architecture ne ferme aucune de
ces portes :

| Non construit maintenant | Ce que l'architecture prépare |
|---|---|
| Réseau social complet (fil, abonnés, partages) | Dossier `features/social/` scaffoldé ; monolithe modulaire extensible |
| Messagerie | Rien de spécifique — s'appuiera sur les modules utilisateurs/notifications existants |
| IA avancée / coaching intelligent | Dossier `features/coaching/` scaffoldé ; entitlement `ai_coaching` réservé ; données de séance structurées et exploitables |
| Marketplace (programmes de coachs) | Modèles programmes/abonnements conçus pour être étendus ; entitlement `coach_dashboard` réservé |
| Live / diffusion temps réel | Aucune contrainte d'architecture prise contre — hors sujet au stade actuel |
| Microservices | **Refus explicite** : monolithe modulaire NestJS (`src/modules/*`) avec frontières nettes, extraction possible plus tard si un besoin réel apparaît |
| Blockchain | Non pertinent pour le produit — aucune préparation |
| Systèmes de points / gamification complexe | Records personnels et statistiques d'abord ; défis et classements en extension future |
| 3D lourde (anatomie, avatars) | Médias d'exercices via `MediaAsset` + stockage S3 ; anatomie 2D/3D en extension future |
| Coaching temps réel | Sessions par appareil et notifications (FCM, ajouté avec sa configuration réelle) posent les bases |

Les dossiers `features/nutrition/`, `features/body_metrics/`,
`features/health/` et `features/notifications/` sont également scaffoldés
(vides, `.gitkeep`) : ils matérialisent l'intention sans code mort — aucune
dépendance n'est installée avant son usage réel.

## Extensions futures

Après le MVP, dans un ordre à arbitrer selon la traction :

- **Comptes coachs** et **programmes de coachs** (création, publication,
  suivi de clients) ;
- **Espace web coach** (application web dédiée) et **marketplace** de
  programmes ;
- **Messagerie** coach ↔ pratiquant ;
- **Défis, classements, groupes** (dimension sociale progressive) ;
- **Coaching intelligent** (suggestions de charges, deload, périodisation) ;
- **Apple Health / Health Connect** (entitlement `health_sync` réservé,
  dossier `features/health/` scaffoldé) ;
- **Montres connectées** (Watch / Wear OS) ;
- **Vidéos d'exercices** (le pipeline média S3 arrive dès l'Étape 3) ;
- **Animations Rive avancées** (entitlement `custom_animations` réservé ;
  la dépendance `rive` reste à ajouter le jour où un fichier existera) ;
- **Anatomie 2D/3D** interactive ;
- **Desktop** (Flutter le permet ; les breakpoints du design system couvrent
  déjà les grandes largeurs).

## Monétisation

### Niveaux

| Niveau | Contenu | Statut |
|---|---|---|
| **Gratuit** | Cœur d'usage : bibliothèque d'exercices, un nombre limité de programmes, séances et historique, records de base | MVP |
| **Premium** | Tout le gratuit + programmes illimités, statistiques avancées, exercices premium, sauvegarde cloud, et à terme les entitlements listés ci-dessous | Étape 6 |
| **Coach** | Offre dédiée aux coachs (tableau de bord, clients) | Futur — non construit |

### Distribution et facturation

- **Produits Apple (App Store) et Google (Play Store)** pour le mobile —
  intégration **RevenueCat possible** ; **Stripe** pour le web. Cibles de
  webhooks : `POST /api/v1/webhooks/revenuecat`, `POST /api/v1/webhooks/stripe`
  — **signés** (signature vérifiée avant tout traitement) et **idempotents**
  (journal append-only `SubscriptionEvent`, unicité
  `(provider, externalEventId)`).
- **Périodes** : mensuel et annuel (`billingPeriod: monthly | yearly`).
- **Essais gratuits** pris en charge (`status: trialing`, `trialEndsAt`).
- Détail du modèle de données : `docs/database/schema.md` (section
  Abonnements — Étape 6).

### Entitlements (clés réservées)

Source de vérité **côté serveur** (`UserEntitlement`, lecture O(1)) ; le
client ne fait qu'afficher. Clés prévues :

| Clé | Droit |
|---|---|
| `unlimited_programs` | Programmes illimités |
| `advanced_statistics` | Statistiques avancées |
| `premium_exercises` | Exercices premium du catalogue |
| `health_sync` | Synchronisation Apple Health / Health Connect (futur) |
| `cloud_backup` | Sauvegarde cloud |
| `ai_coaching` | Coach IA (onglet Coach) |
| `coach_dashboard` | Espace coach (futur) |
| `custom_animations` | Animations Rive avancées (futur) |
| `priority_support` | Support prioritaire |

Un entitlement peut aussi être **accordé manuellement** par un administrateur
(Étape 7), tracé dans le journal d'audit.

## Parcours critiques à tester

Ces parcours de bout en bout sont le filet de sécurité du produit : chacun est
couvert par des tests (e2e API, tests d'intégration mobile) au plus tard à la
fin de l'étape qui le complète.

1. **Inscription → validation e-mail → connexion** (Étape 2) ;
2. **Renouvellement de session** : expiration de l'access token → refresh
   rotatif → détection d'une réutilisation de refresh token → révocation de la
   famille de sessions (Étape 2) ;
3. **Création d'un programme** puis lancement d'une séance depuis ce programme
   (Étape 4) ;
4. **Séance hors ligne** : démarrer une séance sans réseau → enregistrer des
   séries (UUID générés côté client) → récupération de la connexion →
   **synchronisation idempotente** (rejeu sans doublon, y compris en cas de
   coupure pendant la synchronisation) → fin de séance et résumé (Étape 4) ;
5. **Cycle Premium** : achat → activation des entitlements côté serveur →
   expiration → dégradation propre côté client → **restauration d'achat**
   (Étape 6) ; webhooks rejoués sans double traitement ;
6. **Suppression de compte** : demande depuis l'app → invalidation des
   sessions → suppression logique puis purge → les données locales de
   l'appareil sont effacées (Étape 2, re-vérifié à chaque étape suivante).

## Correspondance Étapes 1-7 ↔ périmètre

| Étape | Tranche verticale | Périmètre produit livré |
|---|---|---|
| **1 — Fondation** (faite) | Monorepo, API NestJS (health, metrics, enveloppes, sécurité), admin Next.js (statut plateforme, `/login` documenté sans fausse auth), squelette Flutter + design system complet, Docker Compose, CI | Écrans Splash et Accueil provisoire ; aucune fonctionnalité utilisateur |
| **2 — Authentification** | JWT access court + refresh rotatif hashé, Argon2id, sessions par appareil, détection de réutilisation | Inscription, connexion, mot de passe oublié, validation e-mail, onboarding, profil (base), paramètres (base), gestion des appareils, suppression de compte |
| **3 — Exercices** | Catalogue + seed 30+ exercices, cache Redis, premiers médias (S3) | Bibliothèque d'exercices, recherche/filtres, détail d'exercice ; administration du catalogue |
| **4 — Séances** | Offline-first Drift + file de synchronisation idempotente | Programmes, créateur de programme, séance active (séries/poids/répétitions), minuteur de repos, résumé, historique, hors ligne + synchronisation |
| **5 — Progression** | Agrégats, métriques corporelles | Records personnels, statistiques simples, écran Progression, profil enrichi |
| **6 — Abonnements** | Entitlements côté serveur, RevenueCat possible, Stripe web, webhooks idempotents signés | Premium de base, paywall, écran Abonnement, essais, restauration d'achat |
| **7 — Administration** | Rôles/permissions/audit | Admin complet : comptes admin séparés, RBAC, journal d'audit, gestion des utilisateurs et des entitlements |

Chaque étape livre sa tranche **complète** : schéma → API → clients → tests →
documentation. Le périmètre MVP est atteint à la fin de l'Étape 7.
