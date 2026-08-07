import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/subscription.dart';
import '../controllers/subscription_controllers.dart';

/// Abonnement : plan effectif, état de l'abonnement, droits actifs.
/// Aucun faux paiement : l'achat passera par les stores (RevenueCat) ou
/// Stripe web — cet écran AFFICHE l'état décidé par le serveur.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(planStatusProvider);
    final entitlements = ref.watch(entitlementsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Abonnement')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            plan.when(
              loading: () => const AppLoadingIndicator(label: 'Chargement'),
              error: (_, __) => AppErrorState(
                title: 'Abonnement indisponible',
                onRetry: () => ref.invalidate(planStatusProvider),
              ),
              data: (status) => _PlanCard(status: status),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Vos droits', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            entitlements.when(
              loading: () => const AppLoadingIndicator(label: 'Chargement'),
              error: (_, __) => AppErrorState(
                title: 'Droits indisponibles',
                onRetry: () => ref.invalidate(entitlementsProvider),
              ),
              data: (entries) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in entries) _EntitlementTile(entry: entry),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'La souscription se fera via l’App Store, Google Play ou le '
              'site web. Vos droits sont toujours validés par le serveur — '
              'la restauration d’achat les réactive automatiquement.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.status});

  final PlanStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscription = status.subscription;

    return AppCard(
      semanticLabel: 'Plan actuel : ${status.planName}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.premium,
                color: status.isPremium
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  status.planName,
                  style: theme.textTheme.headlineMedium,
                ),
              ),
              AppBadge(
                label: status.isPremium ? 'Premium' : 'Gratuit',
                variant: status.isPremium
                    ? AppBadgeVariant.accent
                    : AppBadgeVariant.neutral,
              ),
            ],
          ),
          if (subscription != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _subscriptionSummary(subscription),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _EntitlementTile extends StatelessWidget {
  const _EntitlementTile({required this.entry});

  final EntitlementEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(
            entry.isActive
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            size: 20,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              entry.label,
              style: theme.textTheme.bodyLarge?.copyWith(
                color:
                    entry.isActive ? null : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (entry.isActive && entry.expiresAt != null)
            Text(
              'jusqu’au ${_formatDate(entry.expiresAt!)}',
              style: theme.textTheme.bodySmall,
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
