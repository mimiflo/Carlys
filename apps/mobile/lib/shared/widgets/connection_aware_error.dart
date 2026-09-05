import 'package:flutter/material.dart';

import '../../core/errors/app_exception.dart';
import '../../design_system/design_system.dart';

/// L'état d'erreur JUSTE : « hors connexion » quand c'est le réseau qui
/// manque, l'échec générique de la fonctionnalité sinon.
///
/// C'est le statut que le coach affiche depuis toujours quand il n'a pas de
/// réseau — généralisé : un écran qui dépend du serveur ne dit jamais
/// « indisponible » quand la vraie cause est l'absence de connexion.
class ConnectionAwareError extends StatelessWidget {
  const ConnectionAwareError({
    required this.error,
    required this.title,
    required this.onRetry,
    this.message = AppErrorState.retryConnectionMessage,
    this.offlineMessage,
    super.key,
  });

  /// L'erreur reçue — un `NetworkException` bascule sur l'état hors ligne.
  final Object error;

  /// Titre de l'échec GÉNÉRIQUE (serveur en panne, contrat…).
  final String title;

  /// Message de l'échec générique. Par défaut la phrase partagée du design
  /// system, au même tutoiement que la branche hors ligne : un écran ne
  /// change pas de registre selon la panne.
  final String message;

  /// Message hors ligne propre à la fonctionnalité (un défaut sinon).
  final String? offlineMessage;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error is NetworkException) {
      return AppErrorState(
        icon: AppIcons.offline,
        title: 'Hors connexion',
        message:
            offlineMessage ??
            'Cette partie de l’application a besoin du réseau. '
                'Réessaie une fois connecté.',
        onRetry: onRetry,
      );
    }
    return AppErrorState(title: title, message: message, onRetry: onRetry);
  }
}
