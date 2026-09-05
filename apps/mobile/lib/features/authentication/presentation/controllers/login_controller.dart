import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// État de soumission du formulaire de connexion.
/// La redirection est assurée par le routeur quand AuthState change.
class LoginController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({required String email, required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(authControllerProvider.notifier)
          .login(email: email, password: password);
    });
  }
}

final loginControllerProvider =
    AsyncNotifierProvider.autoDispose<LoginController, void>(
      LoginController.new,
    );
