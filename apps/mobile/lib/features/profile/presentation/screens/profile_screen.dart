import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../community/presentation/controllers/community_controllers.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../workout_program/presentation/controllers/program_controllers.dart';
import '../../../workout_program/presentation/widgets/training_goal_sheet.dart';
import '../providers/profile_hub_providers.dart';
import '../widgets/profile_email_verification.dart';
import '../widgets/profile_further_banner.dart';
import '../widgets/profile_hub_tile.dart';
import '../widgets/profile_hub_wording.dart';
import '../widgets/profile_identity_card.dart';
import '../widgets/profile_objective_card.dart';
import '../widgets/profile_page_header.dart';
import '../widgets/profile_program_card.dart';

/// MON PROFIL : ton parcours, ta progression — refonte de septembre 2026,
/// d'après la maquette validée.
///
/// L'écran RACONTE et ne règle rien : chaque carte est une porte vers
/// l'écran qui possède sa donnée, et tous les réglages vivent derrière le
/// rouage (`ProfileSettingsScreen`). L'ancien profil empilait douze groupes
/// de réglages sous l'identité ; c'était précisément le « trop chargé ».
///
/// Écarts à la maquette, tous délibérés :
///  - « Mes contenus sauvegardés » est absent : aucune sauvegarde de
///    contenu n'existe dans le domaine, et une ligne morte mentirait ;
///  - « Bronze » est retiré de « Mes badges » : une ligue ne se reporte
///    jamais dans le profil (`docs/product/progression.md`, test de la date
///    de fin) ;
///  - la jauge de l'objectif nomme sa base (« du programme ») sous son
///    pourcentage ;
///  - la bottom bar n'y est pas : le profil s'ouvre en plein écran depuis
///    l'avatar de l'accueil, d'où la flèche de retour au-dessus du titre.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = switch (ref.watch(authControllerProvider)) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final badges = ref.watch(profileBadgeCountProvider);
    final friends = ref.watch(profileFriendsCountProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.darkSurface,
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              bottomInset + AppSpacing.gapSection,
            ),
            children: [
              ProfilePageHeader(
                title: 'Mon profil',
                tagline: 'Ton parcours, ta progression.',
                action: ProfileSettingsButton(
                  onPressed: () => context.push(AppRoutes.profileSettings),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ProfileIdentityCard(
                user: user,
                onOpen: () => context.push(AppRoutes.carlysProfiles),
              ),
              // Là où l'adresse se lit : le rappel n'existe que tant qu'elle
              // n'a jamais été vérifiée, et disparaît sans laisser d'espace.
              if (user != null && !user.emailVerified) ...[
                const SizedBox(height: AppSpacing.gapTile),
                ProfileEmailVerification(user: user),
              ],
              const SizedBox(height: AppSpacing.sm),
              ProfileObjectiveCard(onTap: () => showTrainingGoalSheet(context)),
              const SizedBox(height: AppSpacing.gapTile),
              ProfileProgramCard(
                onOpenProgram: (id) =>
                    context.push(AppRoutes.programDetail(id)),
                onBrowse: () => context.push(AppRoutes.programs),
              ),
              const SizedBox(height: AppSpacing.gapTile),
              ProfileHubCard(
                children: [
                  ProfileHubTile(
                    icon: AppIcons.statistics,
                    title: 'Mes statistiques',
                    subtitle: 'Voir mon évolution',
                    onTap: () => context.go(AppRoutes.progress),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.gapTile),
              ProfileHubCard(
                children: [
                  ProfileHubTile(
                    icon: AppIcons.rewards,
                    tone: ProfileTileTone.ember,
                    title: 'Mes badges',
                    subtitle: countLine(
                      badges,
                      none: 'Ton premier badge t’attend',
                      singular: 'badge',
                      plural: 'badges',
                    ),
                    onTap: () => context.push(AppRoutes.progression),
                  ),
                  ProfileHubTile(
                    icon: AppIcons.community,
                    tone: ProfileTileTone.lavender,
                    title: 'Mes amis',
                    subtitle: countLine(
                      friends,
                      none: 'Invite quelqu’un à te suivre',
                      singular: 'ami',
                      plural: 'amis',
                    ),
                    onTap: () => context.go(AppRoutes.community),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ProfileFurtherBanner(
                onTap: () => context.push(AppRoutes.programSetup),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Relit ce qui vient du serveur. Les compteurs de vie entière ne sont
  /// PAS auto-disposés (les récompenses en dépendent) : sans ce geste, un
  /// échec hors ligne resterait affiché jusqu'au redémarrage.
  ///
  /// L'attente porte sur la relecture, pas sur son succès : un échec est
  /// déjà dit par la ligne concernée, le relancer ici le dirait deux fois.
  Future<void> _refresh(WidgetRef ref) {
    ref
      ..invalidate(lifetimeStatsProvider)
      ..invalidate(communityFriendsProvider)
      ..invalidate(programsProvider);
    return ref
        .read(lifetimeStatsProvider.future)
        .then<void>((_) {}, onError: (Object _) {});
  }
}
