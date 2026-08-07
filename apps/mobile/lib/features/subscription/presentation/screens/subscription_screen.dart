import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../domain/entities/subscription.dart';
import '../controllers/subscription_controllers.dart';

/// Abonnement (maquette 2h) : hero sur cœur ambiant, avantages réels
/// (droits décidés côté serveur), carte de plan — l'offre d'achat arrivera
/// avec les produits stores, aucun prix inventé d'ici là.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planStatusProvider);
    final entitlements = ref.watch(entitlementsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Abonnement'),
      ),
      body: Stack(
        children: [
          // Cœur ambiant haut-droite, débordant du cadre (2h).
          const Positioned(
            top: 14,
            right: -118,
            child: AppSceneContainer(
              size: 300,
              opacity: 0.55,
              verticalFadeStops: [0.0, 0.22, 0.58, 0.90],
              child: AppSceneHalo(),
            ),
          ),
          const Positioned.fill(child: AppSceneScrim.lateral()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                const AppSectionLabel('Carlys Premium'),
                const SizedBox(height: 10),
                Text(
                  'Ton coach\nne dort jamais.',
                  style: AppTypography.display
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: 10),
                Text(
                  'Programmation adaptative, macros recalculées chaque jour, '
                  'historique illimité.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
                const SizedBox(height: AppSpacing.gapSection),
                entitlements.when(
                  loading: () =>
                      const AppLoadingIndicator(label: 'Chargement des droits'),
                  error: (_, __) => AppErrorState(
                    title: 'Droits indisponibles',
                    onRetry: () => ref.invalidate(entitlementsProvider),
                  ),
                  data: (entries) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final entry in entries)
                        _EntitlementRow(entry: entry),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.gapSection),
                plan.when(
                  loading: () =>
                      const AppLoadingIndicator(label: 'Chargement du plan'),
                  error: (_, __) => AppErrorState(
                    title: 'Plan indisponible',
                    onRetry: () => ref.invalidate(planStatusProvider),
                  ),
                  data: (status) => _PlanCard(status: status),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'La souscription se fera via l’App Store, Google Play ou le '
                  'site web. Vos droits sont toujours validés par le serveur — '
                  'la restauration d’achat les réactive automatiquement.',
                  style: AppTypography.label.copyWith(
                    fontSize: 11,
                    height: 1.5,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.status});

  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final subscription = status.subscription;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.planName,
                style: AppTypography.metricL
                    .copyWith(color: AppColors.darkTextPrimary),
              ),
            ),
            AppPill(
              label: status.isPremium ? 'ACTIF' : 'GRATUIT',
              tone: status.isPremium ? AppPillTone.accent : AppPillTone.neutral,
              mono: true,
            ),
          ],
        ),
        if (subscription != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            _subscriptionSummary(subscription),
            style:
                AppTypography.body.copyWith(color: AppColors.darkTextSecondary),
          ),
        ],
      ],
    );

    // L'offre active porte la bordure animée de la maquette.
    if (status.isPremium) {
      return AppAnimatedBorderCard(child: content);
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: content,
    );
  }
}

class _EntitlementRow extends StatelessWidget {
  const _EntitlementRow({required this.entry});

  final EntitlementEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            entry.isActive
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            size: 20,
            color:
                entry.isActive ? AppColors.accent : AppColors.darkTextTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.label,
              style: AppTypography.body.copyWith(
                color: entry.isActive
                    ? AppColors.darkTextPrimary
                    : AppColors.darkTextTertiary,
              ),
            ),
          ),
          if (entry.isActive && entry.expiresAt != null)
            Text(
              'jusqu’au ${_formatDate(entry.expiresAt!)}',
              style: AppTypography.labelMono
                  .copyWith(color: AppColors.darkTextTertiary),
            ),
        ],
      ),
    );
  }
}

String _subscriptionSummary(SubscriptionInfo subscription) {
  final buffer = StringBuffer(subscription.state.label);
  final end = subscription.currentPeriodEnd;
  if (end != null) {
    buffer.write(
      subscription.cancelAtPeriodEnd ||
              subscription.state == SubscriptionState.canceled
          ? ' — accès jusqu’au ${_formatDate(end)}'
          : ' — renouvellement le ${_formatDate(end)}',
    );
  }
  return buffer.toString();
}

String _formatDate(DateTime utc) {
  final local = utc.toLocal();
  String pad(int value) => value.toString().padLeft(2, '0');
  return '${pad(local.day)}/${pad(local.month)}/${local.year}';
}
