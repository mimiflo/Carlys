/// Le jour du dernier bonjour du coach, gardé sur l'appareil.
///
/// Le bonjour se dit une fois par jour au plus (`shouldGreet`) : sans ce
/// souvenir, il revenait à chaque ouverture de l'écran. Une lecture ratée
/// rend `null` (le bonjour se redit), jamais une erreur qui bloquerait
/// l'écran. Propre au COMPTE : la purge du changement de compte l'efface
/// (`DriftLocalAccountPurge.accountOwnedPreferenceKeys`).
library;

import 'package:shared_preferences/shared_preferences.dart';

class CoachGreetingStore {
  const CoachGreetingStore();

  static const String key = 'coach.bonjour.jour';

  Future<String?> lastDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<void> greeted(String day) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, day);
  }
}
