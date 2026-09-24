import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/feedback/server_gesture.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../../domain/entities/program.dart';
import '../controllers/program_controllers.dart';
import '../widgets/program_day_sheet.dart';
import '../widgets/program_settings_card.dart';
import '../widgets/program_week_view.dart';

/// Le calendrier d'un programme, ÉDITABLE en place : chaque case s'affecte
/// d'un geste (repos, modèle, activité libre), l'interrupteur « suivi »
/// désigne le programme en cours — le serveur garantit qu'il n'y en a qu'un.
///
/// Le serveur reste la source de vérité : chaque geste envoie l'état COMPLET
/// (PUT), puis l'écran relit — pas de brouillon local qui divergerait. Et
/// comme le calendrier n'a AUCUNE file hors ligne, chaque geste passe par
/// `runServerGesture` : un refus ou une coupure se DIT, il ne se perd pas.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({required this.programId, super.key});

  static const _scope = 'ProgramDetailScreen';

  final String programId;

  Future<void> _editDay(
    BuildContext context,
    WidgetRef ref, {
    required bool hasExisting,
    required int weekNumber,
    required int dayOfWeek,
  }) async {
    final choice = await showProgramDaySheet(context, hasExisting: hasExisting);
    if (choice == null || !context.mounted) {
      return;
    }
    final actions = ref.read(programActionsProvider);
    // La case se bâtit sur l'état serveur FRAIS relu par l'action au moment
    // de l'écriture — l'instantané du tap, lui, pouvait déjà être périmé
    // par le geste précédent (le PUT est un état complet : il aurait
    // effacé ce que ce geste-là venait de poser).
    await runServerGesture(context, scope: _scope, () async {
      await actions.setDay(
        programId,
        weekNumber: weekNumber,
        dayOfWeek: dayOfWeek,
        build: (existing) => switch (choice) {
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
        },
      );
      return null;
    });
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Supprimer ce programme ?',
      message: 'Les séances déjà réalisées restent dans l’historique.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    // On ne quitte l'écran QUE si la suppression a abouti : hors ligne, le
    // programme existe toujours — partir en silence aurait dit le contraire.
    final notices = AppNotices.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(programActionsProvider).delete(programId);
    } on AppException catch (exception) {
      notices.show(serverFailureMessage(exception), tone: AppNoticeTone.error);
      return;
    }
    if (context.mounted) {
      navigator.pop();
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
            offlineMessage:
                'Le calendrier vit sur le serveur : il revient '
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
                  const AppBackButton(),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      program.name,
                      style: AppTypography.pageTitle.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _delete(context, ref),
                    tooltip: 'Supprimer le programme',
                    icon: const Icon(
                      AppIcons.delete,
                      color: AppColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ProgramSettingsCard(
                program: program,
                // `setActive` et `setStartsOn` relisent l'état serveur frais
                // (jamais un instantané), et l'échec se DIT — l'interrupteur
                // retombait en silence.
                onActive: (value) =>
                    runServerGesture(context, scope: _scope, () async {
                      await ref
                          .read(programActionsProvider)
                          .setActive(programId, active: value);
                      return null;
                    }),
                onStartsOn: (day) =>
                    runServerGesture(context, scope: _scope, () async {
                      await ref
                          .read(programActionsProvider)
                          .setStartsOn(programId, day);
                      return null;
                    }),
                onOpenCalendar: () =>
                    context.push(AppRoutes.programCalendar(programId)),
              ),
              const SizedBox(height: AppSpacing.gapSection),
              for (var week = 1; week <= program.weeksCount; week++) ...[
                ProgramWeekView(
                  weekNumber: week,
                  program: program,
                  onEditDay: (dayOfWeek) => _editDay(
                    context,
                    ref,
                    hasExisting: program.dayAt(week, dayOfWeek) != null,
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
