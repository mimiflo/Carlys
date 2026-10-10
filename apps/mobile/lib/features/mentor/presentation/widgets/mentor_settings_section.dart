import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../providers/mentor_providers.dart';
import 'mentor_voice_card.dart';

/// Groupe « MENTOR CARLYS » des réglages : une entrée vers sa page, qui
/// règle sa voix, ses interventions et leur fréquence. La valeur affichée
/// est la voix — ce qu'on y vient changer le plus souvent.
class MentorSettingsSection extends ConsumerWidget {
  const MentorSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(currentMentorStyleProvider);
    return AppSettingsGroup(
      label: 'Mentor Carlys',
      rows: [
        AppSettingsRow(
          icon: style == null ? AppIcons.mentor : mentorVoiceIcon(style),
          label: 'Personnaliser le Mentor',
          value: style?.label ?? 'Voix à choisir',
          onTap: () => context.push(AppRoutes.mentor),
        ),
      ],
    );
  }
}
