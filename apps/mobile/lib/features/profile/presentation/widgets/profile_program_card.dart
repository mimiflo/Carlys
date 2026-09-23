import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_program/domain/entities/program.dart';
import '../../../workout_program/domain/program_advancement.dart';
import '../providers/profile_hub_providers.dart';
import 'profile_hub_tile.dart';
import 'profile_hub_wording.dart';

/// « Mon programme » : le plan suivi, son nom et son rythme.
///
/// Quatre états, et aucun ne se confond avec un autre : en route (le titre
/// seul), hors ligne ou en panne (dit tel quel), aucun programme suivi (une
/// invitation), un programme (son nom, son rythme). « Aucun programme »
/// affiché hors ligne serait faux, et c'est exactement ce que l'ancien
/// `valueOrNull` aurait dit.
class ProfileProgramCard extends ConsumerWidget {
  const ProfileProgramCard({
    required this.onOpenProgram,
    required this.onBrowse,
    super.key,
  });

  /// Ouvre la fiche du programme suivi.
  final ValueChanged<String> onOpenProgram;

  /// Ouvre la liste des programmes — sans programme, ou si la lecture a
  /// échoué : la liste a son propre état d'erreur et son réessai.
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeProgramProvider);

    final (subtitle, detail) = switch (active) {
      AsyncData(value: final ProgramDetail program) => (
        program.name,
        rhythmLine(programRhythm(program), program.weeksCount),
      ),
      AsyncData() => ('Aucun programme suivi', 'Choisis-en un ou crée le tien'),
      AsyncError(:final error) => (unavailableLine(error), null),
      _ => (null, null),
    };
    final program = active.valueOrNull;

    return ProfileHubCard(
      children: [
        ProfileHubTile(
          icon: AppIcons.calendar,
          title: 'Mon programme',
          subtitle: subtitle,
          detail: detail,
          onTap: program == null ? onBrowse : () => onOpenProgram(program.id),
        ),
      ],
    );
  }
}
