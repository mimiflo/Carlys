import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../progression/domain/progression.dart';
import '../../../progression/presentation/controllers/progression_controllers.dart';
import '../../../progression/presentation/controllers/reward_controllers.dart';
import 'section_title_bar.dart';

/// TON TITRE, vu de l'accueil : trois lignes, aucune surface.
///
/// La carte de 120 points qui vivait ici était une deuxième carte de titre,
/// en concurrence avec celle du profil de progression. L'accueil n'a pas à
/// refaire cet écran : il en donne l'état, et la porte pour y aller.
///
/// Adossé aux faits LOCAUX : il s'affiche donc même quand les statistiques
/// du serveur, autour de lui, sont hors ligne ou en erreur.
class TitleSummary extends ConsumerWidget {
  const TitleSummary({super.key});

  static const double _gaugeHeight = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(progressionProfileProvider);
    if (profile == null) {
      // L'historique local n'est pas encore lu. Rien vaut mieux qu'un titre
      // provisoire qui changerait sous les yeux.
      return const SizedBox.shrink();
    }

    final earned = ref.watch(showcaseRewardsProvider);
    final latest = earned.isEmpty ? null : earned.first;
    final opened = profile.points > 0;

    return Semantics(
      button: true,
      label: 'Ton titre : ${profile.title.label}, '
          '${profile.points} points sur $maxTotal',
      onTap: () => context.push(AppRoutes.progression),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => context.push(AppRoutes.progression),
          behavior: HitTestBehavior.opaque,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitleBar(
                icon: AppIcons.rank,
                label: 'Ton titre',
                // « NOUVEAU » ne s'allume que le jour où une récompense
                // vient d'être gravée : sinon il ne voudrait plus rien dire.
                trailing: latest?.isNew ?? false ? 'Nouveau' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    profile.title.label,
                    style: AppTypography.title.copyWith(
                      fontSize: 18,
                      letterSpacing: -0.36,
                      color: AppColors.darkTextPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs + 1),
                  Text(
                    '${opened ? profile.points : '—'} / $maxTotal',
                    style: AppTypography.labelMono.copyWith(
                      fontSize: 12,
                      letterSpacing: 0,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 1),
              _Gauge(value: profile.totalProgress, opened: opened),
              const SizedBox(height: AppSpacing.sm - 1),
              _Latest(reward: latest?.reward.label),
            ],
          ),
        ),
      ),
    );
  }
}

/// La jauge du titre. Sans point gagné, elle passe en tirets : une piste
/// vide se lirait comme un échec là où il n'y a que du temps devant soi.
class _Gauge extends StatelessWidget {
  const _Gauge({required this.value, required this.opened});

  final double value;
  final bool opened;

  @override
  Widget build(BuildContext context) {
    if (!opened) {
      return const SizedBox(
        height: TitleSummary._gaugeHeight,
        child: CustomPaint(painter: _PendingTrack(), size: Size.infinite),
      );
    }

    return ClipRRect(
      borderRadius: AppRadius.fullAll,
      child: SizedBox(
        height: TitleSummary._gaugeHeight,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.gaugeTrack),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.001, 1),
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.violetRamp),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingTrack extends CustomPainter {
  const _PendingTrack();

  static const double _dash = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.pendingTrack;
    for (var x = 0.0; x < size.width; x += _dash * 2) {
      final width = (size.width - x).clamp(0.0, _dash);
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_PendingTrack oldDelegate) => false;
}

class _Latest extends StatelessWidget {
  const _Latest({required this.reward});

  final String? reward;

  @override
  Widget build(BuildContext context) {
    final label = AppTypography.label.copyWith(
      fontSize: 12,
      color: AppColors.darkTextTertiary,
    );

    if (reward == null) {
      return Text('Ta première récompense t’attend.', style: label);
    }
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Dernière récompense : '),
          TextSpan(
            // Le style part du design system, jamais d'un `TextStyle` nu :
            // un fragment reconstruit à la main perdrait les polices de
            // repli, et le premier emoji d'un nom sortirait en tofu.
            text: reward,
            style: label.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.darkTextPrimary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: label,
    );
  }
}
