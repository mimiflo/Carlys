import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../../exercises/presentation/providers/exercise_catalog_providers.dart';
import '../../domain/entities/training_profile.dart';
import '../providers/training_profile_providers.dart';
import 'training_setup_sections.dart';

/// Le bloc matériel, avec ses états : la taxonomie vient du serveur.
///
/// Partagé par « Préparer mon programme » et la page du coach : une coche
/// écrit au profil d'entraînement, quel que soit l'écran.
class TrainingEquipmentSection extends ConsumerWidget {
  const TrainingEquipmentSection({required this.profile, super.key});

  final TrainingProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(equipmentCatalogProvider);

    return switch (catalog) {
      AsyncData(:final value) when value.isEmpty => const AppEmptyState(
        icon: AppIcons.exercises,
        title: 'Catalogue vide',
        message: 'Le matériel du catalogue n’est pas encore chargé.',
      ),
      AsyncData(:final value) => EquipmentChecklist(
        catalog: value,
        ownedSlugs: profile.equipmentSlugs.toSet(),
        // La bascule vit dans les actions, SÉRIALISÉE : l'écran ne
        // calcule pas la liste — deux coches rapides se courraient après.
        onToggle: (equipment) async {
          final notices = AppNotices.of(context);
          try {
            await ref
                .read(trainingProfileActionsProvider)
                .toggleEquipment(equipment.slug);
          } on AppException catch (exception) {
            notices.show(exception.message, tone: AppNoticeTone.error);
          }
        },
      ),
      AsyncError() => AppErrorState(
        title: 'Matériel indisponible',
        message: 'Impossible de lire la liste du matériel.',
        onRetry: () => ref.invalidate(equipmentCatalogProvider),
      ),
      _ => const AppLoadingIndicator(),
    };
  }
}
