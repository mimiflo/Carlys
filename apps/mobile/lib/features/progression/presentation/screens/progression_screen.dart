import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../controllers/progression_controllers.dart';
import '../widgets/progression_axis_card.dart';
import '../widgets/progression_title_card.dart';

/// PROFIL DE PROGRESSION : le titre, les cinq axes, et le renvoi au
/// manifeste qui les explique.
///
/// L'écran ne calcule rien : tout vient du moteur, qui est une fonction pure
/// de faits locaux. Il se contente d'être lisible, et de ne jamais faire
/// honte — c'est la seule chose qu'on lui demande en plus d'afficher.
class ProgressionScreen extends ConsumerWidget {
  const ProgressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(progressionProfileProvider);
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
            const Align(
              alignment: Alignment.centerLeft,
              child: AppBackButton(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ta progression',
              style: AppTypography.display
                  .copyWith(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Cinq axes, tenus par ce que tu fais vraiment.',
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.gapSection),
            if (ref.watch(progressionUnreadableProvider))
              AppErrorState(
                icon: AppIcons.retry,
                title: 'Ton historique n’a pas pu être lu',
                message: 'Ta progression se recalcule depuis tes séances : '
                    'elle réapparaîtra entière dès que la lecture repart. '
                    'Rien n’est perdu.',
                onRetry: () => ref.invalidate(workoutHistoryProvider),
              )
            else if (profile == null)
              const AppLoadingIndicator(label: 'Lecture de ton historique')
            else ...[
              ProgressionTitleCard(profile: profile),
              const SizedBox(height: AppSpacing.gapSection),
              const AppSectionLabel('Les cinq axes'),
              const SizedBox(height: AppSpacing.xs),
              for (final axis in profile.axes) ...[
                ProgressionAxisCard(axis: axis),
                const SizedBox(height: AppSpacing.gapRow),
              ],
              const SizedBox(height: AppSpacing.xs),
              _ManifestoEntry(
                onOpen: () => context.push(AppRoutes.manifesto),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le renvoi au manifeste : les points disent OÙ tu en es, le manifeste dit
/// POURQUOI ces cinq axes-là.
class _ManifestoEntry extends StatelessWidget {
  const _ManifestoEntry({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSectionLabel('Pourquoi ces cinq axes'),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Relire le manifeste Carlys.',
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.darkTextTertiary,
          ),
        ],
      ),
    );
  }
}
