import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/mentor_prefs.dart';
import '../controllers/mentor_controllers.dart';
import 'mentor_style_sheet.dart';
import 'mentor_tour_sheet.dart';

/// Groupe « MENTOR CARLYS » du profil : sa voix, ses interventions, leur
/// fréquence.
///
/// La voix vit sur le profil SERVEUR (elle teinte le coach partout) ; les
/// interventions et leur fréquence sont locales à l'appareil, comme le
/// thème : elles règlent quand le Mentor parle sur CET écran d'accueil.
class MentorSettingsSection extends ConsumerWidget {
  const MentorSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(currentMentorStyleProvider);
    final prefs =
        ref.watch(mentorPrefsProvider).valueOrNull ?? MentorPrefs.defauts;
    final visite = ref.watch(mentorTourProgressProvider);

    return AppSettingsGroup(
      label: 'Mentor Carlys',
      rows: [
        AppSettingsRow(
          icon: style == null ? AppIcons.forYou : mentorVoiceIcon(style),
          label: 'Sa voix',
          value: style?.label ?? 'À choisir',
          onTap: () => showMentorStyleSheet(context),
        ),
        AppSettingsRow(
          icon: AppIcons.tour,
          label: 'La visite guidée',
          value: visite == null
              ? '—'
              : (visite.terminee
                    ? 'Terminée'
                    : '${visite.vues} / ${visite.total}'),
          onTap: () => showMentorTourSheet(context),
        ),
        AppSettingsRow(
          icon: AppIcons.spark,
          label: 'Ses interventions',
          toggleValue: prefs.interventionsActives,
          onToggle: (value) => ref
              .read(mentorActionsProvider)
              .setInterventionsActives(actives: value),
        ),
        if (prefs.interventionsActives)
          AppSettingsRow(
            icon: AppIcons.calendar,
            label: 'Fréquence',
            value: prefs.frequence.label,
            // Deux crans : le geste bascule de l'un à l'autre, pas besoin
            // d'un écran pour un choix binaire.
            onTap: () => ref
                .read(mentorActionsProvider)
                .setFrequence(
                  prefs.frequence == MentorFrequency.hebdomadaire
                      ? MentorFrequency.quotidienne
                      : MentorFrequency.hebdomadaire,
                ),
          ),
      ],
    );
  }
}
