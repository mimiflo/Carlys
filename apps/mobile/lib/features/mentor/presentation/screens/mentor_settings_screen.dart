import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_prefs.dart';
import '../providers/mentor_providers.dart';
import '../widgets/mentor_coach_note.dart';
import '../widgets/mentor_link_row.dart';
import '../widgets/mentor_settings_parts.dart';
import '../widgets/mentor_style_sheet.dart';
import '../widgets/mentor_tour_sheet.dart';
import '../widgets/mentor_voice_card.dart';

/// « Mentor Carlys » (maquette d'octobre 2026), ouvert depuis les réglages :
/// sa voix, la visite, ses interventions, leur fréquence et son mot.
///
/// La voix vit sur le profil SERVEUR (elle teinte le coach partout) ; les
/// interventions, leur fréquence et la voix haute sont locales à
/// l'appareil, comme le thème : elles règlent quand le Mentor parle sur CET
/// écran d'accueil.
class MentorSettingsScreen extends ConsumerWidget {
  const MentorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(currentMentorStyleProvider);
    final prefs =
        ref.watch(mentorPrefsProvider).valueOrNull ?? MentorPrefs.defauts;
    final visite = ref.watch(mentorTourProgressProvider);
    final mot = ref.watch(mentorWordProvider);
    final actions = ref.read(mentorActionsProvider);

    return Scaffold(
      body: SafeArea(
        // Une page courte et fixe : tout est construit, rien n'est paresseux.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.xs,
            AppSpacing.gutter,
            AppSpacing.gapSection,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppScreenHeader.centered(
                title: 'Mentor Carlys',
                tagline: 'À ton rythme',
              ),
              const SizedBox(height: AppSpacing.lg),
              const MentorSettingsHero(),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    MentorLinkRow(
                      icon: style == null
                          ? AppIcons.forYou
                          : mentorVoiceIcon(style),
                      label: 'Sa voix',
                      description: 'Le ton du Mentor.',
                      value: style?.label ?? 'À choisir',
                      onTap: () => showMentorStyleSheet(context),
                    ),
                    const _Separateur(),
                    MentorLinkRow(
                      icon: AppIcons.tour,
                      label: 'La visite guidée',
                      description: 'Découvre son approche.',
                      value: visite?.resume,
                      onTap: () => showMentorTourSheet(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    MentorLinkRow(
                      icon: AppIcons.mentorInterventions,
                      label: 'Ses interventions',
                      description: 'Le mot du Mentor dans « Pour toi ».',
                      toggleValue: prefs.interventionsActives,
                      onToggle: (value) =>
                          actions.setInterventionsActives(actives: value),
                    ),
                    const _Separateur(),
                    MentorLinkRow(
                      icon: AppIcons.listen,
                      label: 'À voix haute',
                      description: 'Il dit son mot quand tu ouvres sa feuille.',
                      toggleValue: prefs.voixParlee,
                      onToggle: (value) => actions.setVoixParlee(active: value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              if (prefs.interventionsActives) ...[
                MentorFrequencyPicker(
                  selected: prefs.frequence,
                  onSelected: actions.setFrequence,
                ),
                if (mot != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  MentorWordCard(mot: mot, frequence: prefs.frequence),
                ],
              ] else
                const MentorInterventionsOffCard(),
              const SizedBox(height: AppSpacing.lg),
              const MentorCoachNote(
                text:
                    'Le style choisi s’applique aussi aux réponses du Coach IA.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le filet entre deux lignes d'une même carte, aligné sur leur texte.
class _Separateur extends StatelessWidget {
  const _Separateur();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: AppSpacing.md,
      endIndent: AppSpacing.md,
      color: AppColors.rowDivider,
    );
  }
}
