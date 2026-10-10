/// Les pièces de la page « Mentor Carlys » : l'emblème et son titre, le
/// choix de la fréquence, la carte du mot, la carte « désactivées ».
library;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_prefs.dart';
import '../../domain/mentor_word.dart';
import 'mentor_bandeau.dart';

/// La boussole du Mentor, « Personnalise ton accompagnement », sa phrase.
class MentorSettingsHero extends StatelessWidget {
  const MentorSettingsHero({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: AppIconBadge(icon: AppIcons.mentor, size: 96)),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            'Personnalise ton accompagnement',
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Un Mentor à ton image, pour avancer à ton rythme.',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.primaryLight),
        ),
      ],
    );
  }
}

/// « Fréquence » : deux crans, le Mentor est un repère, pas un flux.
class MentorFrequencyPicker extends StatelessWidget {
  const MentorFrequencyPicker({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final MentorFrequency selected;
  final ValueChanged<MentorFrequency> onSelected;

  /// Le cran le plus bavard d'abord, comme sur la maquette.
  static const _choix = [
    MentorFrequency.quotidienne,
    MentorFrequency.hebdomadaire,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Fréquence',
            style: AppTypography.heading.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'À quelle fréquence souhaites-tu recevoir un mot ?',
          style: AppTypography.body.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final (index, frequence) in _choix.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppIconChoiceTile(
                  icon: AppIcons.calendarOutline,
                  label: frequence.label,
                  selected: frequence == selected,
                  onTap: () => onSelected(frequence),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Son mot du moment, cité, sous sa cadence.
class MentorWordCard extends StatelessWidget {
  const MentorWordCard({required this.mot, required this.frequence, super.key});

  final MentorWord mot;
  final MentorFrequency frequence;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const AppIconBadge(icon: AppIcons.quote, size: 64),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mentorWordCadence(mot, frequence).toUpperCase(),
                  style: AppTypography.labelMono.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '« ${mot.message} »',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Interventions coupées : ce que cela change, et que c'est réversible.
class MentorInterventionsOffCard extends StatelessWidget {
  const MentorInterventionsOffCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const AppIconBadge(icon: AppIcons.info, size: 48),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Interventions désactivées',
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Le mot du Mentor est masqué sur l’accueil. Tu peux le '
                  'réactiver quand tu veux.',
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
