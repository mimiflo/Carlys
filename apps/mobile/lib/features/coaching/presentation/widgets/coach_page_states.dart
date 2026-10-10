import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import 'coach_header.dart';
import 'coach_notices.dart';
import 'coach_state_view.dart';

/// Le coach fait partie de l'abonnement : sans le droit, on explique et on
/// mène à l'écran d'abonnement — on ne laisse pas une porte fermée sans clé.
class CoachPremiumState extends StatelessWidget {
  const CoachPremiumState({super.key});

  static const _benefits = [
    (
      AppIcons.trendingUp,
      'Comprends ta progression',
      'Tes séances, records et mesures réunis.',
    ),
    (
      AppIcons.equipmentDumbbell,
      'Adapte ton entraînement',
      'Selon ton temps et ton matériel.',
    ),
    (AppIcons.play, 'Passe à l’action', 'Une séance proposée, prête à lancer.'),
  ];

  @override
  Widget build(BuildContext context) {
    return CoachStateView(
      badge: AppIcons.lock,
      pill: const AppPill(
        label: 'PREMIUM',
        icon: AppIcons.premium,
        tone: AppPillTone.primary,
      ),
      title: 'Le coach est réservé à Premium',
      message: 'Un accompagnement adapté à ton entraînement, à ton rythme.',
      body: AppCard(
        child: Column(
          children: [
            for (final (index, (icon, title, detail)) in _benefits.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.gapRow),
              MergeSemantics(
                child: CoachNoticeHeading(
                  icon: icon,
                  title: title,
                  message: detail,
                ),
              ),
            ],
          ],
        ),
      ),
      actionLabel: 'Voir Premium',
      actionIcon: AppIcons.premium,
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
