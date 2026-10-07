import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_session/presentation/widgets/exercise_picker_sheet.dart';
import '../controllers/template_editor_controller.dart';
import '../utils/template_draft.dart';
import 'template_editor_identity.dart';
import 'template_exercise_tile.dart';

/// Formulaire de l'éditeur : identité du modèle puis ses lignes d'exercice,
/// réordonnables.
///
/// Les exercices viennent du **catalogue existant** ([showExercisePickerSheet],
/// option « exercice libre » comprise) : composer un modèle et saisir une
/// série se font au même endroit.
class TemplateEditorForm extends ConsumerStatefulWidget {
  const TemplateEditorForm({
    required this.templateId,
    required this.draft,
    super.key,
  });

  final String templateId;
  final TemplateDraft draft;

  @override
  ConsumerState<TemplateEditorForm> createState() => _TemplateEditorFormState();
}

class _TemplateEditorFormState extends ConsumerState<TemplateEditorForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.draft.name,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.draft.notes ?? '',
  );
  late final TextEditingController _duration = TextEditingController(
    text: widget.draft.estimatedDurationMinutes?.toString() ?? '',
  );

  /// Ligne dépliée, par identité d'écran — `null` quand tout est replié.
  String? _expanded;

  TemplateEditorController get _controller =>
      ref.read(templateEditorControllerProvider(widget.templateId).notifier);

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = widget.draft.exercises;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return ReorderableListView.builder(
      // Le pavé numérique d'iOS n'a pas de touche Entrée : faire défiler la
      // composition ferme le clavier.
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg + bottomInset,
      ),
      header: TemplateEditorIdentity(
        name: _name,
        notes: _notes,
        duration: _duration,
        onName: _controller.setName,
        onNotes: _controller.setNotes,
        onDuration: _controller.setEstimatedDuration,
        exercisesCount: exercises.length,
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: AppDashedButton(
          label: 'Ajouter un exercice',
          icon: AppIcons.addExercise,
          onPressed: _addExercise,
        ),
      ),
      itemCount: exercises.length,
      onReorderItem: _controller.moveExercise,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return Padding(
          key: ValueKey(exercise.localId),
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: TemplateExerciseTile(
            exercise: exercise,
            position: index + 1,
            expanded: _expanded == exercise.localId,
            onToggle: () => setState(
              () => _expanded = _expanded == exercise.localId
                  ? null
                  : exercise.localId,
            ),
            onRemove: () => _controller.removeExercise(index),
            onAddSet: () => _controller.addSet(index),
            onChangeSet: (setIndex, set) =>
                _controller.updateSet(index, setIndex, set),
            onRemoveSet: (setIndex) => _controller.removeSet(index, setIndex),
            onSetKindForAll: (kind) => _controller.setKindForAll(index, kind),
            dragHandle: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Icon(
                  AppIcons.dragHandle,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addExercise() async {
    final picked = await showExercisePickerSheet(context);
    if (picked == null) {
      return;
    }
    _controller.addExercise(name: picked.name, exerciseId: picked.exerciseId);
    // La ligne qu'on vient d'ajouter s'ouvre : on règle ses séries tout de
    // suite, sans un appui de plus.
    final added = ref
        .read(templateEditorControllerProvider(widget.templateId))
        .valueOrNull
        ?.exercises
        .last;
    if (added != null && mounted) {
      setState(() => _expanded = added.localId);
    }
  }
}
