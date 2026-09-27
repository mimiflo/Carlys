import 'package:carlys_mobile/features/progress/domain/entities/progress.dart';
import 'package:carlys_mobile/features/progress/presentation/utils/progress_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_progress_repository.dart';

/// LA DONNÉE DE TEST, pas l'application : `pointsMemeSemaine` doit tenir
/// dans UNE semaine quel que soit le fuseau du poste qui lance la suite.
///
/// Posée à minuit UTC, elle débordait sur le dimanche d'avant à l'ouest de
/// Greenwich : `progress_flow_test` échouait sous America/Los_Angeles, à
/// chaque exécution. La CI force Europe/Paris et ne le voyait pas ; ce test
/// s'éprouve sous un fuseau négatif avec
/// `TZ=America/Los_Angeles flutter test test/features/progress`.
void main() {
  test('les deux points sont dans la même semaine, ici comme ailleurs', () {
    expect(weeklyAttendance(pointsMemeSemaine(), ProgressPeriod.week), isNull);
  });
}
