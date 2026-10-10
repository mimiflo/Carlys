import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/mentor_word.dart';
import '../controllers/mentor_speech_controller.dart';
import '../providers/mentor_providers.dart';
import 'mentor_sheet_header.dart';
import 'mentor_voice_card.dart';

/// Feuille « La voix du Mentor » : quatre styles, un choix, modifiable à
/// tout moment. La sélection affichée vient de `AuthUser.mentorStyle` (une
/// seule source de vérité) ; choisir écrit au serveur puis rafraîchit
/// l'utilisateur, et un échec s'affiche sans rien changer. Chaque carte
/// fait ENTENDRE sa voix : le premier mot de son catalogue, cité tel quel
/// (maquette d'octobre 2026 : `MentorVoiceCard`).
Future<void> showMentorStyleSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorStyleSheet());
}

class _MentorStyleSheet extends ConsumerWidget {
  const _MentorStyleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentMentorStyleProvider);

    // Quatre cartes et leurs exemples : en grand texte, elles dépassent
    // l'écran — la feuille défile au lieu de couper la dernière voix.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MentorSheetHeader(
            title: 'La voix du Mentor',
            tagline: 'Le ton qui te correspond',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Le fond ne change pas, le ton oui.\nChange quand tu veux.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.primaryLight),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final style in MentorStyle.values) ...[
            MentorVoiceCard(
              style: style,
              selected: style == current,
              onTap: () => _choisir(context, ref, style),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Touche un style pour le choisir.',
            textAlign: TextAlign.center,
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
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
    // Capturés AVANT les attentes : la feuille se ferme en route, et ni
    // `ref` ni `context` ne valent plus rien après. Avec un lecteur d'écran,
    // pas de seconde voix par-dessus la sienne.
    final speech = ref.read(mentorSpeechControllerProvider.notifier);
    final prefs = ref.read(mentorPrefsProvider.future);
    final lecteurEcran = MediaQuery.of(context).accessibleNavigation;
    try {
      await ref.read(mentorActionsProvider).chooseStyle(style);
      if (context.mounted && (route?.isCurrent ?? false)) {
        navigator.pop();
      }
      notices.show(
        'Le Mentor parlera en ${style.label}.',
        tone: AppNoticeTone.success,
      );
      // Il le DIT aussi, de sa nouvelle voix : le choix s'entend.
      if ((await prefs).voixParlee && !lecteurEcran) {
        await speech.say(
          'mentor.voix.${style.wire}',
          mentorWordCatalog[style]!.first,
          style: style,
        );
      }
    } on AppException catch (exception) {
      notices.show(exception.message, tone: AppNoticeTone.error);
    }
  }
}
