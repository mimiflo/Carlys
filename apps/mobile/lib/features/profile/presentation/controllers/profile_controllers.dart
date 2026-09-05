import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/data/repositories/progress_repository_impl.dart';
import '../../../progress/domain/entities/progress.dart';

/// Compteur de séances du profil.
///
/// L'API ne sert pas de total « depuis toujours » : la période la plus large
/// (douze mois) fait donc foi. Provider dédié pour rester indépendant de la
/// période sélectionnée dans l'onglet Progrès.
final profileSessionsOverviewProvider =
    FutureProvider.autoDispose<ProgressOverviewEntity>((ref) {
      return ref
          .watch(progressRepositoryProvider)
          .overview(ProgressPeriod.year);
    });
