import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Mention de bas d'écran : les mécanismes RÉELS, et rien d'autre. Le
/// paiement se fait chez Stripe, les droits restent décidés par le serveur,
/// et une fois Premium tout se gère depuis le portail de facturation
/// (« Gérer mon abonnement »). Les prix, eux, sont au-dessus, servis par
/// `GET /subscriptions/offers`.
class SubscriptionPurchaseNote extends StatelessWidget {
  const SubscriptionPurchaseNote({super.key});

  /// Taille de la mention légale de la maquette 2i.
  static const double _fontSize = 11;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Le paiement se fait chez Stripe, dans ton navigateur, et tes droits '
      'sont toujours validés par le serveur, jamais par l’application. Une '
      'fois Premium, tu changes de moyen de paiement, consultes tes factures '
      'ou résilies à tout moment depuis « Gérer mon abonnement ».',
      textAlign: TextAlign.center,
      style: AppTypography.label.copyWith(
        fontSize: _fontSize,
        height: 1.4,
        color: AppColors.darkTextTertiary,
      ),
    );
  }
}
