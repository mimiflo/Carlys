import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/nutrition_repository_impl.dart';
import '../../domain/entities/nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';

/// Rapport métabolique courant (calculé côté serveur).
final metabolismReportProvider =
    FutureProvider.autoDispose<MetabolismReport>((ref) {
  return ref.watch(nutritionRepositoryProvider).metabolismReport();
});

/// Actions nutrition : enregistrer le profil puis rafraîchir le rapport.
class NutritionActions {
  NutritionActions(this._repository, this._ref);

  final NutritionRepository _repository;
  final Ref _ref;

  Future<void> saveProfile(MetabolicProfileUpdate update) async {
    await _repository.updateProfile(update);
    _ref.invalidate(metabolismReportProvider);
  }
}

final nutritionActionsProvider = Provider.autoDispose<NutritionActions>((ref) {
  return NutritionActions(ref.watch(nutritionRepositoryProvider), ref);
});
