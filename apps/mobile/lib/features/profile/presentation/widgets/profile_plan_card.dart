import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../subscription/domain/entities/subscription.dart';

/// Bannière d'abonnement : carte dégradée lime, icône premium, état du plan
/// et échéance réelle. Le libellé vient toujours du serveur (`planName`,
/// `state`) — jamais d'état inventé côté client.
///
/// La sous-ligne ne porte que le mois et l'année : `formatting.dart` n'offre
/// pas de format « jour mois année ».
class ProfilePlanCard extends StatelessWidget {
  const ProfilePlanCard({required this.plan, required this.onTap, super.key});

  final PlanStatus plan;
  final VoidCallback onTap;

  static const double _fillStart = 0.16;
  static const double _fillEnd = 0.04;
  static const double _borderAlpha = 0.30;

  @override
  Widget build(BuildContext context) {
    final subtitle = _subtitle(plan);

    return Semantics(
      button: true,
      label: subtitle == null ? plan.planName : '${plan.planName}, $subtitle',
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardSecondaryAll,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withValues(alpha: _fillStart),
                AppColors.accent.withValues(alpha: _fillEnd),
              ],
            ),
            border: Border.fromBorderSide(
              BorderSide(
                color: AppColors.accent.withValues(alpha: _borderAlpha),
              ),
            ),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.premium, size: 24, color: AppColors.accent),
              const SizedBox(width: AppSpacing.gapRow),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subheading.copyWith(
                        fontSize: 14,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMono.copyWith(
                          fontSize: 11,
                          color: AppColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.gapTile),
              const Icon(
                AppIcons.chevronRight,
                size: 20,
                color: AppColors.darkTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sous-ligne mono : échéance réelle quand le serveur en fournit une,
  /// sinon l'état du plan ; invitation pour un compte sans abonnement.
  static String? _subtitle(PlanStatus plan) {
    final subscription = plan.subscription;
    if (subscription == null) {
      return 'DÉCOUVRIR PREMIUM';
    }
    final periodEnd = subscription.currentPeriodEnd;
    if (periodEnd == null) {
      return subscription.state.label.toUpperCase();
    }
    final date = formatMonthYearMono(periodEnd.toLocal());
    if (subscription.cancelAtPeriodEnd) {
      return 'ACCÈS JUSQU’À $date';
    }
    return switch (subscription.state) {
      SubscriptionState.active => 'RENOUVELLEMENT $date',
      SubscriptionState.trialing => 'ESSAI JUSQU’À $date',
      _ => '${subscription.state.label.toUpperCase()} · $date',
    };
  }
}
