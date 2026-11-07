import 'package:shared_preferences/shared_preferences.dart';

import '../domain/health_data_source.dart';

/// La santé connectée, telle que CET appareil s'en souvient — par compte.
///
/// Par compte, parce que l'autorisation Health Connect, elle, vaut pour le
/// téléphone : sur un téléphone partagé, le compte suivant n'importe pas les
/// pesées du précédent tant qu'il n'a pas lui-même activé la connexion.
///
/// Même grammaire que `MentorPrefsStore` : une préférence illisible rend le
/// défaut — au pire, la connexion est à réactiver.
class HealthPrefsStore implements HealthImportLedger {
  const HealthPrefsStore();

  static String connectedKey(String userId) => 'health.connected.$userId';
  static String stepsGoalKey(String userId) => 'health.steps.goal.$userId';
  static String importedAtKey(String userId) => 'health.weighings.at.$userId';

  Future<bool> isConnected(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return prefs.getBool(connectedKey(userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setConnected(String userId, {required bool connected}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(connectedKey(userId), connected);
  }

  Future<int?> stepsGoal(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return prefs.getInt(stepsGoalKey(userId));
    } catch (_) {
      return null;
    }
  }

  Future<void> setStepsGoal(String userId, int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(stepsGoalKey(userId), goal);
  }

  @override
  Future<DateTime?> lastImportAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = prefs.getString(importedAtKey(userId));
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      // Illisible : le pire est un import qui relit ses 30 jours, sans
      // doublon puisque l'identifiant dérive de la pesée.
      return null;
    }
  }

  @override
  Future<void> markImported(String userId, DateTime at) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(importedAtKey(userId), at.toUtc().toIso8601String());
  }
}
