import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minuit LOCAL du lendemain de [moment].
///
/// `add(const Duration(days: 1))` serait faux : `Duration` est une durée
/// ABSOLUE, donc « plus un jour » rend 1 h du matin le dimanche où l'on
/// recule d'une heure, et 23 h la veille quand on avance. Le constructeur
/// `DateTime` raisonne en jour CIVIL : `day + 1` passe au mois puis à
/// l'année suivante tout seul, et rend l'instant local correspondant quel
/// que soit le changement d'heure au milieu.
///
/// La leçon vient de l'hydratation (`LocalWaterStore.prochainMinuit`), qui
/// l'avait apprise seule : elle vit ici pour que le journal alimentaire et
/// l'Academy en héritent au lieu de la réapprendre.
DateTime nextMidnight(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day + 1);

/// Le JOUR CIVIL courant (minuit local), qui se renouvelle DE LUI-MÊME au
/// passage de minuit.
///
/// Ce que ce provider répare : tout ce qui lisait `DateTime.now()` dans un
/// provider observé en permanence figeait « aujourd'hui » au lancement. Les
/// tuiles de l'accueil montraient encore les calories de la veille à 0 h 05,
/// et la question du jour ne changeait jamais sur une application restée
/// résidente — ce que leur documentation promettait pourtant.
///
/// S'en servir plutôt que `DateTime.now()` dès qu'une lecture porte sur
/// « aujourd'hui » : la dépendance suffit à faire recalculer l'écran.
final currentDayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final timer = Timer(nextMidnight(now).difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return today;
});
