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
///
/// [toLocal] traduit l'échéance dans le fuseau de l'appareil ; il ne se
/// remplace qu'en test, la CI tournant en UTC.
String recoverySentence(
  RecoveryAdvice advice, {
  required DateTime now,
  DateTime Function(DateTime moment) toLocal = _deviceLocal,
}) {
  final muscles = advice.muscleGroups.map((group) => group.toLowerCase());
  final who = muscles.isEmpty ? '' : ' pour ${_frenchList(muscles.toList())}';
  final head = 'Repos conseillé : ${advice.rest.inHours} h$who';
  if (!advice.until.isAfter(now)) {
    return head;
  }
  final local = toLocal(advice.until);
  final exact = local.minute == 0 && local.second == 0;
  // Des CHAMPS, pas un instant : `DateTime.utc` les recompose sans qu'un
  // changement d'heure de l'appareil ne les décale. 23 h + 1 devient bien
  // 0 h le lendemain.
  final hour = DateTime.utc(
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

DateTime _deviceLocal(DateTime moment) => moment.toLocal();
