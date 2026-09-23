import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../carlys_profile/presentation/widgets/carlys_profile_content.dart';
import '../../../mentor/presentation/widgets/mentor_settings_section.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../progression/presentation/controllers/progression_controllers.dart';
import '../../../workout_program/presentation/controllers/training_goal_controllers.dart';
import '../../../workout_program/presentation/widgets/training_goal_sheet.dart';
import '../widgets/profile_legal_section.dart';
import '../widgets/profile_nutrition_settings.dart';
import '../widgets/profile_page_header.dart';
import '../widgets/profile_plan_section.dart';
import '../widgets/profile_settings_sections.dart';
import '../widgets/profile_training_settings.dart';

/// LES RÉGLAGES, derrière le rouage du profil.
///
/// Ils vivaient à même le profil, sous l'identité : douze groupes empilés,
/// où ce qu'on est venu VOIR (son parcours) se noyait dans ce qu'on vient
/// CHANGER une fois par trimestre. La refonte de septembre 2026 les sépare :
/// le profil raconte, cet écran règle.
///
/// Rien n'a été retiré en chemin — chaque groupe est celui d'avant, dans le
/// même ordre, abonnement en tête et déconnexion en pied.
class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    // Le plan nutrition ne s'affiche que sur une ligne de réglage, où
    // l'absence de valeur n'affirme rien : le `valueOrNull` y est juste.
    final profile = ref.watch(metabolismReportProvider).valueOrNull?.profile;
    final progression = ref.watch(progressionProfileProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.md,
            AppSpacing.gutter,
            bottomInset + AppSpacing.gapSection,
          ),
          children: [
            const ProfilePageHeader(
              title: 'Réglages',
              tagline: 'Ton compte, tes préférences.',
            ),
            const SizedBox(height: AppSpacing.lg),
            ProfilePlanSection(
              onOpenPlan: () => context.push(AppRoutes.subscription),
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileIdentitySettings(
              currentLabel: user?.carlysProfile == null
                  ? null
                  : carlysProfileContentOf(user!.carlysProfile!).title,
              titleLabel: progression?.title.label,
              onOpen: () => context.push(AppRoutes.carlysProfiles),
              onProgression: () => context.push(AppRoutes.progression),
              onManifesto: () => context.push(AppRoutes.manifesto),
            ),
            const SizedBox(height: AppSpacing.md),
            const MentorSettingsSection(),
            const SizedBox(height: AppSpacing.md),
            ProfileTrainingSettings(
              goalLabel: ref.watch(currentTrainingGoalProvider)?.label,
              onGoal: () => showTrainingGoalSheet(context),
              onSetup: () => context.push(AppRoutes.programSetup),
              onTemplates: () => context.push(AppRoutes.templates),
              onHistory: () => context.push(AppRoutes.history),
              onBodyMetrics: () => context.go(AppRoutes.progress),
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileNutritionSettings(
              goalLabel: profile?.goal?.label,
              // Le plan se règle dans le profil métabolique (onglet
              // Nutrition), seul écrivain de cette donnée.
              onGoal: () => context.go(AppRoutes.nutrition),
            ),
            const SizedBox(height: AppSpacing.md),
            ProfileAppSettings(
              onAppearance: () => context.push(AppRoutes.settings),
              onDevices: () => context.push(AppRoutes.sessions),
            ),
            const SizedBox(height: AppSpacing.md),
            const NotificationSettingsSection(),
            const SizedBox(height: AppSpacing.md),
            ProfileAccountSettings(
              onChangePassword: () => context.push(AppRoutes.changePassword),
              onDeleteAccount: () => context.push(AppRoutes.deleteAccount),
            ),
            const SizedBox(height: AppSpacing.md),
            const ProfileLegalSettings(),
            const SizedBox(height: AppSpacing.gapSection),
            Center(
              child: TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: Text(
                  'Se déconnecter',
                  style: AppTypography.body.copyWith(color: AppColors.danger),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
