import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/mentor_tour.dart';
import '../controllers/mentor_controllers.dart';
import 'mentor_tour_chemin.dart';

/// Où chaque étape emmène. La table vit ICI, pas dans le manifeste : le
/// domaine ne connaît pas le routeur, et un test vérifie que chaque étape a
/// sa destination.
const Map<String, String> mentorTourRoutes = {
  'accueil': AppRoutes.home,
  'entrainement': AppRoutes.training,
  'nutrition': AppRoutes.nutrition,
  'progres': AppRoutes.progress,
  'academy': AppRoutes.academy,
  'communaute': AppRoutes.community,
  'coach': AppRoutes.coach,
};

/// Feuille de la visite guidée : UNE étape à la fois, l'ordre du manifeste,
/// le chemin des sept pièces sous les yeux, et deux gestes — y aller
/// (l'ancrage réel), ou passer à la suivante. Rien n'est verrouillé :
/// fermer la feuille n'engage à rien, et « déjà vu » se rejoue depuis les
/// réglages du Mentor.
Future<void> showMentorTourSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorTourSheet());
}

class _MentorTourSheet extends ConsumerWidget {
  const _MentorTourSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(mentorTourProgressProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: progress == null
          ? const AppLoadingIndicator()
          : (progress.terminee
                ? _VisiteTerminee(
                    onRejouer: () =>
                        ref.read(mentorActionsProvider).rejouerVisite(),
                  )
                : _Etape(progress: progress)),
    );
  }
}

/// Une étape : sa position, le chemin, son titre, son propos, ses gestes.
class _Etape extends ConsumerWidget {
  const _Etape({required this.progress});

  final MentorTourProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final etape = progress.prochaine!;
    final vues = ref.watch(mentorTourVuesProvider).valueOrNull ?? const {};

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Visite guidée · ${progress.vues + 1} sur ${progress.total}',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        AppGauge(
          progress: (progress.vues + 1) / progress.total,
          color: AppColors.primaryLight,
          height: 3,
        ),
        const SizedBox(height: AppSpacing.md),
        MentorTourChemin(vues: vues, etapeCourante: etape.id),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.cta,
              ),
              child: Icon(
                mentorTourIcons[etape.id] ?? AppIcons.mentor,
                size: 20,
                color: AppColors.neutral0,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(etape.titre, style: theme.textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          etape.corps,
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: etape.libelleAller,
          onPressed: () => _aller(context, ref, etape),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Étape suivante',
          variant: AppButtonVariant.secondary,
          onPressed: () =>
              ref.read(mentorActionsProvider).marquerEtapeVue(etape.id),
        ),
      ],
    );
  }

  /// « Aller voir » est l'ancrage réel : l'étape se marque vue, la feuille
  /// se ferme, et la navigation emmène sur la pièce présentée.
  Future<void> _aller(
    BuildContext context,
    WidgetRef ref,
    MentorTourStep etape,
  ) async {
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    await ref.read(mentorActionsProvider).marquerEtapeVue(etape.id);
    if (navigator.mounted) {
      navigator.pop();
    }
    final route = mentorTourRoutes[etape.id];
    if (route != null && route != AppRoutes.home) {
      router.go(route);
    }
  }
}

/// La fin de la visite : le bandeau violet qui la salue, le chemin
/// complet, et une porte pour la revoir.
class _VisiteTerminee extends StatelessWidget {
  const _VisiteTerminee({required this.onRejouer});

  final VoidCallback onRejouer;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            gradient: AppColors.cta,
            borderRadius: AppRadius.cardSecondaryAll,
          ),
          child: Row(
            children: [
              const Icon(
                AppIcons.checkCircle,
                size: 28,
                color: AppColors.neutral0,
              ),
              const SizedBox(width: AppSpacing.gapRow),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Les sept pièces vues',
                      style: AppTypography.label.copyWith(
                        color: AppColors.neutral0.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Visite terminée',
                      style: AppTypography.title.copyWith(
                        color: AppColors.neutral0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        MentorTourChemin(vues: {for (final step in mentorTour) step.id}),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Tu as fait le tour des grandes pièces. Tout reste là où tu l’as '
          'vu, et tu peux revoir la visite quand tu veux.',
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Revoir la visite',
          variant: AppButtonVariant.secondary,
          onPressed: onRejouer,
        ),
      ],
    );
  }
}
