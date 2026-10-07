import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/workout_template.dart';

/// Identité du modèle, en carte (maquette d'octobre 2026) : le nom, puis
/// durée estimée et notes côte à côte ; enfin l'en-tête des exercices.
class TemplateEditorIdentity extends StatelessWidget {
  const TemplateEditorIdentity({
    required this.name,
    required this.notes,
    required this.duration,
    required this.onName,
    required this.onNotes,
    required this.onDuration,
    required this.exercisesCount,
    super.key,
  });

  final TextEditingController name;
  final TextEditingController notes;
  final TextEditingController duration;
  final ValueChanged<String> onName;
  final ValueChanged<String> onNotes;
  final ValueChanged<String> onDuration;
  final int exercisesCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'Nom de la séance',
                controller: name,
                hint: 'Push force',
                suffixIcon: AppIcons.editOutline,
                suffixIconColor: AppColors.primaryLight,
                textInputAction: TextInputAction.next,
                maxLength: WorkoutTemplateLimits.nameMax,
                showCounter: false,
                onChanged: onName,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'Durée estimée',
                      controller: duration,
                      hint: '60',
                      prefixIcon: AppIcons.timer,
                      prefixIconColor: AppColors.primaryLight,
                      suffixText: 'min',
                      keyboardType: TextInputType.number,
                      onChanged: onDuration,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppTextField(
                      label: 'Notes',
                      controller: notes,
                      hint: 'Ajouter une note…',
                      minLines: 1,
                      maxLines: 4,
                      maxLength: WorkoutTemplateLimits.notesMax,
                      showCounter: false,
                      onChanged: onNotes,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.gapSection),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'Exercices',
                  style: AppTypography.pageTitle.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
            ),
            Text(
              _count(exercisesCount),
              style: AppTypography.body.copyWith(
                color: AppColors.darkTextSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          exercisesCount == 0
              ? 'Aucun exercice pour l’instant. Ajoutes-en depuis le '
                    'catalogue, puis règle les séries prévues.'
              : 'Glisse les poignées pour changer l’ordre.',
          style: AppTypography.body.copyWith(color: AppColors.primaryLight),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

String _count(int exercises) =>
    '${formatThousands(exercises)} exercice${exercises > 1 ? 's' : ''}';
