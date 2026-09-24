import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/mentor_word.dart';
import '../controllers/mentor_controllers.dart';

/// L'image de chaque voix — présentation pure, le domaine n'en sait rien.
IconData mentorVoiceIcon(MentorStyle style) => switch (style) {
  MentorStyle.bienveillant => AppIcons.voiceBienveillant,
  MentorStyle.exigeant => AppIcons.voiceExigeant,
  MentorStyle.athlete => AppIcons.voiceAthlete,
  MentorStyle.philosophe => AppIcons.voicePhilosophe,
};

/// Feuille « La voix du Mentor » : quatre styles, un choix, modifiable à
/// tout moment. La sélection affichée vient de `AuthUser.mentorStyle` (une
/// seule source de vérité) ; choisir écrit au serveur puis rafraîchit
/// l'utilisateur, et un échec s'affiche sans rien changer. Chaque carte
/// fait ENTENDRE sa voix : le premier mot de son catalogue, cité tel quel.
Future<void> showMentorStyleSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorStyleSheet());
}

class _MentorStyleSheet extends ConsumerWidget {
  const _MentorStyleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentMentorStyleProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'La voix du Mentor',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Comment il te parle : le fond ne change pas, le ton oui. '
            'Essaie, change quand tu veux.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final style in MentorStyle.values) ...[
            // La carte est celle du design system ; la feuille n'apporte
            // que le contenu de la voix — et son mot d'exemple en pied.
            AppChoiceCard(
              icon: mentorVoiceIcon(style),
              title: style.label,
              description: style.description,
              selected: style == current,
              selectedSemantics: 'Voix actuelle.',
              onTap: () => _choisir(context, ref, style),
              footer: _ExempleDeVoix(style: style),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }

  Future<void> _choisir(
    BuildContext context,
    WidgetRef ref,
    MentorStyle style,
  ) async {
    final notices = AppNotices.of(context);
    // La route de LA feuille, capturée avant l'attente. Le navigateur
    // RACINE, lui, reste « monté » toute la vie de l'application : sa garde
    // ne disait rien, et un second choix pendant l'appel réseau fermait
    // l'écran situé SOUS la feuille. `isCurrent` neutralise aussi le
    // double-tap : le premier pop rend la route non courante.
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(mentorActionsProvider).chooseStyle(style);
      if (context.mounted && (route?.isCurrent ?? false)) {
        navigator.pop();
      }
      notices.show(
        'Le Mentor parlera en ${style.label}.',
        tone: AppNoticeTone.success,
      );
    } on AppException catch (exception) {
      notices.show(exception.message, tone: AppNoticeTone.error);
    }
  }
}

/// Le mot d'exemple d'une voix, cité tel quel : on ENTEND la voix avant
/// de la choisir.
class _ExempleDeVoix extends StatelessWidget {
  const _ExempleDeVoix({required this.style});

  final MentorStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(AppIcons.quote, size: 14, color: AppColors.primaryLight),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '« ${mentorWordCatalog[style]!.first} »',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
        ),
      ],
    );
  }
}
