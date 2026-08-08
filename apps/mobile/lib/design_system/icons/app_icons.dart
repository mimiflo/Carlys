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

  // Actions
  static const IconData add = Icons.add_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_outline_rounded;

  // Métier
  static const IconData nutrition = Icons.restaurant_rounded;
  static const IconData timer = Icons.timer_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData record = Icons.emoji_events_rounded;
  static const IconData bodyMetrics = Icons.monitor_weight_rounded;
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
  static const IconData minus = Icons.remove_rounded;
  static const IconData recovery = Icons.battery_charging_full_rounded;

  /// Jour tenu dans la série de constance.
  static const IconData streak = Icons.local_fire_department_rounded;

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

  // États
  static const IconData error = Icons.error_outline_rounded;
  static const IconData empty = Icons.inbox_rounded;
  static const IconData offline = Icons.cloud_off_rounded;
  static const IconData retry = Icons.refresh_rounded;
}
