import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../subscription/presentation/controllers/subscription_controllers.dart';

/// Profil & réglages (maquette 2j) : identité, tuiles de stats réelles,
/// groupes de réglages, déconnexion.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = switch (authState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final overview = ref.watch(progressOverviewProvider).valueOrNull;
    final weights = ref.watch(bodyWeightMetricsProvider).valueOrNull;
    final plan = ref.watch(planStatusProvider).valueOrNull;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.gutter,
            AppSpacing.gutter,
            bottomInset + AppSpacing.gutter,
          ),
          children: [
            // ── Identité ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    borderRadius:
                        BorderRadius.all(Radius.circular(AppRadius.statTile)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, Color(0xFF2B2B7A)],
                    ),
                  ),
                  child: Center(
                    child: Text(
                      user == null || user.displayName.isEmpty
                          ? '?'
                          : user.displayName.characters.first.toUpperCase(),
                      style: AppTypography.title
                          .copyWith(color: AppColors.neutral0),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Profil',
                        style: AppTypography.title
                            .copyWith(color: AppColors.darkTextPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        (user?.email ?? '').toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMono
                            .copyWith(color: AppColors.darkTextTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gutter),

            // ── Tuiles de stats (données réelles) ────────────────────
            Row(
              children: [
                Expanded(
                  child: AppStatTile(
                    label: 'Poids',
                    value: weights == null || weights.isEmpty
                        ? '—'
                        : _kg(weights.last.value),
                    unit: weights == null || weights.isEmpty ? null : ' kg',
                  ),
                ),
                const SizedBox(width: AppSpacing.gapTile),
                Expanded(
                  child: AppStatTile(
                    label: 'Séances',
                    value: overview == null ? '—' : '${overview.sessionsCount}',
                  ),
                ),
                const SizedBox(width: AppSpacing.gapTile),
                Expanded(
                  child: AppStatTile(
                    label: 'Volume',
                    value: overview == null
                        ? '—'
                        : _tonnes(overview.totalVolumeKg),
                    unit: overview == null ? null : ' t',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gapSection),

            // ── Groupes de réglages ──────────────────────────────────
            const AppSectionLabel('Compte'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsGroup(
              rows: [
                _SettingsRowData(
                  icon: AppIcons.premium,
                  label: 'Abonnement',
                  trailing: plan?.isPremium == true
                      ? const AppPill(
                          label: 'PRO',
                          tone: AppPillTone.accent,
                          mono: true,
                        )
                      : null,
                  onTap: () => context.push(AppRoutes.subscription),
                ),
                _SettingsRowData(
                  icon: Icons.devices,
                  label: 'Appareils connectés',
                  onTap: () => context.push(AppRoutes.sessions),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const AppSectionLabel('Entraînement'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsGroup(
              rows: [
                _SettingsRowData(
                  icon: AppIcons.history,
                  label: 'Historique des séances',
                  onTap: () => context.push(AppRoutes.history),
                ),
                _SettingsRowData(
                  icon: AppIcons.bodyMetrics,
                  label: 'Mesures corporelles',
                  onTap: () => context.go(AppRoutes.progress),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const AppSectionLabel('Application'),
            const SizedBox(height: AppSpacing.sm),
            _SettingsGroup(
              rows: [
                _SettingsRowData(
                  icon: Icons.dark_mode_outlined,
                  label: 'Apparence',
                  onTap: () => context.push(AppRoutes.settings),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.gapSection),
            Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: Text(
                  'Se déconnecter',
                  style: AppTypography.body.copyWith(color: AppColors.logout),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _kg(double value) {
    final rounded = (value * 10).roundToDouble() / 10;
    return rounded == rounded.truncateToDouble()
        ? '${rounded.truncate()}'
        : '$rounded'.replaceAll('.', ',');
  }

  static String _tonnes(double kg) {
    final tonnes = (kg / 100).roundToDouble() / 10;
    return '$tonnes'.replaceAll('.', ',');
  }
}

class _SettingsRowData {
  const _SettingsRowData({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
}

/// Carte-groupe : lignes internes séparées par un trait 1px `border`.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: AppRadius.listRowAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.darkBorder,
              ),
            InkWell(
              onTap: row.onTap,
              borderRadius: index == 0
                  ? const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.listRow),
                    )
                  : index == rows.length - 1
                      ? const BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.listRow),
                        )
                      : BorderRadius.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Icon(row.icon, size: 20, color: AppColors.darkTextTertiary),
                    const SizedBox(width: AppSpacing.gapRow),
                    Expanded(
                      child: Text(
                        row.label,
                        style: AppTypography.subheading.copyWith(
                          fontSize: 14,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ),
                    if (row.trailing != null)
                      row.trailing!
                    else if (row.onTap != null)
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.darkTextTertiary,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
