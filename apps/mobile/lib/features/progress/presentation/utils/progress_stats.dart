/// Statistiques dérivées de la progression.
///
/// Tout ce que l'écran affiche se calcule ICI, à partir des points réels
/// renvoyés par `/progress/overview` : aucune valeur n'est inventée, et une
/// mesure impossible à établir renvoie `null` plutôt qu'un chiffre factice.
library;

import '../../../../core/utilities/formatting.dart';
import '../../domain/entities/progress.dart';

/// Granularité des points renvoyés par l'API : les séances sont regroupées
/// par jour (période « semaine »), par semaine (« mois ») puis par mois
/// (« année »).
enum ProgressBucket { day, week, month }

ProgressBucket bucketOf(ProgressPeriod period) => switch (period) {
  ProgressPeriod.week => ProgressBucket.day,
  ProgressPeriod.month => ProgressBucket.week,
  ProgressPeriod.year => ProgressBucket.month,
};

/// Sous-ligne des tuiles : décrit la fenêtre analysée, sans chiffre supposé.
String periodCaption(ProgressPeriod period) => switch (period) {
  ProgressPeriod.week => 'Sur la semaine',
  ProgressPeriod.month => 'Sur le mois',
  ProgressPeriod.year => 'Sur l’année',
};

/// Le pas de l'échelle du graphe : un nombre rond (1, 2, 2,5 ou 5 fois une puissance de dix)
/// qui découpe le volume le plus haut en quatre graduations environ.
double volumeScaleStep(double maxVolume) {
  if (maxVolume <= 0) return 1000;
  final raw = maxVolume / 4;
  var magnitude = 1.0;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  for (final factor in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (magnitude * factor >= raw) return magnitude * factor;
  }
  return magnitude * 10;
}

/// Le libellé d'une barre : « lun. 5 » par jour, « 1 sept. » (le début de
/// la semaine) par semaine, « sept. » par mois. Pas de tiret « 1–7 » :
/// l'appli n'affiche aucun tiret de ponctuation (`editorial_tone_test`).
String bucketLabel(DateTime bucketStart, ProgressBucket bucket) {
  final local = bucketStart.toLocal();
  return switch (bucket) {
    ProgressBucket.day => formatWeekdayDay(local),
    ProgressBucket.week => formatDayMonth(local),
    ProgressBucket.month => formatMonthShort(local),
  };
}

/// Ce que le lecteur d'écran dit du graphe : chaque barre, son intervalle et
/// son volume.
String volumeBarsSemantics(List<ProgressPoint> points, ProgressBucket bucket) {
  final unit = switch (bucket) {
    ProgressBucket.day => 'jour',
    ProgressBucket.week => 'semaine',
    ProgressBucket.month => 'mois',
  };
  return [
    'Volume soulevé par $unit',
    for (final point in points)
      '${bucketLabel(point.bucketStart, bucket)} : '
          '${formatThousands(point.volumeKg)} kilos',
  ].join('. ');
}

/// Les bornes et le pas de l'axe du poids : un pas rond (0,1 kg, 0,2, 0,5,
/// 1…) d'environ trois graduations sur l'écart mesuré, et un cran AU-DESSUS
/// de la plus haute mesure, pour que son point ne touche pas le bord.
///
/// La division se lit avec une marge : en flottants, 70,3 / 0,1 vaut
/// 702,999…, et un `floor` nu tombait un cran trop bas — la marge du haut
/// disparaissait pour 70,3, 84,6 ou 90,1 kg.
({double minY, double maxY, double step}) weightAxis(
  double minValue,
  double maxValue,
) {
  var step = 20.0;
  for (final candidate in const [0.1, 0.2, 0.5, 1.0, 2.0, 5.0, 10.0]) {
    if ((maxValue - minValue) / candidate <= 4) {
      step = candidate;
      break;
    }
  }
  const epsilon = 1e-9;
  final minY = (minValue / step + epsilon).floor() * step;
  final maxY = (maxValue / step + epsilon).floor() * step + step;
  return (minY: minY, maxY: maxY, step: step);
}

/// Ce qu'une zone a parcouru depuis la plus ancienne des mesures CHARGÉES :
/// « −3,5 cm depuis le 12 août », « Stable depuis le 12 août », ou, seule,
/// « Première mesure · 12 août ». [entries] va du plus ancien au plus
/// récent, non vide.
///
/// Chargées, pas « la première de toutes » : `/body-metrics` sert les 90
/// mesures les plus récentes d'une zone (`limit` par défaut). Au-delà de
/// 90 tours d'une même zone, l'écart part donc de la 90ᵉ plus récente, et
/// la date affichée le dit.
///
/// L'écart est écrit sans jugement — ni vert ni rouge : un tour de taille
/// qui baisse et un tour de bras qui monte sont deux bonnes nouvelles, et
/// l'écran ne sait pas laquelle la personne cherche.
String measurementTrend(List<BodyMetricEntry> entries) {
  final first = entries.first;
  final depuis = formatDayMonth(first.measuredAt);
  if (entries.length == 1) {
    return 'Première mesure · $depuis';
  }
  // Au dixième, comme la saisie : 82,3 − 80,1 vaut 2,1999… en flottants.
  final delta = ((entries.last.value - first.value) * 10).round() / 10;
  if (delta == 0) {
    return 'Stable depuis le $depuis';
  }
  final signe = delta > 0 ? '+' : '−';
  return '$signe${formatDecimal(delta.abs())} ${first.kind.unit} '
      'depuis le $depuis';
}
