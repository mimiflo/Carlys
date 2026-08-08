import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Mention de bas d'écran : la souscription se termine hors de l'application
/// et les droits restent décidés par le serveur.
///
/// Aucun tarif n'est annoncé — l'API ne sert pas de catalogue de prix.
class SubscriptionPurchaseNote extends StatelessWidget {
  const SubscriptionPurchaseNote({super.key});

  /// Taille de la mention légale de la maquette 2i.
  static const double _fontSize = 11;

  @override
  Widget build(BuildContext context) {
    return Text(
      'La souscription se fait via l’App Store, Google Play ou le site web. '
      'Vos droits sont toujours validés par le serveur — la restauration '
      'd’achat les réactive automatiquement.',
      textAlign: TextAlign.center,
      style: AppTypography.label.copyWith(
        fontSize: _fontSize,
        height: 1.4,
        color: AppColors.darkTextTertiary,
      ),
    );
  }
}
