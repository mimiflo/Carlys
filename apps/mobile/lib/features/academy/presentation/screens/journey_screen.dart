import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/academy_journey.dart';
import '../providers/academy_progress_providers.dart';

/// Le Parcours en un coup d'œil : six étapes, où on en est, où reprendre.
///
/// Rien n'est verrouillé : chaque étape s'ouvre, dans l'ordre ou non —
/// l'ordre est un CONSEIL de lecture, l'exploration libre reste la règle de
/// l'Academy. La reprise automatique se contente de dire laquelle est la
/// prochaine.
class JourneyScreen extends ConsumerWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(academyJourneyProgressProvider);
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(title: const Text('Parcours')),
      body: progress == null
          ? const AppLoadingIndicator()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                bottomInset + AppSpacing.gapSection,
              ),
              children: [
                Text(
                  progress.termine
                      ? 'Parcours terminé. Tout reste relisible.'
                      : 'Six étapes, du premier geste aux réglages fins. '
                            'Lis dans l’ordre ou non : le parcours suit, il '
                            'n’enferme pas.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapRow),
                for (var i = 0; i < academyJourney.length; i++) ...[
                  _EtapeCard(
                    stage: academyJourney[i],
                    progress: progress.parEtape[i],
                    courante: progress.etapeCourante == i,
                    onOpen: () => context.push(
                      AppRoutes.academyJourneyStage(academyJourney[i].rang),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}

/// Une étape : rang, nom, intention, avancement — et l'état qui la
/// distingue : validée (accent), courante (bord primaire), à venir (sobre).
class _EtapeCard extends StatelessWidget {
  const _EtapeCard({
    required this.stage,
    required this.progress,
    required this.courante,
    required this.onOpen,
  });

  final JourneyStage stage;
  final StageProgress progress;
  final bool courante;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final validee = progress.termine && progress.total > 0;

    return Semantics(
      button: true,
      label:
          'Étape ${stage.rang}, ${stage.nom}, ${progress.abordees} leçons '
          'sur ${progress.total}'
          '${validee ? ', validée' : (courante ? ', étape en cours' : '')}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onOpen,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.padCard),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(
                color: courante ? AppColors.primaryLight : AppColors.darkBorder,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Étape ${stage.rang}',
                    style: AppTypography.resized(AppTypography.labelMono, 11)
                        .copyWith(
                          color: courante
                              ? AppColors.primaryLight
                              : AppColors.darkTextTertiary,
                        ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      stage.nom,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  if (validee)
                    const Icon(
                      AppIcons.checkCircle,
                      size: 18,
                      color: AppColors.accent,
                    )
                  else
                    Text(
                      '${progress.abordees} / ${progress.total}',
                      style: AppTypography.resized(
                        AppTypography.labelMono,
                        11,
                      ).copyWith(color: AppColors.darkTextTertiary),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                stage.description,
                style: AppTypography.label.copyWith(
                  color: AppColors.darkTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppGauge(
                progress: progress.ratio,
                color: validee ? AppColors.accent : AppColors.primaryLight,
                height: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
