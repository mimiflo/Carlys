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

  // États
  static const IconData error = Icons.error_outline_rounded;
  static const IconData empty = Icons.inbox_rounded;
  static const IconData offline = Icons.cloud_off_rounded;
  static const IconData retry = Icons.refresh_rounded;
}
