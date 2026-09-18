import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../controllers/mentor_controllers.dart';
import 'mentor_bandeau.dart';
import 'mentor_style_sheet.dart';
import 'mentor_tour_sheet.dart';

/// La feuille du Mentor : son mot du moment, la visite guidée, sa voix.
///
/// C'est la porte unique ouverte depuis l'accueil (« Pour toi ») : tout ce
/// que le Mentor sait faire tient ici, et chaque ligne mène à son geste.
/// Le bandeau parle depuis le dégradé VIOLET de l'application (règle 9 du
/// CLAUDE.md) — le dégradé de marque reste aux célébrations.
Future<void> showMentorSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorSheet());
}

class _MentorSheet extends ConsumerWidget {
  const _MentorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mot = ref.watch(mentorWordProvider);
    final style = ref.watch(currentMentorStyleProvider);
    final visite = ref.watch(mentorTourProgressProvider);
    final frequence = ref.watch(mentorPrefsProvider).valueOrNull?.frequence;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MentorBandeau(mot: mot, frequence: frequence),
          const SizedBox(height: AppSpacing.md),
          _Ligne(
            icon: AppIcons.tour,
            label: 'Visite guidée',
            description: 'Les sept pièces de l’application, une par étape.',
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
            icon: style == null ? AppIcons.forYou : mentorVoiceIcon(style),
            label: 'Sa voix',
            description: 'Le fond ne change pas, le ton oui.',
            valeur: style?.label ?? 'À choisir',
            onTap: () {
              Navigator.of(context).pop();
              showMentorStyleSheet(context);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                AppIcons.info,
                size: 14,
                color: AppColors.darkTextTertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Sa voix teinte aussi les réponses du coach IA.',
                  style: AppTypography.label.copyWith(
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Une ligne de la feuille : où elle mène, ce qu'on y trouve, l'état.
class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.valeur,
  });

  final IconData icon;
  final String label;
  final String description;
  final String? valeur;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: valeur == null ? label : '$label, $valeur',
      // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.darkSurfaceAlt,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.darkBorder),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBadgeBg,
                ),
                child: Icon(icon, size: 18, color: AppColors.primaryLight),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.body.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description,
                      style: AppTypography.label.copyWith(
                        color: AppColors.darkTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (valeur != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  valeur!,
                  style: AppTypography.label.copyWith(
                    color: AppColors.primaryLight,
                  ),
                ),
              ],
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
