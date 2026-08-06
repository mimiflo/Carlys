import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/auth_session_device.dart';

/// Appareils connectés : chargement, révocation ciblée ou globale.
class SessionsController
    extends AutoDisposeAsyncNotifier<List<AuthSessionDevice>> {
  @override
  Future<List<AuthSessionDevice>> build() {
    return ref.watch(authRepositoryProvider).sessions();
  }

  Future<void> revoke(String sessionId) async {
    await ref.read(authRepositoryProvider).revokeSession(sessionId);
    ref.invalidateSelf();
  }

  Future<void> revokeOthers() async {
    await ref.read(authRepositoryProvider).revokeOtherSessions();
    ref.invalidateSelf();
  }
}

final sessionsControllerProvider = AsyncNotifierProvider.autoDispose<
    SessionsController, List<AuthSessionDevice>>(
  SessionsController.new,
);
