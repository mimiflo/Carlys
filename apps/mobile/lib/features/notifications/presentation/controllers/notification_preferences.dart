import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/device_token_repository_impl.dart';
import '../../domain/repositories/device_token_repository.dart';

/// Ce que la personne accepte de recevoir, tel que le SERVEUR le connaît.
///
/// Non auto-disposé : l'écran des réglages s'ouvre et se referme, la réponse
/// ne doit pas être redemandée à chaque aller-retour. Une catégorie absente
/// de la carte vaut « acceptée » — c'est la règle du serveur, et la répéter
/// ici éviterait une bascule qui clignote.
final notificationPreferencesProvider =
    FutureProvider<Map<NotificationCategory, bool>>((ref) {
      return ref.read(deviceTokenRepositoryProvider).preferences();
    });

/// Régler une famille de notifications.
class NotificationPreferenceActions {
  const NotificationPreferenceActions(this._ref);

  final Ref _ref;

  /// Enregistre le choix, puis relit : c'est le serveur qui fait foi, et
  /// c'est lui qui coupera réellement l'envoi.
  Future<void> set(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    await _ref
        .read(deviceTokenRepositoryProvider)
        .setPreference(category, enabled: enabled);
    _ref.invalidate(notificationPreferencesProvider);
  }
}

final notificationPreferenceActionsProvider =
    Provider<NotificationPreferenceActions>(NotificationPreferenceActions.new);
