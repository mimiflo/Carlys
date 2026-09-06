import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/subscription.dart';

/// Carte du plan réel, dessinée comme la carte d'offre de la maquette 2i :
/// rayon 24, libellé + mention secondaire à gauche, pastille d'état à droite
/// (là où la maquette pose son prix). Bordure animée quand le plan est actif,
/// carte neutre sinon.
///
/// Aucun tarif ici : les prix vivent dans les cartes d'offre, servis par
/// `GET /subscriptions/offers`.
class SubscriptionPlanCard extends StatelessWidget {
  const SubscriptionPlanCard({required this.status, super.key});

  final PlanStatus status;

  /// Rembourrage des cartes d'offre de la maquette.
  static const EdgeInsets _padding = EdgeInsets.all(
    AppSpacing.md + AppSpacing.xxs,
  );

  @override
  Widget build(BuildContext context) {
    final detail = _planDetail(status);

    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                status.planName,
                style: AppTypography.subheading.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                detail,
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.gapRow),
        AppPill(
          label: status.isPremium ? 'ACTIF' : 'GRATUIT',
          tone: status.isPremium ? AppPillTone.accent : AppPillTone.neutral,
          mono: true,
        ),
      ],
    );

    final card = status.isPremium
        ? AppAnimatedBorderCard(padding: _padding, child: content)
        : Container(
            padding: _padding,
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.cardSecondaryAll,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.darkBorder),
              ),
            ),
            child: content,
          );

    return Semantics(
      label:
          'Plan ${status.planName}, '
          '${status.isPremium ? 'actif' : 'gratuit'}. $detail',
      excludeSemantics: true,
      child: card,
    );
  }
}

/// Mention secondaire : état de l'abonnement et échéance, telle que le
/// serveur la projette. Jamais de valeur de repli inventée.
String _planDetail(PlanStatus status) {
  final subscription = status.subscription;
  if (subscription == null) {
    return 'Aucun abonnement actif';
  }

  final end = subscription.currentPeriodEnd;
  if (end == null) {
    return subscription.state.label;
  }

  final date = formatShortDateMono(end.toLocal());
  final endsAccess =
      subscription.cancelAtPeriodEnd ||
      subscription.state == SubscriptionState.canceled;

  // L'état « actif » est déjà porté par la pastille : ne pas le répéter,
  // la ligne tiendrait sinon sur deux lignes.
  if (subscription.state == SubscriptionState.active) {
    return endsAccess ? 'Accès jusqu’au $date' : 'Renouvellement le $date';
  }
  return '${subscription.state.label} jusqu’au $date';
}
