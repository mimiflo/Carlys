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
