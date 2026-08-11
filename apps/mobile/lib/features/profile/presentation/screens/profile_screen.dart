import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../subscription/presentation/controllers/subscription_controllers.dart';
import '../controllers/profile_controllers.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_plan_card.dart';
import '../widgets/profile_settings_sections.dart';
import '../widgets/profile_stat_tiles.dart';

/// Profil & réglages (maquette 2j) : identité, bannière d'abonnement, tuiles
/// mono, groupes de réglages puis déconnexion.
///
/// Blocs de la maquette absents faute de donnée : le crayon d'édition (aucune
/// édition de profil), « MEMBRE DEPUIS » (pas de date de création servie),
/// « temps de repos par défaut », « unités », « rappels de séance » et
/// « exporter mes données » (aucun réglage correspondant).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final user = switch (authState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final plan = ref.watch(planStatusProvider).valueOrNull;
    final weights = ref.watch(bodyWeightMetricsProvider).valueOrNull;
    final profile = ref.watch(metabolismReportProvider).valueOrNull?.profile;
    final overview = ref.watch(profileSessionsOverviewProvider).valueOrNull;
    // Plein écran depuis la réorganisation en cinq onglets : la bottom bar ne
    // recouvre plus cet écran, seul l'encart système compte.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.gutter,
            AppSpacing.gutter,
            bottomInset + AppSpacing.gapSection,
          ),
          children: [
            ProfileHeader(user: user),
            const SizedBox(height: AppSpacing.md),
            if (plan != null) ...[
              ProfilePlanCard(
                plan: plan,
                onTap: () => context.push(AppRoutes.subscription),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            ProfileStatTiles(
              weightKg: weights == null || weights.isEmpty
                  ? null
                  : weights.last.value,
              heightCm: profile?.heightCm,
              sessionsCount: overview?.sessionsCount,
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileTrainingSettings(
              goalLabel: profile?.goal?.label,
              // L'objectif se règle dans le profil métabolique (onglet
              // Nutrition), seul écrivain de cette donnée.
              onGoal: () => context.go(AppRoutes.nutrition),
              onTemplates: () => context.push(AppRoutes.templates),
              onHistory: () => context.push(AppRoutes.history),
              onBodyMetrics: () => context.go(AppRoutes.progress),
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileAppSettings(
              onAppearance: () => context.push(AppRoutes.settings),
              onDevices: () => context.push(AppRoutes.sessions),
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
}
