import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';

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
