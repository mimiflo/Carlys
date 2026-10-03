import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import 'coach_header.dart';

/// Le coach fait partie de l'abonnement : sans le droit, on explique et on
/// mène à l'écran d'abonnement — on ne laisse pas une porte fermée sans clé.
class CoachPremiumState extends StatelessWidget {
  const CoachPremiumState({super.key});

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: AppIcons.premium,
      title: 'Le coach est réservé à Premium',
      message:
          'Il lit tes séances, tes records et tes mesures pour adapter '
          'ton entraînement, et te propose une séance prête à lancer.',
      actionLabel: 'Voir Premium',
      onAction: () => GoRouter.of(context).go(AppRoutes.subscription),
    );
  }
}

/// Cadre commun des états non conversationnels : même fond, même en-tête et
/// même réserve sous la barre d'onglets que l'écran plein.
///
/// L'en-tête en fait partie, et ce n'est pas décoratif : un coach qui n'a pas
/// pu s'ouvrir est le moment où l'on veut repartir. Sans sa flèche, il
/// faudrait ressortir par la barre d'onglets, donc quitter Training pour y
/// revenir.
class CoachShell extends StatelessWidget {
  const CoachShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const CoachHeader(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
