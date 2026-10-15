import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../exercises/presentation/providers/exercise_catalog_providers.dart';
import '../../domain/entities/training_place.dart';
import '../../domain/entities/training_profile.dart';
import '../providers/training_profile_providers.dart';

/// La question du matériel, posée GLOBALEMENT : salle de sport, maison ou
/// sans matériel. Un choix remplace tout le matériel du profil par celui du
/// lieu ; le détail se règle dans « Préparer mon programme ».
class TrainingPlaceChoices extends ConsumerWidget {
  const TrainingPlaceChoices({required this.profile, super.key});

  final TrainingProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(equipmentCatalogProvider);

    return switch (catalog) {
      // Sans catalogue, « Salle de sport » n'écrirait rien.
      AsyncData(:final value) when value.isEmpty => const AppEmptyState(
        icon: AppIcons.exercises,
        title: 'Catalogue vide',
        message: 'Aucun matériel au catalogue pour l’instant.',
      ),
      AsyncData(:final value) => _Choices(
        owned: profile.equipmentSlugs.toSet(),
        catalog: [for (final equipment in value) equipment.slug],
        onChoose: (kit) => _write(context, ref, kit),
      ),
      AsyncError() => AppErrorState(
        title: 'Matériel indisponible',
        message: 'Impossible de lire la liste du matériel.',
        onRetry: () => ref.invalidate(equipmentCatalogProvider),
      ),
      _ => const AppLoadingIndicator(),
    };
  }

  Future<void> _write(
    BuildContext context,
    WidgetRef ref,
    List<String> kit,
  ) async {
    final notices = AppNotices.of(context);
    try {
      await ref.read(trainingProfileActionsProvider).replaceEquipment(kit);
    } on AppException catch (exception) {
      notices.show(exception.message, tone: AppNoticeTone.error);
    }
  }
}

class _Choices extends StatelessWidget {
  const _Choices({
    required this.owned,
    required this.catalog,
    required this.onChoose,
  });

  final Set<String> owned;
  final List<String> catalog;
  final ValueChanged<List<String>> onChoose;

  @override
  Widget build(BuildContext context) {
    final current = TrainingPlace.matching(owned, catalog);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Un lieu sans rien du catalogue n'écrirait qu'une liste vide.
        for (final place in TrainingPlace.values)
          if (place.kitIn(catalog).isNotEmpty) ...[
            AppChoiceCard(
              title: place.label,
              description: place.description,
              icon: switch (place) {
                TrainingPlace.gym => AppIcons.trainingPlaceGym,
                TrainingPlace.home => AppIcons.trainingPlaceHome,
                TrainingPlace.bodyweight => AppIcons.trainingPlaceBodyweight,
              },
              selected: place == current,
              selectedSemantics: 'Lieu actuel.',
              onTap: () => onChoose(place.kitIn(catalog)),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
        // Réglé au détail ailleurs : on le dit plutôt que de laisser croire
        // que rien n'est choisi.
        if (owned.isNotEmpty && current == null)
          Text(
            'Ton matériel est réglé au détail dans « Préparer mon '
            'programme ». Choisir un lieu le remplace.',
            style: AppTypography.label.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
      ],
    );
  }
}
