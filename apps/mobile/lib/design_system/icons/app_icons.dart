import 'package:flutter/material.dart';

/// Icônes sémantiques Carlys.
///
/// Les écrans référencent ces noms métier, jamais Icons.* directement :
/// changer de banque d'icônes ne touche alors qu'à ce fichier.
abstract final class AppIcons {
  // Navigation principale
  static const IconData home = Icons.home_rounded;
  static const IconData workout = Icons.fitness_center_rounded;
  static const IconData programs = Icons.event_note_rounded;
  static const IconData progress = Icons.insights_rounded;
  static const IconData profile = Icons.person_rounded;

  // Champs et entrées de compte
  static const IconData mail = Icons.mail_outline_rounded;
  static const IconData personOutline = Icons.person_outline_rounded;

  /// Le logotype Apple de la banque Material — pour l'entrée « Continuer
  /// avec Apple », le seul cas où une marque tierce s'affiche en icône.
  static const IconData apple = Icons.apple;

  // Actions
  static const IconData add = Icons.add_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData settings = Icons.settings_rounded;

  /// L'entrée des réglages, en tête du profil : le rouage au trait, qui se
  /// pose sur un disque sans l'alourdir.
  static const IconData settingsOutline = Icons.settings_outlined;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;

  // Métier
  static const IconData nutrition = Icons.restaurant_rounded;
  static const IconData timer = Icons.timer_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData record = Icons.emoji_events_rounded;
  static const IconData bodyMetrics = Icons.monitor_weight_rounded;

  /// Protéines — et non la BALANCE de `bodyMetrics`, qui parlait de pesée
  /// corporelle au milieu d'un résumé nutritionnel.
  static const IconData protein = Icons.egg_alt_rounded;
  static const IconData premium = Icons.workspace_premium_rounded;

  static const IconData exercises = Icons.sports_gymnastics_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData trendingUp = Icons.trending_up_rounded;
  static const IconData calendar = Icons.calendar_month_rounded;
  static const IconData filter = Icons.tune_rounded;
  static const IconData bookmark = Icons.bookmark_border_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;

  /// Renvoi vers une lecture, là où le chevron dirait « déplier ».
  static const IconData arrowForward = Icons.arrow_forward_rounded;

  // ── Barres de titre de section (accueil) ──────────────────────────
  /// L'état du jour, par opposition à la semaine ou à l'histoire.
  static const IconData today = Icons.today_rounded;

  /// L'eau bue dans la journée.
  static const IconData water = Icons.water_drop_rounded;

  /// La séance à lancer : ce qui met en marche, pas ce qui s'entraîne.
  static const IconData spark = Icons.bolt_rounded;

  /// Le titre porté sur le profil de progression.
  static const IconData rank = Icons.military_tech_rounded;

  /// Ce que Carlys a retenu pour toi, sans que tu l'aies demandé.
  static const IconData forYou = Icons.auto_awesome_rounded;

  /// La question du jour.
  static const IconData question = Icons.help_rounded;

  /// La forme du jour, lue sur les séances de la semaine.
  static const IconData form = Icons.monitor_heart_rounded;

  /// L'invite à toucher une réponse.
  static const IconData touch = Icons.touch_app_rounded;

  /// Le cap d'une identité Carlys : ce sur quoi on bâtit.
  static const IconData foundation = Icons.foundation_rounded;
  static const IconData minus = Icons.remove_rounded;
  static const IconData recovery = Icons.battery_charging_full_rounded;

  /// Jour tenu dans la série de constance.
  static const IconData streak = Icons.local_fire_department_rounded;

  // Récompenses du profil de progression — une forme par famille : le badge
  // marque un premier pas, la médaille un cap tenu, le certificat un
  // engagement long, la couronne un titre.
  static const IconData badge = Icons.military_tech_rounded;
  static const IconData medal = Icons.emoji_events_rounded;
  static const IconData certificate = Icons.workspace_premium_rounded;
  static const IconData crown = Icons.auto_awesome_rounded;

  // Profil : les portes vers ce qu'on a construit.
  /// L'objectif d'entraînement choisi — la cible, pas le fanion d'un cap.
  static const IconData objective = Icons.track_changes_rounded;

  /// L'évolution chiffrée, ouverte depuis le profil.
  static const IconData statistics = Icons.bar_chart_rounded;

  /// La COLLECTION des récompenses, toutes familles confondues : le trophée,
  /// quand `badge` ne dessine qu'une famille.
  static const IconData rewards = Icons.emoji_events_rounded;

  // Ligue : ce qui rapporte des points, et le classement.
  /// La ligue elle-même, en tête de sa carte : la coupe qu'on vise.
  static const IconData leagueTrophy = Icons.emoji_events_rounded;

  /// Les points d'une SÉANCE terminée.
  static const IconData leagueSessionPoints =
      Icons.local_fire_department_rounded;

  /// Les points d'une minute d'EFFORT chronométrée.
  static const IconData leagueEffortPoints = Icons.bolt_rounded;

  /// Les points de la DISTANCE parcourue.
  static const IconData leagueDistancePoints = Icons.directions_run_rounded;

  /// Le classement complet, ouvert depuis le podium.
  static const IconData ranking = Icons.bar_chart_rounded;

  // Univers de marque (page de bienvenue)
  static const IconData brandApp = Icons.smartphone_rounded;
  static const IconData brandAcademy = Icons.school_rounded;
  static const IconData brandEvents = Icons.emoji_events_rounded;
  static const IconData brandWear = Icons.checkroom_rounded;
  static const IconData goal = Icons.flag_rounded;
  static const IconData units = Icons.straighten_rounded;
  static const IconData theme = Icons.dark_mode_rounded;
  static const IconData notifications = Icons.notifications_rounded;
  static const IconData devices = Icons.devices_rounded;
  static const IconData logout = Icons.logout_rounded;

  // Compte : ce qu'on fait SUR son compte, pas dans l'application.
  /// Changer son mot de passe — la clé qu'on remplace, pas le cadenas fermé.
  static const IconData password = Icons.lock_reset_rounded;

  /// Supprimer son compte : un geste irréversible sur une personne, pas la
  /// suppression d'une ligne (qui, elle, porte `delete`).
  static const IconData deleteAccount = Icons.person_remove_outlined;

  /// Adresse e-mail pas encore vérifiée.
  static const IconData emailUnverified = Icons.mark_email_unread_outlined;

  // Textes légaux, servis sur le web : on SORT de l'application pour les
  // lire, d'où le renvoi externe plutôt qu'un chevron.
  static const IconData privacy = Icons.privacy_tip_outlined;
  static const IconData terms = Icons.description_outlined;
  static const IconData externalLink = Icons.open_in_new_rounded;

  // Mentor Carlys : le guide, sa parole, ses voix.
  /// L'emblème du Mentor : la boussole du guide — pas l'étincelle du coach.
  static const IconData mentor = Icons.explore_rounded;

  /// Le mot que le Mentor adresse, cité tel quel.
  static const IconData quote = Icons.format_quote_rounded;

  /// La visite guidée : le fanion du guide qui fait faire le tour.
  static const IconData tour = Icons.tour_rounded;

  /// La communauté — le même dessin que son onglet.
  static const IconData community = Icons.group_rounded;

  // Les quatre voix du Mentor, une image par ton.
  static const IconData voiceBienveillant = Icons.volunteer_activism_rounded;
  static const IconData voiceExigeant = Icons.track_changes_rounded;
  static const IconData voiceAthlete = Icons.fitness_center_rounded;
  static const IconData voicePhilosophe = Icons.self_improvement_rounded;

  // Coach IA
  static const IconData coach = Icons.auto_awesome_rounded;
  static const IconData coachOutline = Icons.auto_awesome_outlined;
  static const IconData send = Icons.arrow_upward_rounded;

  /// Précision neutre — jamais une erreur, jamais une alerte.
  static const IconData info = Icons.info_outline_rounded;

  // Profils Carlys : l'entrée du réglage, et les replis tant que les
  // illustrations ne sont pas fournies.
  static const IconData carlysProfile = Icons.badge_rounded;
  static const IconData profileConstructeur = Icons.architecture_rounded;
  static const IconData profileChallenger = Icons.trending_up_rounded;
  static const IconData profileAthlete = Icons.fitness_center_rounded;
  static const IconData profileStratege = Icons.psychology_rounded;

  // Code ami : le QR que l'on montre, la caméra qui le lit
  static const IconData qrCode = Icons.qr_code_2_rounded;
  static const IconData qrScan = Icons.qr_code_scanner_rounded;

  // États
  static const IconData error = Icons.error_outline_rounded;
  static const IconData empty = Icons.inbox_rounded;
  static const IconData offline = Icons.cloud_off_rounded;
  static const IconData retry = Icons.refresh_rounded;

  // ── Programme et calendrier ───────────────────────────────────────
  // Les états d'un jour, chacun sous sa forme : un jour se lit d'un coup
  // d'œil, donc le glyphe porte l'état avant que la couleur ne l'appuie.
  static const IconData restDay = Icons.bedtime_outlined;
  static const IconData trainingDay = Icons.directions_run_rounded;
  static const IconData dayDone = Icons.check_circle_outline_rounded;
  static const IconData dayMissed = Icons.remove_circle_outline_rounded;
  static const IconData dayUpcoming = Icons.schedule_rounded;
  static const IconData startDay = Icons.play_circle_outline_rounded;

  /// Le calendrier en trait fin, quand il DÉSIGNE un programme plutôt que
  /// d'ouvrir une date ([calendar], plein, fait cela).
  static const IconData calendarOutline = Icons.calendar_month_outlined;
  static const IconData programOutline = Icons.event_note_outlined;

  /// Détacher la séance rattachée à un jour — l'inverse du lien, pas sa
  /// suppression : la séance reste, seul le rattachement tombe.
  static const IconData unlink = Icons.link_off_rounded;
  static const IconData clearEntry = Icons.backspace_outlined;
  static const IconData uncheckedCircle = Icons.circle_outlined;
  static const IconData date = Icons.event_outlined;
  static const IconData time = Icons.schedule_outlined;
  static const IconData playFilled = Icons.play_circle_fill_rounded;
  static const IconData dragHandle = Icons.drag_indicator_rounded;

  // ── Communauté ────────────────────────────────────────────────────
  static const IconData block = Icons.block_rounded;
  static const IconData report = Icons.flag_outlined;
  static const IconData addFriend = Icons.person_add_alt_1_outlined;

  /// Le bouton-disque « Ajouter un ami » de l'en-tête Communauté : le groupe
  /// de la maquette, avec son « + » — il dit AJOUTER, là où `community` ne
  /// dit que la section.
  static const IconData inviteFriends = Icons.group_add_rounded;

  // ── Défi entre amis (écran de détail) ─────────────────────────────
  /// « Comment ça se joue » : la ligne d'arrivée, pas une récompense.
  static const IconData challengeRules = Icons.sports_score_rounded;

  /// Le mot de celui qui a lancé le défi.
  static const IconData challengeMessage = Icons.chat_bubble_outline_rounded;

  /// Le menu d'un écran poussé, en en-tête (« … ») : signaler, quitter.
  static const IconData screenMenu = Icons.more_horiz_rounded;
  static const IconData communityOutline = Icons.group_outlined;
  static const IconData encouragementHeart = Icons.favorite_rounded;
  static const IconData encourage = Icons.volunteer_activism_outlined;
  static const IconData challengeOutline = Icons.emoji_events_outlined;
  static const IconData leagueOutline = Icons.military_tech_outlined;
  static const IconData academyOutline = Icons.school_outlined;
  static const IconData overflow = Icons.more_vert_rounded;

  /// L'identifiant public qu'on partage pour être ajouté — d'où l'arobase,
  /// et non un QR ([qrCode], qui est l'autre chemin vers le même but).
  static const IconData friendCode = Icons.alternate_email_rounded;

  /// Le sens d'une place en ligue. [trendingUp] complète la paire ; le
  /// trait plat dit « ni montée ni descente », ce qu'une flèche ne sait
  /// pas dire.
  static const IconData trendingDown = Icons.trending_down_rounded;
  static const IconData trendingFlat = Icons.horizontal_rule_rounded;

  // ── Profil corporel et objectifs (embarquement) ───────────────────
  static const IconData male = Icons.male_rounded;
  static const IconData female = Icons.female_rounded;
  static const IconData birthDate = Icons.cake_rounded;
  static const IconData birthDateOutline = Icons.cake_outlined;

  /// Les niveaux d'activité, du canapé à l'athlète. Les deux plus hauts
  /// réemploient [workout] et [spark], déjà chargés de ce sens.
  static const IconData activitySedentary = Icons.weekend_rounded;
  static const IconData activityLight = Icons.directions_walk_rounded;
  static const IconData activityModerate = Icons.directions_run_rounded;

  /// Les objectifs d'entraînement qui n'ont pas déjà leur glyphe ailleurs.
  static const IconData goalRecomposition = Icons.autorenew_rounded;
  static const IconData goalHyrox = Icons.sports_score_rounded;
  static const IconData goalMarathon = Icons.directions_run_rounded;
  static const IconData goalMaintenance = Icons.balance_rounded;

  // ── Academy : les illustrations de leçon ──────────────────────────
  static const IconData lessonPosture = Icons.accessibility_new_rounded;
  static const IconData lessonCardio = Icons.directions_run_rounded;
  static const IconData lessonHealth = Icons.health_and_safety_outlined;
  static const IconData lessonHeart = Icons.monitor_heart_outlined;
  static const IconData lessonExpand = Icons.keyboard_arrow_down_rounded;

  // ── Listes et replis ──────────────────────────────────────────────
  static const IconData expand = Icons.expand_more_rounded;
  static const IconData collapse = Icons.expand_less_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;

  /// Puce d'énumération — un disque plein, pas une icône de sens.
  static const IconData bullet = Icons.circle;

  // ── Compte et appareils ───────────────────────────────────────────
  static const IconData device = Icons.smartphone_rounded;
  static const IconData editOutline = Icons.edit_outlined;
  static const IconData emailSent = Icons.mark_email_read_outlined;

  // ── Repas (écran « Ajouter / Modifier ce repas ») ─────────────────
  // Le moment de la journée : la course du soleil, puis la lune, et la tasse
  // d'une pause. Le petit-déjeuner prend le soleil LEVANT, pour que les deux
  // repas du jour ne portent pas le même dessin.
  static const IconData mealBreakfast = Icons.wb_twilight_rounded;
  static const IconData mealLunch = Icons.wb_sunny_rounded;
  static const IconData mealDinner = Icons.nightlight_round;
  static const IconData mealSnack = Icons.local_cafe_rounded;

  /// Prendre ou changer la photo de son plat — et, dans la feuille qui
  /// s'ouvre alors, « Prendre une photo ».
  static const IconData mealPhoto = Icons.photo_camera_rounded;

  /// « Choisir dans la galerie » : une photo déjà prise.
  static const IconData mealPhotoGallery = Icons.photo_library_rounded;

  /// « Retirer la photo » : l'image barrée, pas la corbeille, qui
  /// supprimerait le REPAS.
  static const IconData mealPhotoRemove = Icons.hide_image_rounded;

  /// La QUANTITÉ mangée : la balance de cuisine, pas celle du pèse-personne
  /// ([bodyMetrics]).
  static const IconData mealQuantity = Icons.scale_rounded;

  /// Les valeurs nutritionnelles d'un repas, en parts.
  static const IconData mealValues = Icons.pie_chart_rounded;

  /// La liste des aliments qui composent un repas.
  static const IconData mealFoods = Icons.format_list_bulleted_rounded;

  /// Ajouter un aliment à la composition.
  static const IconData addFood = Icons.add_circle_outline_rounded;

  /// La base d'aliments pas encore chargée sur le serveur : elle ARRIVE,
  /// la saisie à la main reste possible.
  static const IconData foodDatabasePending = Icons.hourglass_top_rounded;

  // Les quatre valeurs d'un repas. Les protéines gardent le dessin de
  // [protein], celui de l'accueil : une valeur, un dessin.
  static const IconData nutrientEnergy = Icons.local_fire_department_rounded;
  static const IconData nutrientCarbs = Icons.grass_rounded;
  static const IconData nutrientFat = Icons.opacity_rounded;

  // Les familles d'aliments de la table CIQUAL : la vignette d'un aliment,
  // faute de photo dans la table.
  static const IconData foodDishes = Icons.dinner_dining_rounded;
  static const IconData foodPlants = Icons.eco_rounded;
  static const IconData foodCereals = Icons.bakery_dining_rounded;
  static const IconData foodProteins = Icons.set_meal_rounded;
  static const IconData foodDairy = Icons.local_drink_rounded;
  static const IconData foodDrinks = Icons.emoji_food_beverage_rounded;
  static const IconData foodSweets = Icons.cake_rounded;
  static const IconData foodFrozen = Icons.icecream_rounded;
  static const IconData foodFats = Icons.opacity_rounded;
  static const IconData foodPantry = Icons.soup_kitchen_rounded;
  static const IconData foodInfant = Icons.child_care_rounded;

  // ── Popups (AppNotices, showAppConfirm, showAppPrompt) ────────────
  // Le glyphe du médaillon, en haut de la carte : il dit le GENRE de ce qui
  // s'affiche avant qu'on le lise. Des glyphes pleins et sans cercle quand
  // c'est possible : le médaillon EST déjà le cercle.

  /// Message passager neutre : ce qui vient de se passer, sans jugement.
  ///
  /// Exception : la banque Material n'a aucun « i » sans cercle. En trait,
  /// ce second cercle reste un filet discret dans le médaillon ; plein, ce
  /// serait un disque blanc posé dans le disque violet.
  static const IconData noticeInfo = Icons.info_outline_rounded;

  /// Un geste a abouti.
  static const IconData noticeSuccess = Icons.check_rounded;

  /// Un geste n'a PAS abouti : le point d'exclamation seul, le cercle de
  /// [error] en dessinerait un second dans le médaillon.
  static const IconData noticeError = Icons.priority_high_rounded;

  /// Une notification reçue pendant qu'on utilise l'application.
  static const IconData noticePush = Icons.notifications_active_rounded;

  /// Une question posée avant un geste (« Terminer la séance ? »).
  static const IconData confirmQuestion = Icons.question_mark_rounded;

  /// Une question posée avant un geste qui supprime ou retire.
  static const IconData confirmDelete = Icons.delete_rounded;

  /// Terminer une séance : la ligne d'arrivée.
  static const IconData confirmFinish = Icons.flag_rounded;

  /// Quitter ce qu'on a commencé : un défi, une séance, une édition.
  static const IconData confirmLeave = Icons.logout_rounded;

  /// Reprendre ce qui tourne déjà (la séance en cours) plutôt qu'en lancer
  /// une autre.
  static const IconData confirmResume = Icons.play_arrow_rounded;

  /// Retirer une personne de ses amis.
  static const IconData confirmRemoveFriend = Icons.person_remove_rounded;

  /// Une saisie courte demandée dans une popup : un nom, un libellé.
  static const IconData promptEdit = Icons.edit_rounded;
}
