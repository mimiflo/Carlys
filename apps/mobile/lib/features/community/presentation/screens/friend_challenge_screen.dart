import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../controllers/community_controllers.dart';
import '../controllers/community_moderation_controllers.dart';
import '../providers/community_tab_state.dart';
import '../providers/friend_challenge_detail_providers.dart';
import '../widgets/friend_challenge/friend_challenge_content.dart';
import '../widgets/friend_challenge/friend_challenge_gestures.dart';
import '../widgets/friend_challenge/friend_challenge_menu.dart';

/// UN DÉFI ENTRE AMIS, en plein écran — d'après la maquette du
/// 23 septembre 2026.
///
/// Il se relit par son identifiant (`GET /community/friend-challenges/:id`),
/// réservé à ses membres : à tout autre, le serveur répond « introuvable »
/// sans dire s'il existe. Un défi refusé ou quitté n'est donc plus
/// lisible, et l'écran le dit au lieu d'afficher une panne.
class FriendChallengeScreen extends ConsumerWidget {
  const FriendChallengeScreen({required this.challengeId, super.key});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = friendChallengeDetailProvider(challengeId);
    final detail = ref.watch(provider);
    final challenge = detail.valueOrNull;
    final gestures = FriendChallengeGestures(
      ref.read(communityActionsProvider),
      ref.read(communityModerationActionsProvider),
    );
    void closeScreen() => _close(context);
    final menu = challenge == null
        ? const <FriendChallengeMenuEntry>[]
        : friendChallengeMenuEntries(challenge, gestures, onLeft: closeScreen);

    final Widget body;
    if (challenge != null) {
      body = FriendChallengeContent(
        challenge: challenge,
        gestures: gestures,
        onLeft: closeScreen,
      );
    } else if (detail.hasError) {
      body = _Unavailable(
        error: detail.error!,
        onRetry: () => ref.invalidate(provider),
        onBack: closeScreen,
      );
    } else {
      body = const AppLoadingIndicator();
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: RefreshIndicator(
        // Un ami a pu marquer depuis l'ouverture : rien sur l'appareil ne
        // déclenche la relecture, le geste la demande.
        onRefresh: () => _reload(ref),
        color: AppColors.primaryLight,
        backgroundColor: AppColors.darkSurface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            MediaQuery.paddingOf(context).top + AppSpacing.md,
            AppSpacing.md,
            MediaQuery.paddingOf(context).bottom + AppSpacing.gapSection,
          ),
          children: [
            AppScreenHeader(
              title: 'Défi entre amis',
              tagline: 'Se motiver ensemble',
              actions: [
                if (menu.isNotEmpty)
                  AppRoundIconButton(
                    icon: AppIcons.screenMenu,
                    tooltip: 'Plus d’options',
                    onPressed: () => showFriendChallengeMenu(context, menu),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            body,
          ],
        ),
      ),
    );
  }

  /// Relit le défi sans jamais jeter : l'anneau attend le futur, personne
  /// n'en reçoit l'erreur — l'écran la montre déjà.
  Future<void> _reload(WidgetRef ref) async {
    try {
      final provider = friendChallengeDetailProvider(challengeId);
      ref.invalidate(provider);
      await ref.read(provider.future);
    } on Exception catch (error) {
      AppLogger('community').warning('Défi non rafraîchi', error: error);
    }
  }

  /// Retour à la liste ; ouvert sans historique (une notification), l'écran
  /// ramène à l'onglet Défis plutôt que de laisser l'appli sans issue.
  static void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.communityTab(CommunityTab.defis));
    }
  }
}

/// Le défi n'a pas pu être lu : soit il n'est plus le mien (refusé,
/// quitté), soit le réseau ou le serveur a manqué.
class _Unavailable extends StatelessWidget {
  const _Unavailable({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final gone =
        error is ServerException &&
        (error as ServerException).statusCode == 404;
    if (gone) {
      return AppEmptyState(
        icon: AppIcons.challengeOutline,
        title: 'Ce défi n’est plus là',
        message:
            'Il a été refusé ou quitté, ou tu n’en fais pas partie. Les défis '
            'en cours t’attendent dans l’onglet Défis.',
        actionLabel: 'Retour aux défis',
        onAction: onBack,
      );
    }
    return ConnectionAwareError(
      error: error,
      title: 'Défi indisponible',
      offlineMessage:
          'Le défi vit sur le serveur : son classement revient avec le '
          'réseau.',
      onRetry: onRetry,
    );
  }
}
