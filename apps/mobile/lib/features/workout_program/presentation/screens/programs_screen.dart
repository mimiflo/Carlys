import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/connection_aware_error.dart';
import '../controllers/program_controllers.dart';
import '../widgets/create_program_sheet.dart';
import '../widgets/program_card.dart';

/// Mes programmes multi-semaines : la liste, et la porte de création.
///
/// La limite gratuite (2 programmes) est DÉCIDÉE PAR LE SERVEUR : l'écran ne
/// compte rien, il relaie le refus si l'API en oppose un.
class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final draft = await showCreateProgramSheet(context);
    if (draft == null) {
      return;
    }
    try {
      final id = await ref
          .read(programActionsProvider)
          .create(name: draft.name, weeksCount: draft.weeksCount);
      if (context.mounted) {
        await context.push(AppRoutes.programDetail(id));
      }
    } on AppException catch (exception) {
      if (context.mounted) {
        // Typiquement la limite gratuite : le message vient du serveur.
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(exception.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: ListView(
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
                  child: AppSectionHeader(
                    title: 'Programmes',
                    trailing: 'Nouveau',
                    trailingIcon: Icons.add_rounded,
                    trailingTone: AppSectionTrailingTone.accent,
                    onTrailingTap: () => _create(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Des semaines planifiées, chaque jour relié à un modèle.',
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
            const SizedBox(height: AppSpacing.gapRow),
            programs.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: AppSpacing.xl),
                child: AppLoadingIndicator(label: 'Chargement des programmes'),
              ),
              error: (error, _) => ConnectionAwareError(
                error: error,
                title: 'Programmes indisponibles',
                message: 'Tes programmes n’ont pas pu être chargés.',
                offlineMessage: 'Tes programmes vivent sur le serveur : ils '
                    'reviendront avec le réseau.',
                onRetry: () => ref.invalidate(programsProvider),
              ),
              data: (entries) => entries.isEmpty
                  ? AppEmptyState(
                      icon: Icons.calendar_month_outlined,
                      title: 'Aucun programme',
                      message:
                          'Planifie tes semaines : chaque jour renvoie à un '
                          'modèle de séance, ou à un simple intitulé.',
                      actionLabel: 'Créer un programme',
                      onAction: () => _create(context, ref),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final program in entries) ...[
                          ProgramCard(
                            program: program,
                            onOpen: () => context
                                .push(AppRoutes.programDetail(program.id)),
                          ),
                          const SizedBox(height: AppSpacing.gapRow),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
