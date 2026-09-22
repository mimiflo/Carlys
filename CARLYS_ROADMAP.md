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
   personne. FAIT : les deux documents portent l'arbitrage (`academy.md`
   « il nomme sa base », `progression.md` amendement du test de l'unité),
   et un test d'écran épingle la base nommée.
2. **Défis, ligues, pas** : le principe 5 de `docs/product/community.md`
   (« jamais un classement individuel ») et la promesse de
   `docs/legal/privacy.md` (« ne lit pas les données de santé ») devaient être
   réécrits AVANT le code du Plan 7. Réécrire une politique publiée est un
   acte juridique : il se fait en tête de plan, pas en catimini. FAIT le
   19 septembre 2026 — les deux documents portent l'arbitrage (voir le
   premier point du Plan 7). Le Plan 7 n'est donc plus bloqué par un
   arbitrage ; ce qu'il reste est du code et un document de règles de ligue.
3. **Photo et description IA d'un repas** : `privacy.md` promet « Carlys ne te
   demande jamais de photo ». Acté au Plan 6 : la photo est transmise au
   modèle puis JETÉE, jamais stockée — la réécriture de la politique est
   d'autant plus étroite. Reste un arbitrage ouvert : quel droit et quel
   quota (`ai_coaching` ou une clé nouvelle) — voir `[!]` du Plan 6.

---

## PLAN 1 — Carlys Academy  `[x] TERMINÉ (à confirmer au Plan 11)`

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
- [x] Contenu : 58 leçons (pack v4), chaque domaine en sert au moins 4 —
      20 leçons écrites par ateliers puis relues en ADVERSAIRE (faits +
      forme, 7 corrections appliquées, 2 fautes des relecteurs eux-mêmes
      réparées) ; plancher ≥ 4 par domaine ajouté au test d'intégrité.

### 1.3 Gamification  `[x]`

- [x] Badges de progression : six sceaux, calculés depuis les seuls faits de
      l'Academy (`academy_progress_card.dart`).
- [x] Récompenses visuelles : bandeau de célébration au franchissement d'un
      domaine (`domain_completed_banner.dart`).
- [x] Progression par catégorie : compte + jauge par domaine
      (`academy_domain_header.dart`).
- [x] Niveaux : cinq jalons à seuils ABSOLUS (1/5/12/20/30 — Découverte,
      Exploration, Assiduité, Profondeur, Érudition), affichage seul, AUCUNE
      récompense nouvelle (le journal fête déjà ces franchissements, une par
      niveau compterait deux fois). `academy_level.dart`, tués par mutation.
- [x] Pourcentage de complétion : « X % du pack » (carte) et « % du
      domaine » (en-têtes), TRONQUÉ (100 seulement au contenu bouclé), la
      base toujours nommée — arbitrage consigné dans `academy.md` +
      amendement du test de l'unité dans `progression.md`.
- [x] Quiz de chapitre : « chapitre » = domaine. `domain_quiz_screen.dart`,
      offert par l'en-tête d'un domaine BOUCLÉ, une question à la fois,
      score affiché puis mort avec l'écran PAR CONSTRUCTION (l'écran ne lit
      que le pack, n'écrit nulle part).

### 1.4 Mode Parcours  `[x]`

Livré : six étapes (Débutant → Nutrition → Entraînement → Récupération →
Discipline → Optimisation), manifeste de 32 leçons (`academy_journey.dart`,
intégrité testée : uniquement des identifiants du pack, jamais deux fois la
même), progression DÉRIVÉE des mêmes réponses que le reste (rien à stocker),
reprise automatique (carte d'entrée sur l'écran Academy : étape courante,
Commencer/Reprendre/Terminé), vue des six étapes (`journey_screen.dart`),
écran d'étape réutilisant `LessonCard` avec bandeau « Étape validée » au
franchissement (`journey_stage_screen.dart`). Rien de verrouillé — un test
l'épingle — et une leçon lue hors parcours y compte. Les fiches d'anatomie
et les filières spécialisées restent en exploration libre (choix éditorial
documenté dans `academy.md`).

### Préalable serveur (rattaché au Plan 1, livrable sans arbitrage)

- [x] Lecture serveur des réponses de quiz : migration Prisma
      (`choiceIndex Int?` sur `QuizAnswer`), POST qui emporte le choix
      (facultatif — clients déployés), `GET /community/quiz-answers` (une
      entrée par leçon, la PREMIÈRE fait foi — `distinct` + tri tués par
      mutation en e2e), contrat `quizAnswerRecordSchema`, et
      `AcademyActions.pullAnswers` qui COMBLE le magasin local à
      l'ouverture de l'Academy sans jamais réécrire une réponse locale ni
      inventer un choix inconnu. La progression et le Parcours survivent
      au changement d'appareil.

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

## PLAN 3 — Le Mentor Carlys  `[x] TERMINÉ (à confirmer au Plan 11)`

Livré sur le socle prouvé (`systemPerUser` du coach, précédent « Profil
Carlys ») — `features/mentor/` côté mobile, la voix côté serveur.

- [x] Nom : « Mentor Carlys », provisoire et assumé tel (`mentor.md`) —
      visible dans l'application (feuille du Mentor, groupe de réglages).
- [x] Styles : Bienveillant / Exigeant / Athlète / Philosophe —
      `mentorStyleBriefing` composé avec le briefing de profil par
      `mentorVoiceBriefing` (4 + 4, jamais 16), chaîne vide sans choix,
      aucun nom de style dans le préfixe partagé (cache protégé par spec).
      Le contenu change VRAIMENT : briefings serveur distincts + mots
      d'accueil distincts par voix + célébrations distinctes par voix,
      chacun sous test d'unicité.
- [x] Persistance : enum + colonne `mentorStyle` (migration
      `20260917175451_mentor_style`), DTO, contrat `mentorStyleSchema`,
      `AuthUser.mentorStyle`, entité Dart `MentorStyle.fromWire` (null pour
      toute valeur inconnue). E2e : PATCH indépendant du profil, valeur
      hors liste refusée, les DEUX briefings dans le tour du coach.
- [x] Préférences profil : groupe « Mentor Carlys » (voix, interventions,
      fréquence 2 crans, visite guidée) — voix sur le serveur, interventions
      locales à l'appareil comme le thème, défauts sûrs (actives, cran
      discret).
- [x] Accueil / visite : le MOT du Mentor dans « Pour toi » (rotation
      déterministe par période, voix neutre sans choix) ouvre la feuille du
      Mentor ; visite guidée en 7 étapes (manifeste pur, « déjà vu » local,
      ordre testé, rejouable, table étape → route complète sous test,
      RIEN de verrouillé).
- [x] Célébrations transverses : la récompense fraîche (`isNew`, donc garde
      de première lecture du journal héritée) prend la parole à la voix du
      style, se marque « dite » au premier toucher, ne crée AUCUN score
      (non-concurrence).
- [x] `docs/product/mentor.md` créé ; `coach-ia.md` (composition des deux
      axes), `carlys-profiles.md` (indépendance), `home-screen.md` (Pour
      toi + visite) amendés.

---

## PLAN 4 — Objectifs / Programmes / Calendrier  `[~] EN COURS`

Existant : grille `Program`/`ProgramDay` (semaine N × jour J) éditable à la
main, modèles de séance, `propose_session` du coach (UNE séance, n'écrit
rien). Audit du 17 septembre 2026 : conforme — aucun objectif
d'entraînement, aucune entrée de génération, aucune génération, aucune
date sur `Program`, aucun lien `WorkoutSession` ↔ jour de programme.

- [x] Durcissement inter-tranches (audit adverse de l'application ENTIÈRE,
      demandé le 18 septembre 2026 avant la tranche « génération »).
      **Terminé le 19 septembre 2026** : les dix sous-systèmes ont été
      relus, et les 47 constats confirmés des sept derniers sont traités.
      TREIZE commits, du plus ancien au plus récent : `1b94543`
      (anti-clignotement, matériel sérialisé, `AppChoiceCard`), `6b56dbe`
      (purge des célébrations, gardes de feuille, relais
      `Semantics.onTap`, parité hors-ligne de l'onboarding, DTO
      displayName/birthDate, lecture d'entraînement transactionnelle),
      `c1dd133` (les 13 confirmés : purge vs rapatriement en vol, séance
      active atomique, `doneSetId` rendu à la suppression, corrections non
      écrasées, calendrier qui dit ses échecs, contrat ↔ DTO alignés),
      `7be4f83` (les 15 constats nutrition/Academy/progression :
      `currentDayProvider`, `SerialQueue`, faits de récompense complets),
      `611b484` (jour figé de l'accueil, `dashboard_controllers` scindé et
      rangé en `presentation/providers/`), `69373bd` (les 4 bloquants),
      `81be6d7` (photos du seed vs back-office, P2002 de `createSession`,
      série supprimée rejouée, N+1 des programmes, ordre de suppression
      d'un média, fenêtre d'historique du coach), `c4a6e45` (le compteur
      collectif ne recule plus — `leftAt` ; la paire d'amis est unique en
      base — `userLowId`/`userHighId`), `57e7e87` (trois pages du
      back-office : journal d'audit qui s'annonçait vide, comptes tronqués
      à vingt, brouillon de catégorie qui écrasait un renommage),
      `8e8e079` (le coach ne facture plus deux fois, la communauté se
      rafraîchit), `8b13402` (clé d'idempotence de paiement qui suivait le
      compte, `buy()` qui attrapait un `StateError` jamais levé, Premium
      qui ne fermait pas le tunnel, push mort après suppression de compte,
      bascule de notification muette hors ligne, report d'onboarding sur un
      profil pas encore lu), `b90482d` (états vide et erreur illisibles
      sous le thème Clair, feuille d'explication qui ne défilait pas,
      champ vidé sans un mot), `3ad10c5` (code mort retiré, documentation
      remise d'accord avec le code).

- [x] Objectif d'entraînement : enum `TrainingGoal` 8 valeurs (perte de
      gras, muscle, recomposition, Hyrox, marathon, maintien, force,
      callisthénie) — migration `20260917190658_training_goal`,
      `PATCH /users/me`, `AuthUser.trainingGoal`, onboarding (étape 2
      « Ton entraînement », 6 étapes désormais), profil (« Entraînement »
      → « Mon objectif », feuille à huit cartes). Coexiste avec l'objectif
      nutritionnel — indépendance épinglée par le e2e, wires disjoints
      épinglés par un test Dart. Doc : `docs/product/entrainement-objectifs.md`.
- [x] Entrées de génération au profil : `TrainingExperience`,
      `weeklySessionsTarget`, `sessionMinutesTarget`, `UserEquipment`
      (adossé à la taxonomie `Equipment` du catalogue, slug inconnu refusé
      en 400 nommé, remplacement de liste transactionnel) — migration
      `20260917192528_training_generation_inputs`, `PATCH /users/me`,
      `GET /users/me/training` (manifeste des routes à jour), écran mobile
      « Préparer mon programme » (`/programs/preparation`, profil →
      Entraînement), doublures et tests des deux côtés.
- [x] **Catalogue ouvert à qui n'a aucun matériel** — PRÉALABLE mesuré, pas
      prévu : `equipment` est une CONJONCTION, et quinze mouvements de sol
      exigeaient un TAPIS. Une personne sans matériel n'atteignait que neuf
      exercices, et six groupes musculaires lui étaient fermés ; la
      génération n'avait rien d'honnête à lui proposer. Commits `65e7328`
      (le tapis retiré) puis `30d19fb` (vingt exercices écrits puis relus
      sous trois angles — un doublon entre deux lots, une instruction
      physiquement fausse et quatre classements de matériel corrigés avant
      collage). Catalogue 170 → 190, sans matériel 24 → 46, **11 des 12
      groupes couverts en principal contre 5**. `avant-bras` reste à zéro
      sur tout le catalogue, matériel compris, et le plancher de
      `catalog-data.spec.ts` l'écarte NOMMÉMENT.
- [x] Génération d'un programme (règles par objectif : fréquence,
      répartition, cardio, progression) — côté serveur, auditables.
      **Terminé le 19 septembre 2026**, commits `0f1328b` (serveur) et
      `f4b8a3d` (mobile). `PUT /api/v1/programs/{id}/generate`, moteur PUR
      dans `programs/domain/generation/` (aucune base, aucune horloge,
      aucun hasard — un test-garde lit les sources et le vérifie). Table
      des huit objectifs, chaque ligne portant son `rationale` en français.
      Huit contraintes dures relues par `verify()`, LA MÊME fonction que le
      test rejoue sur les **8 232 combinaisons d'entrées** — et qui a
      trouvé deux défauts réels : vingt séries de pectoraux dans une
      séance, et deux séances lourdes du même groupe à un jour d'écart.
      Migration `20260919163304_generation_de_programme` :
      `Program.generationReport` (un programme reste explicable des mois
      plus tard) et `WorkoutTemplate.generatedFromProgramId` (la
      bibliothèque ne se noie pas). Programme né INACTIF, rejeu rendu tel
      quel. Mobile : bouton « Générer » + feuille de rapport qui montre ce
      que le serveur a dû céder.
      **Reste ouvert, et dit comme tel** : le dos et le biceps sans
      matériel sont OUVERTS, pas résolus (`tirage-a-plat-ventre` travaille
      contre le poids des bras, `curl-auto-resiste` n'a pas de charge
      mesurable) ; MARATHON et HYROX passent par des jours à intitulé
      libre tant que `WorkoutTemplateSet` n'a ni durée ni distance — c'est
      la migration à faire AVANT d'ajouter des exercices d'endurance.
- [x] Calendrier daté — FAIT le 19 septembre 2026. Migration
      `20260919185324_calendrier_date` : `Program.startsOn` (`@db.Date`,
      nullable) et `WorkoutSession.programDayId` (`@db.Uuid`, nullable,
      indexé) — **volontairement SANS clé étrangère** : les lignes
      `ProgramDay` sont détruites puis recréées à chaque enregistrement du
      programme, donc `SetNull` aurait effacé tous les liens au premier
      geste d'édition, `Restrict` cassé le PUT, `Cascade` supprimé des
      séances réalisées. Le lien tient par l'identifiant, stable d'une
      écriture à l'autre — un e2e le prouve en réécrivant le programme
      entre deux lectures. `GET /programs/:id/calendar?week=` rend les SEPT
      jours datés ; leurs états (`done`, `missed`, `before`, `upcoming`,
      `rest`, `free`) sont tous DÉDUITS, aucun stocké. La grille est ancrée
      au LUNDI de la semaine de `startsOn`, et les jours de la semaine 1
      antérieurs au départ sont « hors période » : sans cette nuance,
      commencer un mercredi accueillait par deux cases rouges des séances
      que personne n'avait promis de faire. Mobile : Drift **v7**
      (`programDayId` voyage dans `session.create`, donc lancer depuis le
      calendrier marche HORS LIGNE), écran de calendrier daté, choix du
      premier jour, résumé et légende des couleurs.
      **Reste ouvert, et dit comme tel** : « déplacer / reporter » se fait
      par le PUT existant (l'état complet passe toute permutation, là où un
      `UPDATE` unique violerait `@@unique([programId, weekNumber,
      dayOfWeek])`) — mais AUCUN geste d'écran ne l'expose encore.
- [x] Le calendrier se corrige — FAIT le 22 septembre 2026. Le second
      « reste ouvert » de la tranche 4 est fermé : une séance lancée HORS
      calendrier ne portait l'identifiant d'aucune case, donc elle était
      faite et sa case restait rouge. `PUT
      /programs/{id}/calendar/days/{dayId}/session` la fait reconnaître,
      `null` la détache. **Le jour civil est la seule règle** : une séance
      n'honore une case que si elle a eu lieu CE JOUR-LÀ dans le fuseau de
      la personne — sans cette borne, « marquer comme fait » deviendrait
      « cocher » et le calendrier ne mesurerait plus rien. Trois refus
      nommés (séance d'un autre jour, jour de repos, case ou séance
      d'autrui), reconnaissance EXCLUSIVE en une transaction, réponse = la
      semaine entière (pas de second aller-retour). Aucune migration : la
      colonne `WorkoutSession.programDayId` existait déjà. Mobile : la case
      ouvre une FEUILLE qui dit son état et ne propose que du vrai — les
      séances terminées de ce jour civil, et seulement celles que le serveur
      connaît (une séance en file de synchronisation est nommée, pas tue).
      Tests : 8 e2e, 7 widget. Capture `34b-calendrier-case`.
- [x] Prescription ≠ placement — TRANCHÉ (17 septembre 2026) : on ASSUME
      une case = un jour. `@@unique([programId, weekNumber, dayOfWeek])`
      reste : c'est la grammaire de la grille actuelle, le moindre risque
      sur une table déployée, et « deux séances le même jour » reste
      exprimable par un modèle combiné. Si le besoin réel apparaît un jour,
      l'extension est ADDITIVE (un champ de créneau), pas une refonte.

---

## PLAN 5 — Nutrition pilier majeur  `[x] TERMINÉ (à confirmer au Plan 11)`

- [x] Emplacement : onglet « Nutrition », 3e des six de la barre.
- [x] « Objectif » déjà reformulé : « Mon plan nutrition »
      (`metabolic_profile_form.dart:172`, `profile_nutrition_settings.dart`).
- [ ] Passe UX finale au Plan 11 (hiérarchie, accès rapide).

---

## PLAN 6 — Ajouter un repas  `[~] PARTIEL`

Existant : saisie manuelle (nom, kcal, 3 macros), journal du jour, suppression.

- [x] Option 2 (manuel) : FAIT le 19 septembre 2026. QUANTITÉ descriptive
      (`quantity` + `quantityUnit`, migration `20260919181907`, jamais
      multiplicatrice), DATE et HEURE choisies (`eatenAt` ne vient plus de
      l'instant de saisie, et le futur est refusé à la création comme à la
      correction), CORRECTION sur place (`PATCH /nutrition/meals/:id` —
      absent = inchangé, `null` = effacé), HISTORIQUE (deux flèches, un an en
      arrière, `mealsForDayProvider` par jour civil). Tests : 9 widget/unité
      mobiles, 5 e2e API, captures `30-nutrition-journal` et
      `31-nutrition-correction-repas` régénérées.
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

## PLAN 7 — Défis & communauté  `[~] DÉBLOQUÉ, préalable écrit`

Existant : défis mensuels GLOBAUX à deux entrées (sport/culture),
contribution +1 codée en dur, barre collective. Rien d'individuel, rien
entre amis, aucune ligue, aucun pas.

- [x] Préalable : réécrire le principe 5 de `community.md` (le limiter aux
      défis collectifs) et la phrase santé de `privacy.md` + consentement
      dédié. FAIT le 19 septembre 2026 : `community.md` principe 5 borné aux
      défis COLLECTIFS, avec les trois conditions de tout classement
      (périmètre choisi, fenêtre qui se ferme, aucun report dans le profil)
      et la section finale qui acte l'arbitrage ; `privacy.md` — la phrase
      « ni les données de santé de ton téléphone » retirée, remplacée par une
      section « Les pas de ton téléphone (facultatif, consentement dédié) »
      (pas SEULS, consentement distinct du compte, révocation qui efface),
      base légale au §3, droit de retrait au §7, date de mise à jour.
- [x] Défis entre amis — FAIT le 19 septembre 2026. Migration
      `20260919…_defis_entre_amis` : `FriendChallenge` +
      `FriendChallengeMember`, tables SÉPARÉES de `CommunityChallenge` pour
      quatre raisons mesurées (la lecture des défis collectifs n'a aucun
      prédicat de visibilité ; `@@unique([slug, month])` est l'identité d'un
      défi de catalogue ; la sémantique du départ est INVERSE — partir
      retire du classement individuel, là où quitter un défi collectif
      laisse sa contribution au groupe ; et il n'existait aucun état
      « invité, pas encore accepté »). Ce qui EST partagé : la métrique et
      le chemin d'écriture des contributions — une séance verse aux deux
      familles par le même appel. Garde-fous : on n'invite que des amis
      acceptés et non bloqués (403 indiscernable), 9 invités par défi, 5
      défis ouverts par créateur, `endsAt` CALCULÉ côté serveur, nouvelle
      famille de notification `CHALLENGE_INVITES`. Clôture PARESSEUSE et
      idempotente : la première lecture après la fin fige les rangs
      (`finalRank`), pose `closedAt`, et l'écriture est conditionnée à sa
      nullité — deux lectures simultanées n'en règlent qu'une. Mobile :
      section « Défis entre amis », carte-classement avec MA ligne même
      hors du podium, feuille « Défier mes amis ». Tests : 7 e2e, 7 widget.
- [x] Métrique généralisée — FAIT le 19 septembre 2026. Migration
      `20260919200500_metrique_des_defis` : `CommunityChallenge.metric`,
      rétro-remplie depuis `kind` (SPORT → WORKOUTS, CULTURE →
      QUIZ_CORRECT) par un `UPDATE` écrit à la main entre l'ajout de la
      colonne et son passage en NOT NULL. Les deux méthodes qui portaient
      `+1` en dur fusionnent en `contribute(userId, metric, amount, at)`, et
      une séance terminée verse désormais à TROIS métriques : une séance,
      ses secondes chronométrées série par série (pas sa durée totale,
      pauses comprises), ses mètres parcourus. Le contrat transporte
      `metric`, `unit` et `totalContribution` : la carte écrit « 390 000 /
      500 000 mètres » là où une barre nue ne disait pas ce qu'elle mesurait.
      Quatrième défi du mois ajouté au catalogue (500 km à plusieurs).
      **Reste ouvert, et dit comme tel** : `STEPS` et `WATER_ML` ne sont PAS
      dans l'enum, parce que rien ne les alimente — les pas ne sont pas lus,
      l'eau ne quitte jamais l'appareil. Et toutes les métriques présentes
      sont des ÉVÉNEMENTS : le jour où l'une redéclare un total (les pas
      d'hier resynchronisés), l'incrément devient faux et il faudra un
      registre de totaux quotidiens avec un delta `max(0, nouveau − ancien)`.
      Les kcal brûlées n'ont aucune source dans le dépôt (le TDEE est une
      dépense estimée et statique, pas une mesure) : arbitrage propriétaire
      avant d'en faire une métrique.
- [x] Ligues Bronze→Diamant — FAIT le 19 septembre 2026. Barème ÉCRIT
      D'ABORD dans `community.md` (« Les ligues, barème complet »), puis
      migration `20260919225014_ligues` : `LeagueDivision`,
      `LeagueMembership((userId, periodKey))`, `CommunityPreference.joinsLeague`
      (défaut `false`). Période = SEMAINE ISO en UTC (`YYYY-Www`, chaîne :
      une période est un fait civil). Score = l'EFFORT converti en points
      (séance 50, minute d'effort 1, cent mètres 1, bonne réponse 10),
      versé par la MÊME couture `verser` que les deux familles de défis —
      pas les contributions aux défis, qui feraient dépendre le rang d'avoir
      rejoint le jeu du mois. Montées/descentes : 5 et 5, jamais pour un
      score NUL (aucun axe ne punit une absence), rien si moins de 10
      joueurs, ex æquo partagés. Règlement PARESSEUX à la lecture
      (`settledAt` en clé d'idempotence, `nextDivision` pour que la montée
      survive sans créer une ligne par semaine d'absence). Tests : 18
      unitaires sur le barème, 6 e2e, 10 widget. Captures `37` et `38`.
      **Arbitrage assumé, et écrit comme tel** : le test « si le fait est
      dans `ProgressionFacts` ou `RewardFacts`, la ligue ne le compte pas »
      ne laisse, MESURÉ, que `ACTIVE_SECONDS` et `DISTANCE_METERS` — les
      deux que la fonte produit à zéro. Le test est donc ramené à ce qu'il
      protégeait : la ligue ne rend RIEN au profil (ni point, ni axe, ni
      titre, ni récompense), et c'est vérifiable — aucun des deux
      constructeurs de faits ne connaît `LeagueMembership`. Réversible par
      le propriétaire.
- [ ] Ligues, suite possible : une notification à la montée (le résultat
      s'annonce aujourd'hui à la première lecture, pas en push), et un écran
      dédié si une division de 20 devient trop longue pour une carte.
- [x] Défis communautaires à objectif chiffré — FAIT le 19 septembre 2026,
      par la généralisation de la métrique elle-même. `CommunityChallenge`
      porte déjà `metric`, `target` et `unit`, le contrat transporte
      `totalContribution` BRUT en plus du ratio, et `challenge_card.dart`
      écrit « 390 000 / 500 000 mètres » là où une barre nue ne disait pas
      ce qu'elle mesurait. Rien de plus à livrer : l'item était la
      conséquence de la tranche précédente, pas une tranche de plus.
- [ ] Pas : abstraction santé (Health Connect / HealthKit), permissions,
      historique, doublons, révocation. La dépendance à `privacy.md` est
      LEVÉE (réécriture du 19 septembre 2026, section « Les pas de ton
      téléphone »). Ce qui bloque désormais est MATÉRIEL, et il faut le
      dire : `android/` et `ios/` ne sont pas versionnés (ils se génèrent
      par `bootstrap_mobile.sh`), Health Connect et HealthKit exigent un
      appareil réel pour accorder puis révoquer une permission, et aucun
      test d'ici ne peut voir passer un seul pas. Le livrer à l'aveugle
      reviendrait à poser un faux backend, que les règles interdisent.
      Reste aussi, côté serveur et celui-là testable : les pas sont un
      TOTAL REDÉCLARÉ, pas un événement — il faudra un registre
      `MetricDailyTotal(userId, metric, jour)` et un delta
      `max(0, nouveau − ancien)` écrit dans la même transaction que la
      contribution, sans quoi un téléphone qui resynchronise hier
      rajouterait ses 8 000 pas.
- [x] Prérequis transverse — SANS OBJET pour la ligue livrée. Elle compte
      l'effort déjà connu du serveur (séances, secondes, mètres, quiz) et
      ne demande donc à remonter NI l'eau NI les récompenses, qui restent
      sur l'appareil comme la règle l'exige. Le prérequis redeviendrait
      vrai si une future métrique s'asseyait sur l'eau — auquel cas il
      faudrait rouvrir `privacy.md` §2, ce que la ligue actuelle évite.

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
- [x] 8.3 Courbe performances — COMPLÈTE le 22 septembre 2026. La courbe par
      exercice avec records SUR le tracé était livrée ; le cardio manquait,
      et sa condition (la saisie durée/distance) a été remplie entre-temps.
      `GET /progress/exercises/:id` sert désormais `distanceMeters` et
      `durationSeconds` par séance, SOMMÉS et non maximisés (trois
      fractionnés de 400 m font 1 200 m de course, là où une charge se
      maximise). L'écran choisit la courbe sur les FAITS, jamais sur une
      étiquette d'exercice : plus de séances cardio que chargées → courbe
      cardio, sinon la charge, avec un repli cardio quand une seule séance
      est chargée. En ordonnée, la distance quand elle est notée au moins
      aussi souvent que le chrono, le temps sinon. Les lignes de séance
      suivent — elles écrivaient « — » et « 0 kg » là où il y avait huit
      kilomètres. Les deux courbes partagent leur cadre
      (`progression_chart_frame.dart`), extrait pour l'occasion. Tests :
      1 e2e, 12 widget/unitaires. Capture `39-progression-cardio`.
- [x] 8.4 Timeline — FAIT le 22 septembre 2026. « Ton histoire » :
      `GET /progress/timeline` fusionne séances, mesures, leçons (groupées
      par jour, APRÈS dédoublonnage) et franchissements. La ligne de partage
      est « le fait est-il déjà une ligne datée et corrigible ? » : les trois
      premières sources sont DÉRIVÉES à la lecture, les franchissements
      MATÉRIALISÉS dans `ProgressMilestone` — ce sont les seuls qui ne
      correspondent à aucune ligne (`PersonalRecord` ne garde que le maximum
      courant, un mur de trophées et non une chronologie). Les
      franchissements de record restent une FONCTION des séries, synchronisés
      à chaque `recomputeRecords` : une charge saisie 300 au lieu de 30 fait
      disparaître le franchissement qu'elle avait inventé. Récompenses et
      titres s'IMPORTENT du journal local, la plus ANCIENNE date gagnant par
      un `LEAST` dans l'écriture ; les records ne s'importent jamais. Curseur
      sur le couple `(occurredAt, id)`, en-têtes de mois côté client. Le
      libellé n'est pas en base : le serveur stocke la clé, le client la
      résout dans son catalogue embarqué. Tests : 10 e2e, 8 unitaires sur le
      rejeu des records, 10 widget. Capture `40-progression-frise`.
      **Le préalable annoncé était mal posé**, et mesuré il cachait pire : le
      moteur de récompenses dérivait ses compteurs des 60 séances
      rapatriées, et une médaille gagnée disparaissait en changeant de
      téléphone. Réparé la veille (`GET /progress/lifetime`).
---

## PLAN 9 — Titres & rangs  `[~] QUASI TERMINÉ`

- [x] Explication : feuille des cinq paliers, chaque palier son POURQUOI,
      textes vérifiés en EXÉCUTANT le barème (deux affirmations fausses
      attrapées ainsi).
- [x] Conditions d'obtention : seuils affichés, marque « GRAVÉ » quand un
      titre acquis n'est plus porté.
- [x] Progression vers le suivant — VÉRIFIÉ puis COMPLÉTÉ le 22 septembre
      2026. La carte de titre du profil le disait déjà (« Encore 42 points
      avant Artisan », plus le seuil absolu en regard) ; l'accueil, lui, ne
      montrait que le total et la jauge. La jauge répond à « où j'en suis »,
      pas à « combien encore » — une barre sans son reste à parcourir ne
      donne rien à viser. La phrase est donc ajoutée sous la jauge de
      l'accueil, muette tant que le compteur n'est pas ouvert (annoncer un
      palier à qui n'a pas commencé, c'est montrer une dette) et au dernier
      palier, où il n'y a plus de « prochain ». 4 tests, capture
      `02b-accueil-progression` refaite.
- [ ] Revoir les noms (« Apprenti ») : proposition de noms au propriétaire —
      décision produit, pas de code avant.

---

## PLAN 10 — Citations Carlys  `[x] TERMINÉ (à confirmer au Plan 11)`

Existant : 60 maximes originales, 12 par valeur (constance, maîtrise,
performance, discipline, équilibre), entrelacées par construction
(`entrelacer()` lève si les listes divergent), rotation par jour.

- [x] Étendre aux 12 catégories demandées (échec, patience, retour après une
      pause, objectifs atteints…) — étiquetage par contexte plutôt que douze
      listes concurrentes. `QuoteContext` porte les douze ; une maxime en
      porte plusieurs quand elle sert plusieurs états, ce qui évite douze
      variantes quasi identiques de la même phrase.
- [x] Affichage CONTEXTUEL : brancher sur les faits réels (retour après X
      jours, record battu, objectif atteint), avec repli sur la rotation.
      `buildQuoteFacts()` est PUR (ni horloge, ni base, ni réseau) et
      `contextualQuote()` sert le premier contexte vrai, sinon la rotation
      d'origine, jour pour jour.

**Un défaut LIVRÉ a été trouvé et fermé au passage.** Trois maximes de la
rotation parlaient d'un état qu'elles ne vérifiaient pas — « Après une pause,
reprends plus léger… » s'affichait à tout le monde un jour sur soixante, y
compris à qui s'entraîne depuis six mois sans en manquer une. Le premier
geste du plan n'a donc pas été d'ajouter des maximes, mais de sortir
celles-là de la rotation en les étiquetant. Deux gardes le tiennent : un
garde structurel (aucune maxime de rotation n'est étiquetée, sur deux tours)
et un garde lexical (aucune ne contient un marqueur qui AFFIRME un état).

Le balayage sur soixante jours est le cœur du dispositif : une assertion sur
un seul jour passerait par chance 59 fois sur 60 — c'est-à-dire aussi verte
que la CI l'était pendant que le défaut était livré.

Règle, priorité et sources des faits : `docs/product/citations.md`.

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
