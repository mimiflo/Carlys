import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// État de soumission du formulaire d'inscription.
class RegisterController extends AutoDisposeAsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authControllerProvider.notifier).register(
            email: email,
            password: password,
            displayName: displayName,
          );
    });
  }
}

final registerControllerProvider =
    AsyncNotifierProvider.autoDispose<RegisterController, void>(
  RegisterController.new,
);
