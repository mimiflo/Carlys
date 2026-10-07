import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout_template.dart';
import '../controllers/template_editor_controller.dart';
import '../providers/workout_template_providers.dart';
import '../utils/template_draft.dart';
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
    final editor = ref.watch(
      templateEditorControllerProvider(widget.templateId),
    );
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
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xs,
                  AppSpacing.gutter,
                  AppSpacing.md,
                ),
                child: AppScreenHeader.centered(
                  title: draft?.isNew ?? false
                      ? 'Nouvelle séance'
                      : 'Modifier une séance',
                  tagline: 'Compose ton entraînement',
                ),
              ),
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

  /// Enregistre : validation des bornes partagées avec l'API, écriture Drift
  /// puis mise en file — le tout côté repository, en une transaction.
  Future<void> _save(TemplateDraft draft) async {
    setState(() => _saving = true);
    try {
      await ref.read(workoutTemplateActionsProvider).save(draft.toInput());
    } on InvalidTemplateException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        AppNotices.of(context).show(error.message, tone: AppNoticeTone.error);
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

  Future<bool> _confirmDiscard() {
    return showAppConfirm(
      context,
      title: 'Abandonner les modifications ?',
      message: 'Ce modèle n’a pas été enregistré : tes réglages seront perdus.',
      confirmLabel: 'Abandonner',
      cancelLabel: 'Continuer l’édition',
      destructive: true,
      icon: AppIcons.confirmLeave,
    );
  }
}
