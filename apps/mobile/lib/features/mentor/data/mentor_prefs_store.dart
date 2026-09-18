/// Préférences d'intervention du Mentor, gardées sur l'appareil.
///
/// Locales PAR CHOIX, pas par facilité : elles règlent quand le Mentor
/// parle sur CET écran d'accueil — un réglage d'affichage, comme le thème.
/// La voix, elle, vit sur le profil serveur : c'est elle qui teinte le
/// coach, quel que soit l'appareil.
///
/// Même grammaire que `answered_lessons_store.dart` : des préférences
/// illisibles rendent les défauts plutôt qu'une erreur — le pire d'une
/// lecture ratée est un Mentor qui parle à sa fréquence par défaut.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/mentor_prefs.dart';

class MentorPrefsStore {
  const MentorPrefsStore();

  /// Clés des préférences locales.
  static const String interventionsKey = 'mentor.interventions';
  static const String frequenceKey = 'mentor.frequence';
  static const String visiteVuesKey = 'mentor.visite.vues';
  static const String celebrationsDitesKey = 'mentor.celebrations.dites';

  Future<MentorPrefs> read() async {
    final prefs = await SharedPreferences.getInstance();
    // La promesse d'en-tête se TIENT ici : une valeur d'un autre type fait
    // jeter `getBool`/`getString` — sans ce filet, le Mentor restait muet
    // derrière un provider en erreur au lieu de parler à ses défauts.
    try {
      return MentorPrefs(
        interventionsActives:
            prefs.getBool(interventionsKey) ??
            MentorPrefs.defauts.interventionsActives,
        frequence: MentorFrequency.fromWire(prefs.getString(frequenceKey)),
      );
    } catch (_) {
      return MentorPrefs.defauts;
    }
  }

  Future<void> setInterventionsActives({required bool actives}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(interventionsKey, actives);
  }

  Future<void> setFrequence(MentorFrequency frequence) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(frequenceKey, frequence.wire);
  }

  // ── Visite guidée : les étapes déjà vues ───────────────────────────────

  Future<Set<String>> readVisiteVues() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return (prefs.getStringList(visiteVuesKey) ?? const []).toSet();
    } catch (_) {
      // Illisible : la visite se repropose, elle ne bloque jamais.
      return const {};
    }
  }

  /// IDEMPOTENT : marquer deux fois la même étape n'écrit qu'une entrée.
  Future<void> marquerEtapeVue(String stepId) async {
    final prefs = await SharedPreferences.getInstance();
    final vues = (prefs.getStringList(visiteVuesKey) ?? const []).toSet();
    if (vues.add(stepId)) {
      await prefs.setStringList(visiteVuesKey, vues.toList()..sort());
    }
  }

  /// « Revoir la visite » : l'état repart à zéro, le manifeste ne bouge pas.
  Future<void> reinitialiserVisite() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(visiteVuesKey);
  }

  // ── Célébrations : ce que le Mentor a déjà dit ─────────────────────────

  Future<Set<String>> readCelebrationsDites() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      return (prefs.getStringList(celebrationsDitesKey) ?? const []).toSet();
    } catch (_) {
      // Illisible : le pire est une célébration redite une fois.
      return const {};
    }
  }

  Future<void> marquerCelebrationDite(String rewardId) async {
    final prefs = await SharedPreferences.getInstance();
    final dites = (prefs.getStringList(celebrationsDitesKey) ?? const [])
        .toSet();
    if (dites.add(rewardId)) {
      await prefs.setStringList(celebrationsDitesKey, dites.toList()..sort());
    }
  }
}

final mentorPrefsStoreProvider = Provider<MentorPrefsStore>(
  (ref) => const MentorPrefsStore(),
);
