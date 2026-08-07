import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/data/repositories/progress_repository_impl.dart';
import '../../../progress/domain/entities/progress.dart';

/// Vue « semaine » de l'accueil — indépendante de la période sélectionnée
/// sur l'onglet Progression.
final weekOverviewProvider =
    FutureProvider.autoDispose<ProgressOverviewEntity>((ref) {
  return ref.watch(progressRepositoryProvider).overview(ProgressPeriod.week);
});
