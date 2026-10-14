import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/mentor_word.dart';
import 'mentor_voice_line.dart';

/// La médaille de la célébration, tirée de la maquette (fondu transparent).
const String mentorMedalAsset = 'assets/illustrations/mentor_medaille.webp';

/// Le bandeau du Mentor quand il fête un cap (maquette d'octobre 2026) :
/// la médaille, « Un nouveau cap », l'annonce, puis le mot de sa voix —
/// qui nomme la récompense — et la voix qui le dit.
class MentorCelebrationBandeau extends StatelessWidget {
  const MentorCelebrationBandeau({required this.mot, this.voix, super.key});

  final MentorWord mot;
  final String? voix;

  static const double _medalWidth = 96;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.padCard),
      decoration: const BoxDecoration(
        gradient: AppColors.mentorCelebration,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.majestyBorder),
        ),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Image.asset(
              mentorMedalAsset,
              width: _medalWidth,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                AppIcons.checkCircle,
                size: _medalWidth / 2,
                color: AppColors.neutral0,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'UN NOUVEAU CAP',
                  style: AppTypography.labelMono.copyWith(
                    color: AppColors.neutral0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Entier : sur un petit écran au texte agrandi, le titre se
                // resserre plutôt que de couper « récompense ».
                AppWholeWordsText(
                  'Une nouvelle récompense est à toi.',
                  // Deux lignes, comme la maquette : le titre à 22 en
                  // prenait trois à côté de la médaille.
                  style: AppTypography.resized(
                    AppTypography.title,
                    20,
                  ).copyWith(color: AppColors.neutral0),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  mot.message,
                  style: AppTypography.body.copyWith(color: AppColors.neutral0),
                ),
                const SizedBox(height: AppSpacing.sm),
                MentorVoiceLine(message: mot.message, voix: voix),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
