import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout_template.dart';
import '../controllers/template_draft.dart';
import '../controllers/template_editor_controller.dart';
import '../controllers/workout_template_controllers.dart';
import '../widgets/template_editor_bottom_bar.dart';
import '../widgets/template_editor_form.dart';

/// Éditeur d'un modèle de séance — **création et modification**.
///
/// La seule différence entre les deux : une création part d'un brouillon vide.
/// Le brouillon vit en mémoire ; l'écriture locale et la mise en file de
/// synchronisation n'ont lieu qu'à « Enregistrer ».
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({required this.templateId, super.key});

  final String templateId;

  @override
  ConsumerState<TemplateEditorScreen> createState() =>
      _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final editor =
        ref.watch(templateEditorControllerProvider(widget.templateId));
    final draft = editor.valueOrNull;

    return PopScope(
      // Sortir en perdant une composition serait la seule vraie perte de
      // travail de cet écran : on demande confirmation.
      canPop: draft == null || !draft.dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_confirmThenPop());
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(title: _title(draft)),
              Expanded(
                child: editor.when(
                  loading: () =>
                      const AppLoadingIndicator(label: 'Chargement du modèle'),
                  error: (_, __) => AppErrorState(
                    title: 'Modèle indisponible',
                    message: 'Ce modèle n’a pas pu être lu sur l’appareil.',
                    onRetry: () => ref.invalidate(
                      templateEditorControllerProvider(widget.templateId),
                    ),
                  ),
                  data: (loaded) => TemplateEditorForm(
                    templateId: widget.templateId,
                    draft: loaded,
                  ),
                ),
              ),
              if (draft != null)
                TemplateEditorBottomBar(
                  exercisesCount: draft.exercises.length,
                  plannedSetsCount: draft.plannedSetsCount,
                  canSave: draft.canSave,
                  saving: _saving,
                  onSave: () => _save(draft),
                  onCancel: _cancel,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(TemplateDraft? draft) {
    final name = draft?.name.trim() ?? '';
    return name.isEmpty ? 'Nouveau modèle' : name;
  }

  /// Enregistre : validation des bornes partagées avec l'API, écriture Drift
  /// puis mise en file — le tout côté repository, en une transaction.
  Future<void> _save(TemplateDraft draft) async {
    setState(() => _saving = true);
    try {
      await ref.read(workoutTemplateActionsProvider).save(draft.toInput());
    } on InvalidTemplateException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }
    if (mounted) {
      setState(() => _saving = false);
      context.pop();
    }
  }

  /// Sortie demandée par le geste système ou le bouton retour, avec des
  /// modifications non enregistrées.
  Future<void> _confirmThenPop() async {
    if (await _confirmDiscard() && mounted) {
      context.pop();
    }
  }

  Future<void> _cancel() async {
    final draft = ref
        .read(templateEditorControllerProvider(widget.templateId))
        .valueOrNull;
    if (draft != null && draft.dirty) {
      await _confirmThenPop();
      return;
    }
    if (mounted) {
      context.pop();
    }
  }

  Future<bool> _confirmDiscard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abandonner les modifications ?'),
        content: const Text(
          'Ce modèle n’a pas été enregistré : tes réglages seront perdus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuer l’édition'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

/// En-tête de l'éditeur : retour et nom du modèle en cours de composition.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.gutter,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          // La flèche commune, et non sa copie : cet en-tête en redessinait
          // une à l'identique, géométrie comprise, mais sans la garde qui
          // l'efface quand il n'y a rien à dépiler.
          const AppBackButton(),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.display.copyWith(
                fontSize: 27,
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
