import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import 'auth_controller.dart';

/// Suppression du compte. Deux temps, dans cet ordre : le serveur d'abord
/// (il peut refuser le mot de passe), l'appareil ensuite.
class DeleteAccountController extends AutoDisposeAsyncNotifier<bool> {
  /// Le routeur bascule vers l'écran de connexion dès que le compte est
  /// oublié : cet écran, et ce contrôleur avec lui, disparaissent alors au
  /// milieu de `submit`. Le drapeau dit si l'état publié après coup a encore
  /// quelqu'un pour le lire.
  bool _gone = false;

  @override
  Future<bool> build() async {
    ref.onDispose(() => _gone = true);
    return false;
  }

  Future<void> submit(String password) async {
    state = const AsyncLoading();

    // Les deux dépendances sont lues AVANT l'appel : après le premier
    // `await`, `ref` peut déjà avoir été démonté par la bascule du routeur.
    final repository = ref.read(authRepositoryProvider);
    final auth = ref.read(authControllerProvider.notifier);

    final result = await AsyncValue.guard(() async {
      await repository.deleteAccount(password);
      return true;
    });
    if (result.hasError) {
      state = result;
      return;
    }

    // Le contrôleur RESTE en chargement pendant l'oubli local. Publier le
    // succès ici, comme avant, réactivait le bouton rouge alors que la purge
    // tournait encore : un second appui relançait `deleteAccount` sur un
    // compte déjà détruit. Le bouton reste donc inerte jusqu'à la bascule.
    //
    // `forgetDeletedAccount` ne jette pas : une panne du trousseau y est
    // journalisée et la bascule a lieu quand même. Sans cela, l'exception
    // s'échapperait d'un `submit()` que l'écran appelle sans attendre.
    await auth.forgetDeletedAccount();

    // En pratique la bascule a déjà démonté l'écran ; on ne publie que si ce
    // n'est pas le cas, pour ne pas laisser un chargement éternel derrière
    // soi — et jamais sur un contrôleur mort.
    if (_gone) return;
    state = result;
  }
}

final deleteAccountControllerProvider =
    AsyncNotifierProvider.autoDispose<DeleteAccountController, bool>(
      DeleteAccountController.new,
    );
