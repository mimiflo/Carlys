/// LE JOURNAL DES RÉCOMPENSES : la mémoire longue de Carlys.
///
/// Le profil se dérive et fluctue ; le journal, lui, n'oublie pas. Une
/// médaille obtenue le reste après trois mois d'arrêt, même si le fait qui
/// l'a value est sorti de la fenêtre d'observation. Il ne s'écrit qu'en
/// AJOUT : rien ne s'y efface jamais, c'est la règle qui rend la promesse
/// tenable — Carlys conserve l'histoire plutôt que de punir les absences.
///
/// La date inscrite est celle de la PREMIÈRE obtention et ne change plus :
/// regagner un cap ne réécrit pas l'histoire.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging/app_logger.dart';

class RewardLedger {
  const RewardLedger();

  static const _logger = AppLogger('RewardLedger');

  /// Clé des préférences locales.
  static const String key = 'progression.recompenses';

  /// Identifiant de récompense vers la date de première obtention.
  Future<Map<String, DateTime>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return const {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const {};
      }
      final entries = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is! String) continue;
        final date = DateTime.tryParse(value);
        if (date != null) entries[entry.key] = date;
      }
      return entries;
    } on FormatException catch (error) {
      // Un journal illisible ne doit pas faire échouer l'écran : les
      // récompenses se re-dériveront des faits à la prochaine lecture, et
      // seules leurs dates seront perdues.
      _logger.warning('Journal des récompenses illisible', error: error);
      return const {};
    }
  }

  /// Inscrit les récompenses ABSENTES du journal, à la date fournie.
  ///
  /// Rend les identifiants réellement inscrits : ce sont eux, et eux seuls,
  /// qui se gravent sous les yeux de l'utilisateur.
  Future<Set<String>> record(
    Iterable<String> rewardIds,
    DateTime earnedAt,
  ) async {
    final current = Map<String, DateTime>.from(await read());
    final added = <String>{};
    for (final id in rewardIds) {
      if (current.containsKey(id)) continue;
      current[id] = earnedAt;
      added.add(id);
    }
    if (added.isEmpty) {
      return const {};
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      key,
      jsonEncode({
        for (final entry in current.entries)
          entry.key: entry.value.toIso8601String(),
      }),
    );
    return added;
  }
}

final rewardLedgerProvider = Provider<RewardLedger>((ref) {
  return const RewardLedger();
});
