import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';

/// Changement de mot de passe. Le serveur révoque les AUTRES sessions dans
/// la foulée — la nôtre survit, l'écran n'a donc pas à se déconnecter.
///
/// État `false` au repos, `true` une fois abouti, sur le même patron que
/// `ForgotPasswordController` : l'écran lit `isLoading`, `hasError` et la
/// valeur, et n'a rien à retenir lui-même.
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
