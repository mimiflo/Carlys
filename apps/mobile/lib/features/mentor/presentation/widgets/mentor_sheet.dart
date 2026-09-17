import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/mentor_controllers.dart';
import 'mentor_style_sheet.dart';
import 'mentor_tour_sheet.dart';

/// La feuille du Mentor : son mot du moment, la visite guidée, sa voix.
///
/// C'est la porte unique ouverte depuis l'accueil (« Pour toi ») : tout ce
/// que le Mentor sait faire tient ici, et chaque ligne mène à son geste.
Future<void> showMentorSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorSheet());
}

class _MentorSheet extends ConsumerWidget {
  const _MentorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mot = ref.watch(mentorWordProvider);
    final style = ref.watch(currentMentorStyleProvider);
    final visite = ref.watch(mentorTourProgressProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Le Mentor Carlys', style: theme.textTheme.titleLarge),
          if (mot != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              mot.message,
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _Ligne(
            icon: AppIcons.exercises,
            label: 'Visite guidée',
            valeur: visite == null
                ? null
                : (visite.terminee
                      ? 'Terminée'
                      : '${visite.vues} / ${visite.total}'),
            onTap: () {
              Navigator.of(context).pop();
              showMentorTourSheet(context);
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          _Ligne(
            icon: AppIcons.forYou,
            label: 'Sa voix',
            valeur: style?.label ?? 'À choisir',
            onTap: () {
              Navigator.of(context).pop();
              showMentorStyleSheet(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Une ligne de la feuille : où elle mène, et l'état en un mot.
class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icon,
    required this.label,
    required this.onTap,
    this.valeur,
  });

  final IconData icon;
  final String label;
  final String? valeur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: valeur == null ? label : '$label, $valeur',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.darkBorder),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              if (valeur != null)
                Text(
                  valeur!,
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                AppIcons.chevronRight,
                size: 16,
                color: AppColors.darkTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
