import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/exercise.dart';
import '../utils/equipment_categories.dart';

/// Le nom du mouvement, puis ce qu'il travaille et ce qu'il demande : le
/// muscle principal et le matériel, en puces (maquette d'octobre 2026).
class ExerciseIdentity extends StatelessWidget {
  const ExerciseIdentity({required this.exercise, super.key});

  final ExerciseDetail exercise;

  @override
  Widget build(BuildContext context) {
    final muscle = exercise.primaryMuscleGroup;
    final equipment = exercise.equipment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            exercise.name,
            style: AppTypography.pageTitle.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        if (muscle != null || equipment.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (muscle != null)
                _Chip(
                  icon: AppIcons.muscleGroup,
                  label: muscle.name,
                  semanticLabel: 'Muscle principal : ${muscle.name}',
                ),
              if (equipment.isNotEmpty)
                _Chip(
                  icon: equipmentIcon(equipment.first.slug),
                  label: equipment.map((e) => e.name).join(' · '),
                  semanticLabel:
                      'Matériel : ${equipment.map((e) => e.name).join(', ')}',
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.semanticLabel,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: AppRadius.fullAll,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.darkBorder),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.primaryLight),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color: AppColors.primaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
