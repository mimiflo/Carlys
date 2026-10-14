import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'mentor_speak_button.dart';

/// La phrase « le mot du moment », pour le bouton comme pour la lecture à
/// l'ouverture de la feuille : une seule clé, un seul bouton « Arrêter ».
const String mentorWordSpeechKey = 'mentor.mot';

/// Le bas des bandeaux du Mentor (mot ordinaire ou célébration) : la voix
/// qui parle en pastille, puis le bouton qui dit le mot. La pastille se
/// resserre plutôt que de pousser le bouton hors de la carte (320 points,
/// texte agrandi).
class MentorVoiceLine extends StatelessWidget {
  const MentorVoiceLine({required this.message, this.voix, super.key});

  /// Ce que le bouton fait dire au Mentor.
  final String message;

  /// La voix (« Bienveillant »), `null` tant qu'elle n'est pas choisie : pas
  /// de pastille pour une voix qu'on n'a pas.
  final String? voix;

  @override
  Widget build(BuildContext context) {
    final voix = this.voix;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (voix != null)
          Flexible(
            // Le mot reste ENTIER : la pastille se resserre plutôt que de
            // couper « Bienveillant » ou de pousser le bouton hors champ.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neutral0.withValues(alpha: 0.16),
                  borderRadius: AppRadius.fullAll,
                ),
                child: Text(
                  voix,
                  style: AppTypography.label.copyWith(
                    color: AppColors.neutral0,
                  ),
                ),
              ),
            ),
          ),
        MentorSpeakButton(
          speechKey: mentorWordSpeechKey,
          text: message,
          color: AppColors.neutral0,
          size: 24,
        ),
      ],
    );
  }
}
