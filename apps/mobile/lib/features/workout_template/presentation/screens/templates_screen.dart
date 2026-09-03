import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../controllers/workout_template_controllers.dart';
import '../widgets/template_card.dart';
import '../widgets/templates_header.dart';

/// « Mes modèles » — les séances enregistrées, prêtes à être relancées.
///
/// La liste vient de la base locale : elle s'affiche **hors ligne** comme en
/// ligne, et l'état de synchronisation de chaque modèle est signalé par une
/// pastille, jamais par un écran d'erreur.
class TemplatesScreen extends ConsumerWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(workoutTemplatesProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xs,
                AppSpacing.xs,
                AppSpacing.gutter,
                0,
              ),
              child: TemplatesHeader(onCreate: () => _create(context, ref)),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: templates.when(
                loading: () =>
                    const AppLoadingIndicator(label: 'Chargement des modèles'),
                error: (_, __) => AppErrorState(
                  title: 'Modèles indisponibles',
                  message: 'Tes modèles n’ont pas pu être lus sur l’appareil.',
                  onRetry: () => ref.invalidate(workoutTemplatesProvider),
                ),
                data: (list) => RefreshIndicator(
                  // Rapatrie les modèles du serveur : utile après une
                  // réinstallation ou un changement d'appareil. Ne touche
                  // jamais à une modification locale non acquittée.
                  onRefresh: () =>
                      ref.read(workoutTemplateActionsProvider).refresh(),
                  child: list.isEmpty
                      ? _EmptyList(onCreate: () => _create(context, ref))
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.gutter,
                            0,
                            AppSpacing.gutter,
                            bottomInset + AppSpacing.gapSection,
                          ),
                          itemCount: list.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.gapTile),
                          itemBuilder: (context, index) {
                            final template = list[index];
                            return TemplateCard(
                              template: template,
                              onOpen: () => context.push(
                                AppRoutes.templateEditor(template.id),
                              ),
                              onStart: () => _start(context, ref, template.id),
                              onDelete: () => ref
                                  .read(workoutTemplateActionsProvider)
                                  .delete(template.id),
                            );
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Créer un modèle : un UUID est généré **sur l'appareil**, puis son éditeur
  /// s'ouvre. Rien n'est encore écrit — le brouillon vit en mémoire jusqu'à
  /// « Enregistrer ».
  void _create(BuildContext context, WidgetRef ref) {
    final id = ref.read(workoutTemplateActionsProvider).newTemplateId();
    context.push(AppRoutes.templateEditor(id));
  }

  /// Lancer un modèle : transaction locale (séance + plan + mise en file),
  /// puis l'écran de séance active. Aucun appel réseau, donc instantané et
  /// disponible hors ligne.
  ///
  /// Le domaine impose **au plus une séance en cours** : quand il y en a déjà
  /// une, on ne la remplace pas en silence, on propose de la reprendre.
  Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    if (ref.read(activeWorkoutProvider).valueOrNull != null) {
      final resume = await _confirmActiveSession(context);
      if (resume == true && context.mounted) {
        await context.push(AppRoutes.activeWorkout);
      }
      return;
    }

    try {
      await ref.read(workoutTemplateActionsProvider).start(templateId);
    } on StateError {
      // Course rare : une séance a démarré entre-temps. On ne perd rien, on
      // renvoie simplement l'utilisateur vers elle.
    }
    if (context.mounted) {
      await context.push(AppRoutes.activeWorkout);
    }
  }

  Future<bool?> _confirmActiveSession(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Une séance est en cours'),
        content: const Text(
          'Termine-la avant d’en lancer une autre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reprendre la séance'),
          ),
        ],
      ),
    );
  }
}

/// État vide, posé dans une liste défilante : sans ça, le geste de tirer pour
/// rapatrier ses modèles (réinstallation, nouvel appareil) serait justement
/// indisponible dans le seul cas où il sert.
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: constraints.maxHeight,
            child: AppEmptyState(
              title: 'Aucun modèle',
              message: 'Compose ta séance type une fois, '
                  'relance-la en un geste.',
              icon: AppIcons.workout,
              actionLabel: 'Créer un modèle',
              onAction: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}
