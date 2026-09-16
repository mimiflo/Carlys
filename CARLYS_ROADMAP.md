# CARLYS_ROADMAP — le TODO maître

État au 16 septembre 2026, commit `bbaeda1`. Ce fichier est la liste de
travail PERSISTANTE des onze plans : il se met à jour à CHAQUE plan terminé,
et il fait foi contre toute liste recopiée ailleurs — y compris les comptes
rendus de conversation.

Légende : `[ ]` à faire · `[~]` en cours / partiel · `[x]` terminé ET vérifié
(tests exécutés, pas seulement du code écrit) · `[!]` bloqué par un arbitrage
ou un fait extérieur, nommé à chaque fois.

L'audit initial (Étape A) n'a pas été fait de mémoire : il vient d'un
recensement par 11 agents contre le code (HEAD `8fca426`), contre-vérifié par
deux relecteurs adverses, puis complété des huit commits livrés depuis. Chaque
statut ci-dessous a une preuve dans le code ; les chemins cités sont les
fichiers principaux du plan.

## Décisions produit actées (et où elles sont écrites)

Trois demandes de la feuille de route contredisaient des règles écrites du
dépôt. Le propriétaire du produit a tranché, les documents suivent :

1. **Pourcentage de complétion Academy** : demandé deux fois, malgré
   l'exclusion écrite dans `docs/product/academy.md` (« un pourcentage global
   est exclu »). Acté : le pourcentage s'affiche comme une position dans le
   CONTENU (« du pack », « du domaine »), jamais comme un score de la
   personne. Les deux documents (`academy.md`, `progression.md`) sont à
   réécrire pour porter ce nouvel arbitrage — Plan 1.
2. **Défis, ligues, pas** : le principe 5 de `docs/product/community.md`
   (« jamais un classement individuel ») et la promesse de
   `docs/legal/privacy.md` (« ne lit pas les données de santé ») devront être
   réécrits AVANT le code du Plan 7. Réécrire une politique publiée est un
   acte juridique : il se fait en tête de plan, pas en catimini.
3. **Photo et description IA d'un repas** : `privacy.md` promet « Carlys ne te
   demande jamais de photo ». Acté au Plan 6 : la photo est transmise au
   modèle puis JETÉE, jamais stockée — la réécriture de la politique est
   d'autant plus étroite. Reste un arbitrage ouvert : quel droit et quel
   quota (`ai_coaching` ou une clé nouvelle) — voir `[!]` du Plan 6.

---

## PLAN 1 — Carlys Academy  `[~] EN COURS`

Fichiers : `apps/mobile/lib/features/academy/`,
`apps/mobile/assets/academy/pack.json`, `assets/academy/README.md`,
`docs/product/academy.md`, `apps/mobile/test/features/academy/`.

### 1.1 Audit  `[x]`

Fait (recensement + relecture adverse). Verdict : architecture saine
(contenu embarqué `rootBundle`, hors-ligne par construction, zéro dépendance
vers la base d'entraînement — prouvé par test), progression enregistrée en
local (`answered_lessons_store.dart`) + POST serveur en meilleur effort.

### 1.2 Les douze catégories  `[x]`

- [x] Les 12 catégories demandées existent, mot pour mot
      (`domain/entities/academy.dart:15-27`).
- [x] Architecture extensible : une catégorie nouvelle = une entrée d'enum +
      des leçons dans le pack ; l'écran n'affiche que les domaines SERVIS.
- [~] Contenu : 38 leçons, dont 2 seulement dans chacun des huit domaines
      récents. À étoffer (≥ 4 par domaine) + plancher par domaine ajouté au
      test d'intégrité du pack.

### 1.3 Gamification  `[~]`

- [x] Badges de progression : six sceaux, calculés depuis les seuls faits de
      l'Academy (`academy_progress_card.dart`).
- [x] Récompenses visuelles : bandeau de célébration au franchissement d'un
      domaine (`domain_completed_banner.dart`).
- [x] Progression par catégorie : compte + jauge par domaine
      (`academy_domain_header.dart`).
- [ ] Niveaux : sémantique DÉJÀ tranchée (`academy.md` : « ils situent, ne
      notent pas ») et chiffres déjà calculés (`academy_progress.dart`) —
      reste l'affichage, les jalons au journal des récompenses, les tests.
- [ ] Pourcentage de complétion (par catégorie et global) — décision actée
      ci-dessus, documents à réécrire dans le même commit.
- [ ] Quiz de chapitre : « chapitre » = domaine. Quiz multi-questions à la
      fin d'un domaine bouclé, score montré sur l'instant et jamais stocké
      (se tromper fait apprendre — règle écrite du moteur de progression).

### 1.4 Mode Parcours  `[ ]`

Six étapes (Débutant → Nutrition → Entraînement → Récupération → Discipline
→ Optimisation) : manifeste d'étapes référençant des leçons existantes,
progression dérivée des réponses (aucune persistance nouvelle), reprise au
premier chapitre non lu, écran du parcours courant, validation d'étape.
Arbitrage pris : le Parcours n'enferme PAS la navigation libre — les onglets
de domaines restent ouverts, seul l'ordre de VALIDATION des étapes est
séquentiel.

### Préalable serveur (rattaché au Plan 1, livrable sans arbitrage)

- [ ] Lecture serveur des réponses de quiz : `GET /community/quiz-answers`
      n'existe pas, et le POST n'emporte pas le choix retenu. Migration
      (`choiceIndex` sur `QuizAnswer`), route, contrat, bascule
      d'`answered_lessons_store` en cache. Sans quoi ni la progression ni le
      Parcours ne survivent à un changement d'appareil.

---

## PLAN 2 — Explications & éducation  `[x] TERMINÉ`

Fichiers : `apps/mobile/lib/core/explanations/`,
`features/nutrition/domain/nutrition_explanations.dart`,
`features/progression/domain/title_explanations.dart`,
`design_system/components/app_explainable.dart`.

- [x] Système : `Explanation` (trois blocs : ce que c'est, d'où ça sort, ce
      que ça ne dit pas) + feuille, portés par la DONNÉE elle-même.
- [x] IMC (formule, seuils OMS, limites — dont le pratiquant musclé).
- [x] Métabolisme de base (Mifflin-St Jeor en toutes lettres, variations).
- [x] Calories cibles (facteurs, déficit/maintien/surplus, évolution) +
      plancher de sécurité (1200/1500) avec sa propre explication.
- [x] Dépense énergétique, protéines, glucides, lipides, hydratation.
- [x] Masse grasse / masse musculaire : expliquées comme ABSENTES (« nous ne
      les mesurons pas, voici pourquoi ») plutôt qu'estimées.
- La garde : un test lit `metabolism.calculator.ts` et échoue si un chiffre
  cité diverge du serveur. Toute donnée future suit ce gabarit.

---

## PLAN 3 — Le Mentor Carlys  `[ ] À FAIRE`

Zéro occurrence de « mentor » dans le dépôt. Socle prouvé : l'injection par
utilisateur du coach (`systemPerUser`, couverte e2e) et le précédent complet
de l'écran « Profil Carlys » (choix à 4 cartes, persistance, repli d'image).

- [ ] Nom : « Mentor Carlys » accepté comme nom provisoire (décision de la
      feuille de route).
- [ ] Styles (Bienveillant / Exigeant / Athlète / Philosophe) : axe NOUVEAU,
      indépendant du profil Carlys — le profil décrit l'utilisateur, le style
      décrit la VOIX. Les deux briefings se composent (4 + 4 textes, pas 16).
- [ ] Persistance : enum + colonne `mentorStyle` (migration Prisma), DTO,
      contrat, entité Dart tolérante aux valeurs inconnues.
- [ ] Préférences profil : style, activation des interventions, fréquence.
- [ ] Accueil / visite des fonctionnalités : AUCUN moteur de guide n'existe
      (vérifié) — ancrage, ordre, état « déjà vu », rejouable. Le gros du plan.
- [ ] Célébrations transverses à la voix du Mentor (événement + surface +
      déduplication).
- [ ] `docs/product/mentor.md` + mise à jour de `coach-ia.md`.

---

## PLAN 4 — Objectifs / Programmes / Calendrier  `[ ] À FAIRE`

Existant : grille `Program`/`ProgramDay` (semaine N × jour J) éditable à la
main, modèles de séance, `propose_session` du coach (UNE séance, n'écrit
rien). Le seul « objectif » du dépôt est `NutritionGoal`.

- [ ] Objectif d'entraînement : enum extensible (perte de gras, muscle,
      recomposition, Hyrox, marathon, maintien, force, calisthenics) —
      migration + API + onboarding/profil. Coexiste avec l'objectif
      nutritionnel (deux questions distinctes).
- [ ] Entrées de génération au profil : expérience, séances/semaine, durée,
      matériel (`UserEquipment`) — migrations.
- [ ] Génération d'un programme (règles par objectif : fréquence,
      répartition, cardio, progression) — côté serveur, auditables.
- [ ] Calendrier : date de début de `Program` (migration sur table
      déployée), vue semaine datée, déplacer/reporter, fait/manqué — exige le
      lien séance réalisée ↔ jour de programme (migration `WorkoutSession`).
- [!] Prescription ≠ placement : `@@unique([programId, weekNumber,
      dayOfWeek])` interdit deux séances le même jour. Les séparer est une
      MIGRATION DE DONNÉES sur une table déployée — à trancher explicitement
      en tête de plan (deux tables, ou assumer une case = un jour).

---

## PLAN 5 — Nutrition pilier majeur  `[x] TERMINÉ (à confirmer au Plan 11)`

- [x] Emplacement : onglet « Nutrition », 3e des six de la barre.
- [x] « Objectif » déjà reformulé : « Mon plan nutrition »
      (`metabolic_profile_form.dart:172`, `profile_nutrition_settings.dart`).
- [ ] Passe UX finale au Plan 11 (hiérarchie, accès rapide).

---

## PLAN 6 — Ajouter un repas  `[~] PARTIEL`

Existant : saisie manuelle (nom, kcal, 3 macros), journal du jour, suppression.

- [~] Option 2 (manuel) : il manque la QUANTITÉ (aucune colonne nulle part —
      migration), la date choisie (`eatenAt` figé à maintenant), la
      CORRECTION d'un repas (aucun PATCH — migration non requise, route +
      contrat + mobile) et l'historique (le journal n'a pas d'hier alors que
      la lecture par intervalle existe côté serveur).
- [!] Option 1 (base d'aliments) : la SOURCE est un choix produit/juridique —
      CIQUAL (fiable, français, embarquable hors ligne, sans codes-barres),
      Open Food Facts (ODbL, codes-barres, réseau), ou table maison.
      Recommandation : CIQUAL embarquée. À trancher avant toute ligne.
- [ ] Option 4 (description IA) : port d'estimation distinct du coach,
      workflow estimation → correction → validation, marquage « estimé ».
- [ ] Option 3 (photo IA) : photo transmise puis JETÉE (décision actée),
      dépendance de capture, motifs de permission (scripts de bootstrap),
      réécriture de `privacy.md`.
- [!] Droit et quota des estimations IA : `ai_coaching` (30/jour) ou clé
      nouvelle dans `ENTITLEMENT_KEYS` — arbitrage propriétaire.

---

## PLAN 7 — Défis & communauté  `[!] BLOQUÉ EN TÊTE DE PLAN`

Existant : défis mensuels GLOBAUX à deux entrées (sport/culture),
contribution +1 codée en dur, barre collective. Rien d'individuel, rien
entre amis, aucune ligue, aucun pas.

- [!] Préalable : réécrire le principe 5 de `community.md` (le limiter aux
      défis collectifs) et la phrase santé de `privacy.md` + consentement
      dédié. Décision produit actée, actes d'écriture à faire en premier.
- [ ] Défis entre amis : portée, invitation/acceptation, durées (3 j / 7 j /
      30 j, extensible), clôture — modèle de données entier.
- [ ] Généraliser la métrique d'un défi (`CommunityChallenge` ne sait compter
      que +1) : pas, séances, kcal brûlées, temps de course, eau.
- [ ] Ligues Bronze→Diamant sur la régularité : RÈGLES À ÉCRIRE D'ABORD
      (doc), sans repeser un fait déjà compté par l'axe Constance ; clôture de
      période SANS cron (matérialisation paresseuse, comme les défis).
- [ ] Défis communautaires à objectif chiffré : généralisation du présent.
- [ ] Pas : abstraction santé (Health Connect / HealthKit), permissions,
      historique, doublons, révocation. Dépend de la réécriture `privacy.md`.
- [ ] Prérequis transverse : l'eau et les récompenses ne quittent jamais
      l'appareil — remonter ce qui sert une ligue.

---

## PLAN 8 — Progression  `[~] PARTIEL`

- [x] 8.1 Poids : saisie PRÉCISE au champ + date au sélecteur
      (`add_weight_sheet.dart`), correction, suppression avec conséquence
      dite, liste complète (`body_weight_history_sheet.dart`). Le « + / − »
      de la feuille de route est périmé.
- [~] 8.2 Courbe physique : courbe de poids livrée ; PHOTOS non faites —
      `[!]` le stockage est PUBLIC par construction (URL devinable, cache un
      an) : arbitrage lecture privée (URL présignée / relais API) + légal
      avant toute photo de corps.
- [~] 8.3 Courbe performances : courbe par exercice avec records SUR le
      tracé, livrée ; cardio absent tant que durée/distance ne se saisissent
      pas (chantier transverse avec Plans 4 et 7 ; la chaîne serveur accepte
      déjà tout).
- [ ] 8.4 Timeline : rien. `[!]` architecture : les récompenses vivent en
      SharedPreferences sur l'appareil — les remonter au serveur d'abord,
      sinon la frise change d'un appareil à l'autre.

---

## PLAN 9 — Titres & rangs  `[~] QUASI TERMINÉ`

- [x] Explication : feuille des cinq paliers, chaque palier son POURQUOI,
      textes vérifiés en EXÉCUTANT le barème (deux affirmations fausses
      attrapées ainsi).
- [x] Conditions d'obtention : seuils affichés, marque « GRAVÉ » quand un
      titre acquis n'est plus porté.
- [~] Progression vers le suivant : les points sur le total existent sur
      l'accueil ; vérifier qu'un « prochain palier : N points » explicite
      est bien rendu, sinon l'ajouter.
- [ ] Revoir les noms (« Apprenti ») : proposition de noms au propriétaire —
      décision produit, pas de code avant.

---

## PLAN 10 — Citations Carlys  `[~] PARTIEL`

Existant : 60 maximes originales, 12 par valeur (constance, maîtrise,
performance, discipline, équilibre), entrelacées par construction
(`entrelacer()` lève si les listes divergent), rotation par jour.

- [ ] Étendre aux 12 catégories demandées (échec, patience, retour après une
      pause, objectifs atteints…) — étiquetage par contexte plutôt que douze
      listes concurrentes.
- [ ] Affichage CONTEXTUEL : brancher sur les faits réels (retour après X
      jours, record battu, objectif atteint), avec repli sur la rotation.

---

## PLAN 11 — Cohérence globale  `[ ] EN DERNIER`

Passe finale UX / UI / architecture une fois les plans 1 à 10 livrés. Une
partie est déjà tenue en continu par les gardes du dépôt : tailles de
fichiers, tokens design obligatoires, états
erreur/chargement/vide/hors-ligne, `check.sh` + `check_mobile.sh`.

---

## Hors plans, mais bloquant la publication (rappel)

Ces verrous ne figurent pas dans les onze plans et restent entiers :
les 20 marqueurs `[À COMPLÉTER]` des pages légales (le build de production
admin ÉCHOUE tant qu'ils sont là — faits juridiques, pas du code), l'achat
intégré absent (page Stripe navigateur = refus App Store / Play), le binaire
iOS de production (entitlement Apple, icône, `CFBundleURLTypes` Google), et
les secrets de dépôt non posés.
