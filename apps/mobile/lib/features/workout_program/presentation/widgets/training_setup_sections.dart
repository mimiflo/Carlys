import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../exercises/domain/entities/exercise.dart';
import '../../domain/entities/training_profile.dart';

/// Les choix de rythme proposés — les bornes du contrat sont plus larges
/// (1 à 7, 15 à 240) : ces listes sont des PROPOSITIONS, pas des limites.
const List<int> weeklySessionsChoices = [2, 3, 4, 5, 6];
const List<int> sessionMinutesChoices = [30, 45, 60, 75, 90];

/// L'expérience : trois cartes de choix du design system, une sélection.
class ExperienceChoices extends StatelessWidget {
  const ExperienceChoices({
    required this.current,
    required this.onChoose,
    super.key,
  });

  final TrainingExperience? current;
  final ValueChanged<TrainingExperience> onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final experience in TrainingExperience.values) ...[
          AppChoiceCard(
            title: experience.label,
            description: experience.description,
            selected: experience == current,
            selectedSemantics: 'Expérience actuelle.',
            onTap: () => onChoose(experience),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

/// Le glyphe d'un matériel du catalogue, par son slug ; [AppIcons.exercises]
/// pour un matériel que l'appli ne connaît pas encore.
IconData equipmentIcon(String slug) => switch (slug) {
  'barre' => AppIcons.equipmentBarbell,
  'halteres' => AppIcons.equipmentDumbbell,
  'kettlebell' => AppIcons.equipmentKettlebell,
  'machine' => AppIcons.equipmentMachine,
  'poulie' => AppIcons.equipmentCable,
  'banc' => AppIcons.equipmentBench,
  'elastique' => AppIcons.equipmentBand,
  'poids-du-corps' => AppIcons.equipmentBodyweight,
  _ => AppIcons.exercises,
};

/// Le matériel : la taxonomie du catalogue, cochée ligne à ligne — chaque
/// geste écrit la liste COMPLÈTE, l'écran reflète l'état serveur.
class EquipmentChecklist extends StatelessWidget {
  const EquipmentChecklist({
    required this.catalog,
    required this.ownedSlugs,
    required this.onToggle,
    super.key,
  });

  final List<EquipmentRef> catalog;
  final Set<String> ownedSlugs;
  final ValueChanged<EquipmentRef> onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkSurfaceAlt,
        borderRadius: AppRadius.cardSecondaryAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Column(
        children: [
          for (final (index, equipment) in catalog.indexed) ...[
            if (index > 0)
              const Divider(height: 1, color: AppColors.darkBorder),
            _EquipmentRow(
              equipment: equipment,
              owned: ownedSlugs.contains(equipment.slug),
              onToggle: () => onToggle(equipment),
            ),
          ],
        ],
      ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({
    required this.equipment,
    required this.owned,
    required this.onToggle,
  });

  final EquipmentRef equipment;
  final bool owned;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: owned,
      label: '${equipment.name}${owned ? ', disponible' : ''}',
      // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
      onTap: onToggle,
      excludeSemantics: true,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(
                equipmentIcon(equipment.slug),
                size: 20,
                color: AppColors.primaryLight,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  equipment.name,
                  style: AppTypography.body.copyWith(
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ),
              Icon(
                owned ? AppIcons.checkCircle : AppIcons.uncheckedCircle,
                size: 20,
                color: owned
                    ? AppColors.primaryLight
                    : AppColors.darkTextTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
