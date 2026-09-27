/// Ce qu'on peut faire d'une case DATÉE du calendrier : les gestes que rend
/// la feuille d'une case (`program_calendar_day_sheet.dart`), et que l'écran
/// exécute.
///
/// Extraits de la feuille, qui les réexporte : elle approchait le plafond de
/// 250 lignes d'un widget, et ces types ne dessinent rien.
library;

/// Ce qu'on peut faire d'une case DATÉE du calendrier.
sealed class CalendarDayAction {
  const CalendarDayAction();
}

/// Lancer la séance prévue.
class LaunchDay extends CalendarDayAction {
  const LaunchDay();
}

/// Faire reconnaître par la case une séance déjà faite ce jour-là.
class LinkSessionToDay extends CalendarDayAction {
  const LinkSessionToDay(this.sessionId);

  final String sessionId;
}

/// Détacher la séance que la case reconnaît.
class UnlinkSessionFromDay extends CalendarDayAction {
  const UnlinkSessionFromDay();
}

/// Déplacer la case vers un autre jour de la MÊME semaine.
///
/// La feuille désignait ce geste depuis sa livraison — « c'est la case qu'il
/// faut déplacer » — sans qu'il existe. Une phrase qui renvoie à une action
/// absente est pire qu'un silence : elle fait chercher.
class MoveDayTo extends CalendarDayAction {
  const MoveDayTo(this.dayOfWeek);

  /// 1 (lundi) à 7 (dimanche), la convention de l'API.
  final int dayOfWeek;
}
