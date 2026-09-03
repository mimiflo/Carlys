import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../../workout_session/presentation/widgets/exercise_picker_sheet.dart';
import '../../domain/entities/workout_template.dart';
import '../controllers/template_draft.dart';
import '../controllers/template_editor_controller.dart';
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
  late final TextEditingController _name =
      TextEditingController(text: widget.draft.name);
  late final TextEditingController _notes =
      TextEditingController(text: widget.draft.notes ?? '');
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg + bottomInset,
      ),
      header: _Identity(
        name: _name,
        notes: _notes,
        duration: _duration,
        onName: _controller.setName,
        onNotes: _controller.setNotes,
        onDuration: _controller.setEstimatedDuration,
        exercisesCount: exercises.length,
        onAdd: _addExercise,
      ),
      footer: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: AppButton(
          label: 'Ajouter un exercice',
          variant: AppButtonVariant.secondary,
          icon: AppIcons.add,
          isExpanded: true,
          onPressed: _addExercise,
        ),
      ),
      itemCount: exercises.length,
      onReorderItem: _controller.moveExercise,
      itemBuilder: (context, index) {
        final exercise = exercises[index];
        return Padding(
          key: ValueKey(exercise.localId),
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: TemplateExerciseTile(
            exercise: exercise,
            position: index + 1,
            expanded: _expanded == exercise.localId,
            onToggle: () => setState(
              () => _expanded =
                  _expanded == exercise.localId ? null : exercise.localId,
            ),
            onRemove: () => _controller.removeExercise(index),
            onAddSet: () => _controller.addSet(index),
            onChangeSet: (setIndex, set) =>
                _controller.updateSet(index, setIndex, set),
            onRemoveSet: (setIndex) => _controller.removeSet(index, setIndex),
            dragHandle: ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: 20,
                  color: AppColors.darkTextTertiary,
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

/// Identité du modèle : nom, durée estimée, notes, puis l'en-tête de section
/// des exercices.
class _Identity extends StatelessWidget {
  const _Identity({
    required this.name,
    required this.notes,
    required this.duration,
    required this.onName,
    required this.onNotes,
    required this.onDuration,
    required this.exercisesCount,
    required this.onAdd,
  });

  final TextEditingController name;
  final TextEditingController notes;
  final TextEditingController duration;
  final ValueChanged<String> onName;
  final ValueChanged<String> onNotes;
  final ValueChanged<String> onDuration;
  final int exercisesCount;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Nom de la séance',
          controller: name,
          hint: 'Push force',
          textInputAction: TextInputAction.next,
          maxLength: WorkoutTemplateLimits.nameMax,
          onChanged: onName,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Durée estimée (minutes)',
          controller: duration,
          hint: 'Facultatif',
          keyboardType: TextInputType.number,
          onChanged: onDuration,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          label: 'Notes',
          controller: notes,
          hint: 'Facultatif',
          maxLines: 3,
          maxLength: WorkoutTemplateLimits.notesMax,
          onChanged: onNotes,
        ),
        const SizedBox(height: AppSpacing.gapSection),
        AppSectionHeader(
          title: 'Exercices',
          trailing: 'Ajouter',
          trailingIcon: AppIcons.add,
          trailingTone: AppSectionTrailingTone.primary,
          onTrailingTap: onAdd,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (exercisesCount == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'Aucun exercice pour l’instant. Ajoutes-en depuis le catalogue, '
              'puis règle les séries prévues.',
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
          ),
      ],
    );
  }
}
