import '../../../../core/utilities/formatting.dart';
import '../../../workout_session/domain/services/recovery_advice.dart';

/// « Repos conseillé : 48 h pour pectoraux et triceps, jusqu’à jeudi 18 h ».
///
/// Une virgule et non le cadratin de la maquette : les textes affichés n'en
/// portent pas (`editorial_tone_test.dart`).
///
/// L'échéance est dite en heure LOCALE, arrondie à l'heure SUPÉRIEURE : un
/// repos conseillé ne s'abrège pas d'une minute pour faire un chiffre rond.
/// Passée (séance relue des jours plus tard), elle n'est plus dite : un
/// « jusqu’à jeudi » vieux d'un mois mentirait.
String recoverySentence(RecoveryAdvice advice, {required DateTime now}) {
  final muscles = advice.muscleGroups.map((group) => group.toLowerCase());
  final who = muscles.isEmpty ? '' : ' pour ${_frenchList(muscles.toList())}';
  final head = 'Repos conseillé : ${advice.rest.inHours} h$who';
  if (!advice.until.isAfter(now)) {
    return head;
  }
  final local = advice.until.toLocal();
  final exact = local.minute == 0 && local.second == 0;
  final hour = DateTime(
    local.year,
    local.month,
    local.day,
    local.hour + (exact ? 0 : 1),
  );
  return '$head, jusqu’à ${formatWeekdayName(hour)} ${hour.hour} h';
}

/// « a », « a et b », « a, b et c ».
String _frenchList(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} et ${items.last}';
