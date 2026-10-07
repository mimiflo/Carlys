import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';

/// « Ton espace training » : les portes du hub, en tuiles — quatre en grille
/// de deux, puis le calendrier sur toute la largeur (maquette d'octobre
/// 2026). Le hub ne refait aucun écran : chaque porte mène à un écran qui
/// existe.
///
/// L'orange désigne ce qui est À SOI (ses séances, son historique), le
/// violet ce que l'appli propose (programmes, exercices, coach).
class TrainingSpace extends StatelessWidget {
  const TrainingSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TilePair(
          first: _Tile(
            icon: AppIcons.sessionTemplates,
            mine: true,
            title: 'Mes séances',
            subtitle: 'Tes modèles prêts à lancer.',
            onTap: () => context.push(AppRoutes.templates),
          ),
          second: _Tile(
            icon: AppIcons.calendarOutline,
            title: 'Programmes',
            subtitle: 'Tes semaines planifiées.',
            onTap: () => context.push(AppRoutes.programs),
          ),
        ),
        const SizedBox(height: AppSpacing.gapTile),
        _TilePair(
          first: _Tile(
            icon: AppIcons.workout,
            title: 'Exercices',
            subtitle: 'Explore par groupe musculaire.',
            onTap: () => context.push(AppRoutes.exercises),
          ),
          second: _Tile(
            icon: AppIcons.coach,
            title: 'Coach IA',
            subtitle: 'Questions et conseils adaptés.',
            onTap: () => context.push(AppRoutes.coach),
          ),
        ),
        const SizedBox(height: AppSpacing.gapTile),
        AppCard(
          onTap: () => context.push(AppRoutes.history),
          semanticLabel:
              'Calendrier & historique. Tes séances passées, mois par mois.',
          // Le libellé ci-dessus dit déjà tout : les textes ne se relisent pas.
          child: ExcludeSemantics(
            child: Row(
              children: [
                const _Badge(icon: AppIcons.trainingHistory, mine: true),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: _Wording(
                    title: 'Calendrier & historique',
                    subtitle: 'Tes séances passées, mois par mois.',
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                _chevron,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

const Widget _chevron = Icon(
  AppIcons.chevronRight,
  color: AppColors.primaryLight,
);

/// Deux tuiles de même hauteur, quelle que soit la longueur des textes.
class _TilePair extends StatelessWidget {
  const _TilePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: first),
          const SizedBox(width: AppSpacing.gapTile),
          Expanded(child: second),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.mine = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(icon: icon, mine: mine),
                const Spacer(),
                _chevron,
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _Wording(title: title, subtitle: subtitle),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.mine});

  final IconData icon;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return AppIconBadge(
      icon: icon,
      size: 52,
      color: mine ? AppColors.accent : AppColors.primaryLight,
      background: mine ? AppColors.accentBadgeBg : AppColors.primaryBadgeBg,
    );
  }
}

class _Wording extends StatelessWidget {
  const _Wording({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: AppTypography.body.copyWith(color: AppColors.primaryLight),
        ),
      ],
    );
  }
}
