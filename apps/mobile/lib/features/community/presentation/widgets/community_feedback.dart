import 'package:flutter/material.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';

const _logger = AppLogger('CommunityFeedback');

/// Exécute un geste qui parle au serveur et en rend compte dans la barre de
/// message : le texte rendu par [gesture] en cas de succès (`null` : rien à
/// dire), sinon l'échec, en disant VRAI : hors ligne n'est pas une panne.
///
/// La communauté vit sur le serveur ; sans ce filet, un appui hors réseau
/// échouerait en silence et l'écran resterait figé sur l'ancien état.
Future<void> runCommunityGesture(
  BuildContext context,
  Future<String?> Function() gesture,
) async {
  String? message;
  try {
    message = await gesture();
  } on AppException catch (exception) {
    _logger.warning('Geste communautaire refusé', error: exception);
    message = communityFailureMessage(exception);
  } on Exception catch (exception) {
    _logger.warning('Geste communautaire en échec', error: exception);
    message = communityFailureMessage(null);
  }
  if (message == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Le mot juste pour un geste qui n'a pas abouti, hors ligne ou pas.
String communityFailureMessage(AppException? exception) {
  return exception is NetworkException
      ? 'Hors connexion : ce geste a besoin du réseau. Réessaie une fois '
            'connecté.'
      : 'Ça n’a pas fonctionné. Réessaie dans un instant.';
}
