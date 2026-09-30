import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/repositories/carlys_profile_repository_impl.dart';
import '../../domain/entities/carlys_profile.dart';

/// Choix du profil : écrit au serveur PUIS rafraîchit l'utilisateur — la
/// sélection affichée vient toujours de `AuthUser.carlysProfile`, une seule
/// source de vérité, y compris en démo.
///
/// `Provider` simple (PAS autoDispose) : la référence est capturée dans des
/// callbacks tardifs — même leçon que les actions communauté.
class CarlysProfileActions {
  CarlysProfileActions(this._ref);

  final Ref _ref;

  Future<void> choose(CarlysProfile profile) async {
    await _ref.read(carlysProfileRepositoryProvider).choose(profile);
    await _ref.read(authControllerProvider.notifier).refreshProfile();
  }
}

final carlysProfileActionsProvider = Provider<CarlysProfileActions>(
  CarlysProfileActions.new,
);

/// Identité Carlys de l'utilisateur courant, ou `null` tant qu'elle n'est
/// pas choisie (ou que la session n'est pas restaurée) : `null` signifie
/// « pas de personnalisation », jamais un profil par défaut.
final currentCarlysProfileProvider = Provider<CarlysProfile?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return switch (auth) {
    AuthAuthenticated(:final user) => user?.carlysProfile,
    _ => null,
  };
});
