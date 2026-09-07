/// Les gestes que l'on fait SUR son compte, une fois connecté : changer son
/// mot de passe, supprimer le compte, redemander l'e-mail de vérification.
///
/// Chacun porte son propre état (`false` au repos, `true` une fois abouti),
/// sur le même patron que `ForgotPasswordController` : l'écran lit
/// `isLoading`, `hasError` et la valeur, et n'a rien à retenir lui-même.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import 'auth_controller.dart';

/// Changement de mot de passe. Le serveur révoque les AUTRES sessions dans
/// la foulée — la nôtre survit, l'écran n'a donc pas à se déconnecter.
class ChangePasswordController extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<void> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      return true;
    });
  }
}

final changePasswordControllerProvider =
    AsyncNotifierProvider.autoDispose<ChangePasswordController, bool>(
      ChangePasswordController.new,
    );

/// Suppression du compte. Deux temps, dans cet ordre : le serveur d'abord
/// (il peut refuser le mot de passe), l'appareil ensuite.
class DeleteAccountController extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<void> submit(String password) async {
    state = const AsyncLoading();

    // Les deux dépendances sont lues AVANT l'appel : l'oubli du compte fait
    // basculer le routeur vers l'écran de connexion, donc démonte cet écran
    // et ce contrôleur avec lui. Après ce point, plus rien ne touche `ref`.
    final repository = ref.read(authRepositoryProvider);
    final auth = ref.read(authControllerProvider.notifier);

    final result = await AsyncValue.guard(() async {
      await repository.deleteAccount(password);
      return true;
    });
    state = result;
    if (result.hasError) return;

    await auth.forgetDeletedAccount();
  }
}

final deleteAccountControllerProvider =
    AsyncNotifierProvider.autoDispose<DeleteAccountController, bool>(
      DeleteAccountController.new,
    );

/// Renvoi de l'e-mail de vérification d'adresse. Le serveur répond pareil si
/// l'adresse est déjà vérifiée : l'écran ne peut donc rien en déduire, il se
/// contente de confirmer que c'est parti.
class EmailVerificationController extends AutoDisposeAsyncNotifier<bool> {
  @override
  Future<bool> build() async => false;

  Future<void> resend() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).resendEmailVerification();
      return true;
    });
  }
}

final emailVerificationControllerProvider =
    AsyncNotifierProvider.autoDispose<EmailVerificationController, bool>(
      EmailVerificationController.new,
    );
