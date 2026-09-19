import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/current_day.dart';

/// Le jour que le journal alimentaire affiche, en ÉCART de jours civils avec
/// aujourd'hui : `0` aujourd'hui, `-1` hier.
///
/// Un écart et non une date : une date mémorisée se périme à minuit — « le
/// 18 » resterait sélectionné le 19 tout en s'appelant encore « Aujourd'hui ».
/// L'écart, lui, se recalcule à partir de [currentDayProvider], qui bascule
/// tout seul.
///
/// `autoDispose` : quitter l'écran remet le journal sur aujourd'hui, ce que
/// l'on attend en y revenant plus tard.
final journalDayOffsetProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Jusqu'où le journal se remonte : un an, comme la plage que le serveur
/// accepte en une requête (`MAX_RANGE_DAYS`). Au-delà, ce n'est plus un
/// rattrapage, c'est un historique — et rien ne le montre encore.
const int journalMaxDaysBack = 365;

/// Minuit LOCAL du jour affiché par le journal.
final journalDayProvider = Provider.autoDispose<DateTime>((ref) {
  final today = ref.watch(currentDayProvider);
  final offset = ref.watch(journalDayOffsetProvider);
  return DateTime(today.year, today.month, today.day + offset);
});
