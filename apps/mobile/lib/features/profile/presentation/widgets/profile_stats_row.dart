import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../dashboard/presentation/providers/home_day_providers.dart';
import '../providers/profile_hub_providers.dart';

/// Les trois chiffres sous l'identité : série, séances, amis.
///
/// La série est LOCALE (l'historique de l'appareil, la même que l'accueil) ;
/// les deux autres viennent du serveur. Un chiffre inconnu — pas encore lu,
/// ou pas pu l'être — s'affiche en tiret : un « 0 » hors ligne affirmerait
/// qu'on n'a ni séance ni ami.
class ProfileStatsRow extends ConsumerWidget {
  const ProfileStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(consistencyWeekProvider)?.streakDays;
    final sessions = ref.watch(profileSessionsCountProvider).valueOrNull;
    final friends = ref.watch(profileFriendsCountProvider).valueOrNull;

    const stats = [
      (
        AppIcons.streak,
        AppColors.accent,
        'jour consécutif',
        'jours consécutifs',
      ),
      (
        AppIcons.workout,
        AppColors.primary,
        'séance effectuée',
        'séances effectuées',
      ),
      (AppIcons.community, AppColors.primaryLight, 'ami', 'amis'),
    ];
    final values = [streak, sessions, friends];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Mesuré ICI, hors de l'`IntrinsicHeight` : le corps commun qui
        // laisse le plus long mot des trois libellés tenir dans sa colonne.
        // En texte ×1,5 sur 360 points, « consécutifs » se coupait en son
        // milieu.
        final column =
            (constraints.maxWidth - (stats.length - 1) * AppSpacing.md) /
            stats.length;
        final labelStyle = AppWholeWordsText.fittedStyle(
          context,
          texts: [
            for (var i = 0; i < stats.length; i++)
              _Stat.labelFor(values[i], stats[i].$3, stats[i].$4),
          ],
          style: _Stat.baseLabelStyle,
          maxWidth: column,
        );
        return IntrinsicHeight(
          child: Row(
            // Par le haut : les chiffres s'alignent, quel que soit le nombre
            // de lignes de leur libellé (« amis » en a une, les deux autres
            // deux).
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const _Separator(),
                Expanded(
                  child: _Stat(
                    icon: stats[i].$1,
                    color: stats[i].$2,
                    value: values[i],
                    singular: stats[i].$3,
                    plural: stats[i].$4,
                    labelStyle: labelStyle,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(
      width: AppSpacing.md,
      thickness: 1,
      color: AppColors.rowDivider,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.singular,
    required this.plural,
    required this.labelStyle,
  });

  final IconData icon;
  final Color color;
  final int? value;
  final String singular;
  final String plural;

  /// Le style du libellé, ajusté par la rangée à la largeur des colonnes.
  final TextStyle labelStyle;

  static const double _iconSize = 24;

  static final TextStyle baseLabelStyle = AppTypography.label.copyWith(
    color: AppColors.darkTextSecondary,
    height: 1.25,
  );

  /// Le libellé accordé : en français, zéro et un sont au singulier.
  static String labelFor(int? count, String singular, String plural) =>
      count != null && count <= 1 ? singular : plural;

  @override
  Widget build(BuildContext context) {
    final count = value;
    final label = labelFor(count, singular, plural);

    return Semantics(
      label: count == null
          ? '${_capitalized(plural)} : inconnu pour l’instant'
          : '${formatThousands(count)} $label',
      excludeSemantics: true,
      // Le libellé passe SOUS l'icône et le chiffre, sur toute la largeur
      // de la colonne. À droite de l'icône comme sur la maquette, il ne
      // disposait que d'une soixantaine de points sur un écran de 393 :
      // « consécutifs » n'y tenait pas, et le mot perdait sa dernière lettre.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: _iconSize, color: color),
              const SizedBox(width: AppSpacing.xs),
              // Le chiffre se resserre plutôt que de perdre ses derniers
              // chiffres sous une ellipse (« 1… » pour 148, en texte ×2).
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    count == null ? '—' : formatThousands(count),
                    maxLines: 1,
                    style: AppTypography.resized(
                      AppTypography.title,
                      19,
                    ).copyWith(color: AppColors.darkTextPrimary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(label, style: labelStyle),
        ],
      ),
    );
  }

  static String _capitalized(String text) =>
      '${text[0].toUpperCase()}${text.substring(1)}';
}
