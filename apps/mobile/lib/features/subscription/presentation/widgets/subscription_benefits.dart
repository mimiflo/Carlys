import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/subscription.dart';

/// Liste des avantages de la maquette 2i, alimentée par les droits RÉELS
/// renvoyés par le serveur : coche accent quand le droit est ouvert,
/// cadenas et texte atténué quand il reste verrouillé.
class SubscriptionBenefits extends StatelessWidget {
  const SubscriptionBenefits({required this.entries, super.key});

  final List<EntitlementEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const AppEmptyState(
        title: 'Aucun droit à afficher',
        message: 'Le serveur n’a renvoyé aucun droit pour ce compte.',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < entries.length; index++) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            SubscriptionBenefitRow(entry: entries[index]),
          ],
        ],
      ),
    );
  }
}

/// Une ligne d'avantage : icône d'état puis libellé du droit.
class SubscriptionBenefitRow extends StatelessWidget {
  const SubscriptionBenefitRow({required this.entry, super.key});

  final EntitlementEntry entry;

  /// Taille d'icône de la maquette (géométrie pure).
  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final active = entry.isActive;

    return Semantics(
      label: '${entry.label}, ${active ? 'inclus' : 'verrouillé'}',
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(
            active ? AppIcons.checkCircle : AppIcons.lock,
            size: _iconSize,
            color: active ? AppColors.accent : AppColors.darkTextTertiary,
          ),
          const SizedBox(width: AppSpacing.gapRow),
          Expanded(
            child: Text(
              entry.label,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                height: 1.4,
                color: active
                    ? AppColors.neutralBadgeText
                    : AppColors.darkTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
