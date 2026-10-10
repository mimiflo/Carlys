import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/mentor_word.dart';
import 'mentor_speak_button.dart';

/// L'image de chaque voix — présentation pure, le domaine n'en sait rien.
IconData mentorVoiceIcon(MentorStyle style) => switch (style) {
  MentorStyle.bienveillant => AppIcons.voiceBienveillant,
  MentorStyle.exigeant => AppIcons.voiceExigeant,
  MentorStyle.athlete => AppIcons.voiceAthlete,
  MentorStyle.philosophe => AppIcons.voicePhilosophe,
};

/// Une voix à choisir (maquette d'octobre 2026) : sa pastille, son nom, ce
/// qu'elle change, son mot d'exemple — et, à droite, le rond du choix,
/// coché « Voix actuelle » pour celle qui parle.
///
/// « Écouter » est posé SUR la carte, pas dedans : la carte fond son
/// contenu en un seul nœud pour le lecteur d'écran, et un bouton à
/// l'intérieur y serait introuvable.
class MentorVoiceCard extends StatelessWidget {
  const MentorVoiceCard({
    required this.style,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final MentorStyle style;
  final bool selected;
  final VoidCallback onTap;

  static const double _badgeSize = 56;
  static const double _choiceSize = 32;

  @override
  Widget build(BuildContext context) {
    final exemple = mentorWordCatalog[style]!.first;
    return Stack(
      children: [
        Semantics(
          button: true,
          selected: selected,
          // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
          onTap: onTap,
          label:
              '${style.label}. ${style.description}'
              '${selected ? ' Voix actuelle.' : ''}',
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.cardSecondaryAll,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primaryCardSoft
                    : AppColors.darkSurfaceAlt,
                borderRadius: AppRadius.cardSecondaryAll,
                border: Border.fromBorderSide(
                  BorderSide(
                    color: selected
                        ? AppColors.primaryLight
                        : AppColors.darkBorder,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconBadge(icon: mentorVoiceIcon(style), size: _badgeSize),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.label,
                          style: AppTypography.subheading.copyWith(
                            color: AppColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          style.description,
                          style: AppTypography.body.copyWith(
                            color: AppColors.darkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '« $exemple »',
                          style: AppTypography.body.copyWith(
                            color: AppColors.darkTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Choice(selected: selected),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: AppSpacing.xxs,
          bottom: AppSpacing.xxs,
          child: MentorSpeakButton(
            speechKey: 'mentor.voix.${style.wire}',
            text: exemple,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Le rond du choix : vide, ou coché et nommé « Voix actuelle ».
class _Choice extends StatelessWidget {
  const _Choice({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (!selected) {
      return const Icon(
        AppIcons.choiceEmpty,
        size: MentorVoiceCard._choiceSize,
        color: AppColors.darkTextTertiary,
      );
    }
    return Column(
      children: [
        const AppIconBadge(
          icon: AppIcons.check,
          size: MentorVoiceCard._choiceSize,
          color: AppColors.neutral0,
          background: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Voix actuelle',
          style: AppTypography.label.copyWith(color: AppColors.primaryLight),
        ),
      ],
    );
  }
}
