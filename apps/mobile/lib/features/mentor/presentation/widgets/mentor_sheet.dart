import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../data/flutter_tts_mentor_speaker.dart';
import '../../domain/mentor_speaker.dart';
import '../controllers/mentor_speech_controller.dart';
import '../providers/mentor_providers.dart';
import 'mentor_bandeau.dart';
import 'mentor_coach_note.dart';
import 'mentor_link_row.dart';
import 'mentor_sheet_header.dart';
import 'mentor_style_sheet.dart';
import 'mentor_tour_sheet.dart';
import 'mentor_voice_card.dart';

/// La feuille du Mentor (maquette d'octobre 2026) : son mot du moment, la
/// visite guidée, sa voix.
///
/// C'est la porte unique ouverte depuis l'accueil (« Pour toi ») : tout ce
/// que le Mentor sait faire tient ici, et chaque ligne mène à son geste.
/// Le bandeau parle depuis le dégradé VIOLET de l'application (règle 9 du
/// CLAUDE.md) — le dégradé de marque reste aux célébrations.
Future<void> showMentorSheet(BuildContext context) {
  return showAppSheet<void>(context, builder: (_) => const _MentorSheet());
}

class _MentorSheet extends ConsumerStatefulWidget {
  const _MentorSheet();

  @override
  ConsumerState<_MentorSheet> createState() => _MentorSheetState();
}

/// Ouvrir la feuille, c'est venir écouter le Mentor : il DIT son mot, à sa
/// voix — sauf « à voix haute » coupé, ou un lecteur d'écran actif (les deux
/// voix se couvriraient ; le bouton « Écouter » reste là). Fermer la
/// feuille le fait taire.
class _MentorSheetState extends ConsumerState<_MentorSheet> {
  late final MentorSpeechController _speech;
  late final MentorSpeaker _speaker;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(mentorSpeechControllerProvider.notifier);
    _speaker = ref.read(mentorSpeakerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) => _direSonMot());
  }

  Future<void> _direSonMot() async {
    if (!mounted || MediaQuery.of(context).accessibleNavigation) return;
    final prefs = await ref.read(mentorPrefsProvider.future);
    final mot = ref.read(mentorWordProvider);
    if (!mounted || !prefs.voixParlee || mot == null) return;
    await _speech.say(mentorWordSpeechKey, mot.message);
  }

  @override
  void dispose() {
    // Le moteur se tait tout de suite ; le contrôleur, lui, revient au
    // silence quand la phrase coupée rend la main — pas pendant le
    // démontage, où Riverpod refuse qu'on change un état.
    _speaker.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mot = ref.watch(mentorWordProvider);
    final style = ref.watch(currentMentorStyleProvider);
    final visite = ref.watch(mentorTourProgressProvider);
    final frequence = ref.watch(mentorPrefsProvider).valueOrNull?.frequence;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const MentorSheetHeader(
            title: 'Mentor Carlys',
            tagline: 'Un mot pour avancer',
          ),
          const SizedBox(height: AppSpacing.lg),
          MentorBandeau(mot: mot, frequence: frequence, voix: style?.label),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: MentorLinkRow(
              icon: AppIcons.tour,
              label: 'Visite guidée',
              description: 'Les sept espaces de Carlys, une étape à la fois.',
              value: visite?.resume,
              onTap: () {
                Navigator.of(context).pop();
                showMentorTourSheet(context);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: MentorLinkRow(
              icon: style == null ? AppIcons.forYou : mentorVoiceIcon(style),
              label: 'Sa voix',
              description: 'Le fond ne change pas, le ton oui.',
              value: style?.label ?? 'À choisir',
              onTap: () {
                Navigator.of(context).pop();
                showMentorStyleSheet(context);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.rowDivider),
          const SizedBox(height: AppSpacing.md),
          const MentorCoachNote(
            text: 'Sa voix teinte aussi les réponses du Coach IA.',
          ),
        ],
      ),
    );
  }
}
