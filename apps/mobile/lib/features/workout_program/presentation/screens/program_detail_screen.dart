import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controllers.dart';
import '../widgets/program_day_sheet.dart';
import '../widgets/program_week_view.dart';

/// Le calendrier d'un programme, ÉDITABLE en place : chaque case s'affecte
/// d'un geste (repos, modèle, activité libre), l'interrupteur « suivi »
/// désigne le programme en cours — le serveur garantit qu'il n'y en a qu'un.
///
/// Le serveur reste la source de vérité : chaque geste envoie l'état COMPLET
/// (PUT), puis l'écran relit — pas de brouillon local qui divergerait.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({required this.programId, super.key});

  final String programId;

  Future<void> _editDay(
    BuildContext context,
    WidgetRef ref,
    ProgramDetail program, {
    required int weekNumber,
    required int dayOfWeek,
  }) async {
    final existing = program.dayAt(weekNumber, dayOfWeek);
    final choice = await showProgramDaySheet(
      context,
      hasExisting: existing != null,
    );
    if (choice == null) {
      return;
    }
    final actions = ref.read(programActionsProvider);
    final day = switch (choice) {
      ClearDayChoice() => null,
      RestDayChoice() => ProgramDayEntry(
          id: existing?.id ?? actions.newDayId(),
          weekNumber: weekNumber,
          dayOfWeek: dayOfWeek,
          label: 'Repos',
          isRest: true,
        ),
      TemplateDayChoice(:final templateId, :final name) => ProgramDayEntry(
          id: existing?.id ?? actions.newDayId(),
          weekNumber: weekNumber,
          dayOfWeek: dayOfWeek,
          templateId: templateId,
          label: name,
          isRest: false,
        ),
      FreeDayChoice(:final label) => ProgramDayEntry(
          id: existing?.id ?? actions.newDayId(),
          weekNumber: weekNumber,
          dayOfWeek: dayOfWeek,
          label: label,
          isRest: false,
        ),
    };
    await actions.setDay(
      program,
      weekNumber: weekNumber,
      dayOfWeek: dayOfWeek,
      day: day,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce programme ?'),
        content: const Text(
          'Les séances déjà réalisées restent dans l’historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await ref.read(programActionsProvider).delete(programId);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: detail.when(
          loading: () =>
              const AppLoadingIndicator(label: 'Chargement du programme'),
          error: (error, _) => ConnectionAwareError(
            error: error,
            title: 'Programme introuvable',
            message: 'Il a peut-être été supprimé.',
            offlineMessage: 'Le calendrier vit sur le serveur : il revient '
                'avec le réseau.',
            onRetry: () => ref.invalidate(programDetailProvider(programId)),
          ),
          data: (program) => ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter,
              AppSpacing.gutter + bottomInset,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      program.name,
                      style: AppTypography.display.copyWith(
                        fontSize: 27,
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _delete(context, ref),
                    tooltip: 'Supprimer le programme',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Programme suivi',
                        style: AppTypography.subheading
                            .copyWith(color: AppColors.darkTextPrimary),
                      ),
                    ),
                    Switch(
                      value: program.isActive,
                      onChanged: (value) => ref
                          .read(programActionsProvider)
                          .save(program.copyWith(isActive: value)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              for (var week = 1; week <= program.weeksCount; week++) ...[
                ProgramWeekView(
                  weekNumber: week,
                  program: program,
                  onEditDay: (dayOfWeek) => _editDay(
                    context,
                    ref,
                    program,
                    weekNumber: week,
                    dayOfWeek: dayOfWeek,
                  ),
                ),
                const SizedBox(height: AppSpacing.gapRow),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
