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

    return IntrinsicHeight(
      child: Row(
        // Par le haut : les chiffres s'alignent, quel que soit le nombre de
        // lignes de leur libellé (« amis » en a une, les deux autres deux).
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Stat(
              icon: AppIcons.streak,
              color: AppColors.accent,
              value: streak,
              singular: 'jour consécutif',
              plural: 'jours consécutifs',
            ),
          ),
          const _Separator(),
          Expanded(
            child: _Stat(
              icon: AppIcons.workout,
              color: AppColors.primary,
              value: sessions,
              singular: 'séance effectuée',
              plural: 'séances effectuées',
            ),
          ),
          const _Separator(),
          Expanded(
            child: _Stat(
              icon: AppIcons.community,
              color: AppColors.primaryLight,
              value: friends,
              singular: 'ami',
              plural: 'amis',
            ),
          ),
        ],
      ),
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
  });

  final IconData icon;
  final Color color;
  final int? value;
  final String singular;
  final String plural;

  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    final count = value;
    final label = count != null && count <= 1 ? singular : plural;

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
              Flexible(
                child: Text(
                  count == null ? '—' : formatThousands(count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.resized(
                    AppTypography.title,
                    19,
                  ).copyWith(color: AppColors.darkTextPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(
            label,
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalized(String text) =>
      '${text[0].toUpperCase()}${text.substring(1)}';
}
