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
      **« Déplacer / reporter » : FERMÉ le 22 septembre 2026.** Il se fait
      par le PUT existant (l'état complet passe toute permutation, là où un
      `UPDATE` unique violerait `@@unique([programId, weekNumber,
      dayOfWeek])`), et la feuille de la case l'expose désormais : les sept
      jours de la semaine, celui d'origine marqué et inerte. Si le jour
      d'arrivée est pris, **les deux s'échangent** — écraser perdrait une
      séance prévue sans le dire. Une case DÉJÀ honorée ne se déplace pas :
      son identifiant porte le lien avec la séance, et l'emmener ailleurs
      ferait dire au calendrier qu'on s'est entraîné un jour où on ne s'est
      pas entraîné. UNE lecture, UNE écriture : un échange en deux
      enregistrements laisserait entre les deux un programme où la même
      séance occupe deux jours, ou aucun. La règle est pure
      (`program_day_move.dart`, 7 épreuves) et le geste en a 5 de plus.
      Le message de la feuille, enfin, désignait ce geste — « c'est la case
      qu'il faut déplacer » — depuis sa livraison, sans qu'il existe.
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

## PLAN 11 — Cohérence globale  `[~] EN COURS`

Passe finale UX / UI / architecture une fois les plans 1 à 10 livrés. Une
partie est déjà tenue en continu par les gardes du dépôt : tailles de
fichiers, tokens design obligatoires, états
erreur/chargement/vide/hors-ligne, `check.sh` + `check_mobile.sh`.

- [x] **Les décors de la galerie ne vieillissent plus** — 22 septembre 2026.
      Sept dates étaient figées en dur dans les doublures, et les écrans les
      rendent EN ÂGE : la vitrine du produit s'est mise à raconter le
      contraire de ce qu'elle illustre. L'accueil annonçait « 43 jours de
      repos » sous une semaine de constance vide ; les quatre records
      affichaient tous « IL Y A 1 MOIS » à côté de séances « hier » ; la
      carte « Dernière mesure » datait de deux mois ; la carte « Volume
      hebdo · sur la semaine » traçait son axe sur deux jours d'août, sept
      semaines plus tôt ; la courbe cardio « suivie sur six semaines »
      listait des séances d'un mois ; et l'écran d'ARGENT, celui qui doit
      inspirer le plus confiance, annonçait un renouvellement DÉJÀ PASSÉ.
      **La règle, désormais écrite dans les décors** : une date RENDUE à
      l'écran se date relativement à maintenant ; une date qui ne sert que
      d'identifiant peut rester figée. Deux épreuves qui codaient un nom de
      mois ou un ordre d'insertion ont été décorrélées du décor plutôt que
      recalées. Galerie entièrement régénérée et relue.
- [x] **Six états d'écran qui mentaient ou se taisaient** — 22 septembre
      2026. Tous confirmés par lecture de la source avant correction, et
      tous épinglés : sans les correctifs, 6 des 10 épreuves ajoutées
      tombent.
      1. `todayTrainingProvider` figeait « aujourd'hui » au lancement :
         passé minuit, la tuile félicitait encore pour la séance de la
         VEILLE, et la phrase d'état répétait « Séance faite aujourd'hui ».
         Le remède existait deux providers plus bas (`currentDayProvider`),
         appliqué à la semaine de constance et à la maxime — cette tuile
         était restée en arrière. `restSinceLastWorkoutProvider` en
         dépendait aussi : « 3 jours de repos » restait affiché une semaine
         plus tard.
      2. Le catalogue d'offres rendait `SizedBox.shrink()` sur ERREUR, avec
         l'argument du chargement. Sans offres il n'y a plus de porte
         d'achat du tout : la faire disparaître sans un mot laisse croire
         que Premium ne se vend pas. Le chargement garde son silence, lui.
      3. et 4. L'arbitrage erreur/chargement/vide de l'écran Communauté
         avait été écrit pour CINQ sources ; la ligue et les défis entre
         amis sont arrivés après et n'y ont jamais été ajoutés. Leur panne
         effaçait leur section sous un écran qui se déclarait en bon état.
      5. Le geste « tirer pour rafraîchir » de la Communauté attendait un
         `Future.wait` que personne n'entourait : hors ligne, il levait une
         exception non traitée.
      6. L'écran Parcours se décidait sur un avancement `null`, qui vaut
         `null` pendant le chargement ET en cas d'échec : une panne laissait
         tourner l'indicateur indéfiniment, sans reprise — alors que
         l'Academy et l'étape, juste à côté, branchent les trois branches.
      7. La liste garnie des modèles n'avait pas
         `AlwaysScrollableScrollPhysics` : sous Android, une liste qui ne
         déborde pas refuse l'overscroll, et le geste de rapatriement était
         mort exactement après une réinstallation. **Garde STRUCTUREL et dit
         comme tel** : le harnais de test ne reproduit pas ce clamping, donc
         l'épreuve vérifie le réglage, pas son effet.
- [x] **Onze documents qui affirmaient le faux** — 22 septembre 2026. Chaque
      affirmation relue dans la source AVANT correction ; deux d'entre elles
      ont désigné du code à réparer, pas de la prose à réécrire.
      1. `docs/api/README.md` titrait « Endpoints cibles du MVP
         (spécification produit — non implémentés) » et écrivait « aucune de
         ces routes n'existe encore » au-dessus d'un tableau de **dix-huit
         lignes livrées**. Un lecteur qui s'arrêtait à l'en-tête concluait
         que l'API était vide. Le titre dit maintenant ce que le tableau
         montre, et la phrase de clôture renvoie aux signatures réelles.
      2. et 3. Le seed compte **190** exercices ; `README.md`,
         `docs/database/schema.md` et `docs/api/README.md` en annonçaient
         170 tous les trois (les 156 illustrés, eux, étaient justes).
      4. `README.md` décrivait le contrôle des tailles de fichiers comme une
         « règle du dépôt, absente de la CI ». `mobile-ci.yml` l'exécute,
         et l'en-tête de `check_mobile.sh` le disait déjà.
      5. et 6. `docs/product/coach-ia.md` annonçait deux limites tombées :
         « rien sur les apports alimentaires (aucun journal) » — le coach
         lit `get_nutrition_targets` et `get_recent_meals` —, et « aucun
         programme hebdomadaire (le module `programs` n'existe pas
         encore) » — il est livré. La limite tient toujours, mais pour
         l'autre raison : le coach n'a aucun outil dessus.
      7. 8. et 9. `docs/product/progression.md` donnait les ligues pour
         inexistantes, leur ouvrait une « récompense datée » que les ligues
         livrées n'accordent pas (`LeaguesService` n'écrit que dans
         `LeagueMembership`), et laissait ouverte une contradiction TRANCHÉE
         le 19 septembre 2026 dans `community.md`.
      10. `CLAUDE.md` justifiait le seuil des contrôleurs Riverpod par
         quatre fichiers et leurs deux comptes. Les quatre nombres étaient
         faux, et `dashboard_controllers` avait été scindé puis SUPPRIMÉ :
         la règle nommait un fichier inexistant, dans la section même qui
         interdit de recopier les mesures. Les nombres cèdent la place à une
         troisième commande, à côté des deux autres.
      11. `docs/product/citations.md` datait un record frais « d'aujourd'hui
         ou d'hier ». **C'est le code qui avait dérivé, pas la page** :
         `_estFrais` comptait des tranches de 24 heures au lieu de jours
         civils, bornait à `<= 2` une fenêtre de deux jours, et son
         garde-fou `>= 0` laissait passer une date au futur de moins de
         24 heures. Cumulés, ils fêtaient un record jusqu'à près de quatre
         jours après — ou avant qu'il existe, sur une horloge en avance. Le
         compteur de jours civils de `quote_facts.dart`, qui était juste et
         à deux fichiers de là, est devenu public et sert les deux ; il
         perd au passage son erreur d'un jour au changement d'heure d'été.
         Six épreuves bornent les deux extrémités ; sans le correctif, trois
         tombent.
      Un douzième écart, trouvé par la commande de `CLAUDE.md` elle-même :
      `deleteSet` faisait 43 lignes dans `workout_repository_impl.dart`.
      Déplacée dans `WorkoutSessionWriter`, comme `addSet` et `_closeWorkout`
      avant elle. Aucune méthode de repository ne dépasse plus 40 lignes.
- [x] **Le design system reprend ce qui lui appartient** — 22 septembre 2026.
      Quatre règles que le design system ÉNONÇAIT sans que rien ne les
      tienne. Chacune vérifiée dans la source avant d'être corrigée — et
      deux prétendues violations n'en étaient pas, ce qui est dit plus bas.
      1. **La banque d'icônes.** `app_icons.dart` dit depuis sa première
         ligne « les écrans référencent ces noms métier, jamais `Icons.*`
         directement ». Ils le faisaient **106 fois, dans 46 fichiers** —
         plus que les 89 noms déclarés. Vingt-huit étaient des doublons purs
         (`Icons.chevron_right_rounded` à côté d'`AppIcons.chevronRight`) ;
         les autres ont reçu un nom qui dit le SENS — `AppIcons.restDay`,
         pas `Icons.bedtime_outlined`. Au passage, les variantes carrées
         (`Icons.add`, `Icons.remove`, `Icons.logout`, `Icons.smartphone`,
         `Icons.devices_other`) rejoignent la famille arrondie du reste de
         l'application : les `+` et `−` des incrémenteurs n'étaient pas ceux
         des autres écrans. **Et surtout une GARDE**, sans quoi la règle se
         redégrade au premier écran : `check_mobile_icons.sh`, appelé par
         `check_mobile.sh` ET par `mobile-ci.yml`.
      2. **La lueur du bouton principal**, `0 12px 30px -12px` violet,
         déclarée par quatre écrans pour leur compte — trois avec un triplet
         privé `_glowBlur` / `_glowSpread` / `_glowOffset` aux mêmes valeurs
         recopiées. Devenue `AppShadows.ctaGlow(alpha:)` ; seule l'intensité
         diffère réellement (0,7 sur du contenu, 0,5 sur les écrans
         d'entrée, déjà lumineux).
      3. **Le verre dépoli des barres basses** — `ClipRect` +
         `BackdropFilter` 20 + fond à 0,9 + bordure haute — écrit quatre
         fois : fiche d'exercice, séance en cours, éditeur de modèle, et la
         barre de navigation. Devenu `AppTranslucentBar`. Le `ClipRect` y
         est commenté : sans lui, le flou prend TOUT l'écran, pas la barre.
         **Ce regroupement a déplacé un pixel, et c'est la galerie qui l'a
         dit.** La barre de navigation venait d'un `Container`, les trois
         autres d'un `DecoratedBox` — et `Container` ajoute TOUT SEUL
         `decoration.padding`, c'est-à-dire l'épaisseur de la bordure,
         autour de son enfant. Passer au composant commun remontait donc les
         six onglets d'un pixel logique, sur les vingt-trois captures qui
         portent cette barre (0,24 % des pixels, et 0,02 % sur la feuille de
         correction d'un repas, où la barre ne dépasse que d'un filet). La
         marge est reposée explicitement, `AppTranslucentBar.borderWidth` la
         nomme, et la comparaison repasse au vert.
      4. **Quatre `copyWith(fontSize: 12)` sur `AppTypography.label`**, qui
         vaut 12 : du code mort qui se lit comme une décision de taille.
      Et quatre jetons de couleur morts (`violetRampUp`, `ringHole`,
      `primaryFill`, `vignetteBorder`) : inventés en Dart, absents de
      `tokens.json`, appelés nulle part. La règle qui les distingue est
      désormais écrite en tête d'`app_colors.dart` — **un jeton qui reflète
      `tokens.json` n'est jamais mort**, c'est une palette, et la rampe
      neutre 0→950 en est l'exemple : quatre de ses échelons ne servent à
      rien et doivent rester.
      **Deux constats de l'audit étaient FAUX, et la source l'a montré.**
      Les 27 `fontSize:` en dur hors design system ne cassent aucun
      interlettrage : les trois styles dont ils dérivent (`body`, `label`,
      `metricS`) n'en déclarent pas, donc `AppTypography.resized()` y
      rendrait exactement `copyWith`. Et les deux seuls écrans qui dérivent
      un style QUI en porte — la signature et l'accroche de marque —
      réécrivent le leur explicitement à la ligne suivante. Rien à corriger
      là : seuls les quatre no-op l'étaient. De même, les dix jetons de
      couleur « inutilisés » du premier relevé n'étaient que six, le compte
      ayant oublié les références internes à la classe (`ctaStart` et
      `ctaEnd` servent `cta`, deux lignes plus bas).
      **Précision de méthode, apprise ici.** `tool/screenshots/goldens/` est
      dans le `.gitignore` : `git status` ne dira JAMAIS qu'une capture a
      bougé, et prendre son silence pour une preuve revient à ne pas
      regarder. La comparaison se FABRIQUE — on remise le lot, on régénère
      la référence, on remet le lot, puis on rejoue
      `flutter test tool/screenshots` SANS `--update-goldens`. C'est ce qui
      a trouvé le pixel de la barre, qu'une relecture à l'œil n'aurait pas
      vu sur vingt-trois écrans.
      **Et cette comparaison a buté sur un second défaut, dans le décor.**
      Deux captures de nutrition ne coïncidaient avec elles-mêmes à AUCUNE
      exécution : trois repas portaient `DateTime.now().subtract(...)` alors
      que la tuile REND l'heure à la minute. Le commentaire de
      `startOfToday()` prescrivait pourtant déjà de s'y ancrer. La règle des
      décors se dit donc maintenant en deux temps, à l'endroit où on la
      lit : un JOUR se date relativement à maintenant — sans quoi il
      vieillit —, une HEURE se pose en dur dans ce jour — sans quoi elle
      bouge à chaque exécution. Les deux captures sont désormais identiques
      d'une passe à l'autre, vérifié deux fois de suite.
      **Deux captures neuves**, enfin (`pas-01-serie`, `pas-02-poids`) : le
      seul changement visible de la passe — les `+` et `−` des deux feuilles
      de saisie, passés aux glyphes arrondis du reste de l'application —
      n'apparaissait dans AUCUNE image, ces feuilles s'ouvrant par un geste.
      Un changement d'interface qu'aucune capture ne montre ne se relit pas.
      Chacune est posée sur SON écran, avec les vrais widgets et des faits
      plausibles, et le déclencheur vit dans la barre basse, là où la
      feuille le recouvre — un bouton de harnais resté visible se relirait
      comme un bouton du produit.
- [x] **Le lot « code mort » de l'audit : rien à retirer** — 22 septembre
      2026, et c'est un résultat, pas un renoncement. Balayage des deux
      côtés : **zéro** fichier Dart de `lib/` jamais importé ni exporté
      (459 fichiers), et les 28 modules TypeScript que le même balayage
      signale sont tous atteints autrement — les `.test.ts(x)` sont des
      points d'entrée de Vitest, et les trois CLI (`admin-bootstrap`,
      `catalog-seed`, `subscription-catalog`) sont appelés par
      `scripts/server/carlysctl`, `deploy.sh` et `apps/api/package.json`,
      jamais par un `import`. Un balayage qui ne regarde que les `import`
      déclare mort tout ce qu'un shell lance. Les seuls vrais morts de cette
      passe étaient les quatre jetons de couleur ci-dessus.

---

## Hors plans, mais bloquant la publication (rappel)

Ces verrous ne figurent pas dans les onze plans et restent entiers :
les 20 marqueurs `[À COMPLÉTER]` des pages légales (le build de production
admin ÉCHOUE tant qu'ils sont là — faits juridiques, pas du code), l'achat
intégré absent (page Stripe navigateur = refus App Store / Play), le binaire
iOS de production (entitlement Apple, icône, `CFBundleURLTypes` Google), et
les secrets de dépôt non posés.
