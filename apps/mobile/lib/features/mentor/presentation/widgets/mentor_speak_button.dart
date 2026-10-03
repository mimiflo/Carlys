import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/mentor_speaker.dart';
import '../controllers/mentor_speech_controller.dart';

/// « Écouter » : le Mentor dit [text] à voix haute ; pendant qu'il parle,
/// le même bouton l'arrête. Partout où il parle — son mot, l'aperçu de ses
/// voix, la visite, les réponses du coach — c'est ce bouton.
///
/// [speechKey] distingue les phrases : un seul bouton à la fois montre
/// « Arrêter », celui de la phrase en cours.
class MentorSpeakButton extends ConsumerWidget {
  const MentorSpeakButton({
    required this.speechKey,
    required this.text,
    this.style,
    this.color = AppColors.primaryLight,
    this.size = 20,
    this.compact = false,
    super.key,
  });

  final String speechKey;
  final String text;

  /// La voix d'un style précis (aperçu) ; sinon, celle qui est choisie.
  final MentorStyle? style;
  final Color color;
  final double size;

  /// Sous une bulle : la cible tactile se resserre en hauteur (40 × 32) pour
  /// ne pas ouvrir une ligne vide sous chaque réponse.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speaking = ref.watch(mentorSpeechControllerProvider) == speechKey;
    return IconButton(
      onPressed: () => _toggle(context, ref),
      icon: Icon(
        speaking ? AppIcons.stopListening : AppIcons.listen,
        size: size,
        color: color,
      ),
      tooltip: speaking ? 'Arrêter la voix' : 'Écouter',
      visualDensity: VisualDensity.compact,
      style: compact
          ? IconButton.styleFrom(
              minimumSize: const Size(40, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final notices = AppNotices.of(context);
    final issue = await ref
        .read(mentorSpeechControllerProvider.notifier)
        .toggle(speechKey, text, style: style);
    final message = switch (issue) {
      MentorSpeechOutcome.dite => null,
      MentorSpeechOutcome.sansVoixFrancaise =>
        'Ton téléphone n’a pas de voix française : installe-la dans ses '
            'réglages de synthèse vocale.',
      MentorSpeechOutcome.echec =>
        'La voix n’a pas pu parler. Réessaie dans un instant.',
    };
    if (message != null) {
      notices.show(message, tone: AppNoticeTone.error);
    }
  }
}
