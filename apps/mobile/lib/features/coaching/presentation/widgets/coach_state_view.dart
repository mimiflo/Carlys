import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';

/// Un état du coach qui n'est pas une conversation (maquette d'octobre
/// 2026) : l'emblème et son badge, le titre, une phrase, puis l'action et
/// « Retour au Training ». Premium, pause, erreur et chargement partagent ce
/// gabarit, pour que le coach garde son visage quand il ne peut pas parler.
class CoachStateView extends StatelessWidget {
  const CoachStateView({
    required this.title,
    required this.message,
    this.badge,
    this.pill,
    this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.isLoading = false,
    super.key,
  });

  final String title;
  final String message;

  /// Le petit disque posé sur l'emblème : cadenas, pause, hors ligne.
  final IconData? badge;

  /// Sous l'emblème, avant le titre (la pastille « PREMIUM »).
  final Widget? pill;

  /// Entre la phrase et l'action (la carte des avantages).
  final Widget? body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Chargement : un indicateur à la place de l'action, et pas de retour —
  /// l'en-tête porte déjà sa flèche.
  final bool isLoading;

  static const double _emblemSize = 96;
  static const double _badgeSize = 34;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.gutter,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _Emblem(badge: badge)),
            if (pill case final pill?) ...[
              const SizedBox(height: AppSpacing.md),
              Center(child: pill),
            ],
            const SizedBox(height: AppSpacing.md),
            if (isLoading) ...[
              // Le titre, en région vive, dit déjà ce qui se charge.
              const ExcludeSemantics(child: AppLoadingIndicator()),
              const SizedBox(height: AppSpacing.md),
            ],
            Semantics(
              header: true,
              // Annoncé au passage du chargement à l'état : Premium, pause…
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.title.copyWith(
                  color: AppColors.darkTextPrimary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.primaryLight),
            ),
            if (body case final body?) ...[
              const SizedBox(height: AppSpacing.gapSection),
              body,
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.gapSection),
              AppButton(
                label: action,
                icon: actionIcon,
                onPressed: onAction,
                size: AppButtonSize.large,
                isExpanded: true,
              ),
            ],
            if (!isLoading) ...[
              const SizedBox(height: AppSpacing.md),
              Center(
                child: AppLinkButton(
                  label: 'Retour au Training',
                  onPressed: () => GoRouter.of(context).go(AppRoutes.training),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.badge});

  final IconData? badge;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    return SizedBox.square(
      dimension: CoachStateView._emblemSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const AppIconBadge(
            icon: AppIcons.coachEmblem,
            size: CoachStateView._emblemSize,
          ),
          if (badge != null)
            Positioned(
              right: 0,
              bottom: 0,
              // L'anneau couleur du fond détache le badge de l'emblème.
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xxs),
                decoration: const BoxDecoration(
                  color: AppColors.darkBackground,
                  shape: BoxShape.circle,
                ),
                child: AppIconBadge(
                  icon: badge,
                  size: CoachStateView._badgeSize,
                  color: AppColors.neutral0,
                  background: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
