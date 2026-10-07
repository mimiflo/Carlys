import 'package:flutter/widgets.dart';

import '../../../../design_system/design_system.dart';
import '../../../exercises/domain/entities/exercise.dart';

/// Les familles du matériel, pour qu'on coche par GROUPE plutôt que ligne à
/// ligne : la taxonomie du catalogue est plate, et quinze lignes d'affilée
/// se lisaient comme une corvée. L'ordre est celui de l'écran.
enum EquipmentCategory {
  freeWeights('Poids libres', AppIcons.equipmentDumbbell),
  machines('Machines et poulies', AppIcons.equipmentMachine),
  bodyweight('Au poids du corps', AppIcons.equipmentBodyweight),
  accessories('Accessoires', AppIcons.equipmentBand);

  const EquipmentCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  /// La famille d'un matériel, par son slug. Un matériel que l'appli ne
  /// connaît pas encore (ajouté au catalogue depuis) tombe dans les
  /// accessoires : il reste cochable.
  static EquipmentCategory of(String slug) =>
      _known[slug]?.$1 ?? EquipmentCategory.accessories;
}

/// UNE table pour la famille et le glyphe : deux aiguillages sur les mêmes
/// slugs finiraient par diverger. Les quinze slugs du catalogue
/// (`catalog-data.ts` côté API).
const Map<String, (EquipmentCategory, IconData)> _known = {
  'barre': (EquipmentCategory.freeWeights, AppIcons.equipmentBarbell),
  'barre-ez': (EquipmentCategory.freeWeights, AppIcons.equipmentBarbell),
  'halteres': (EquipmentCategory.freeWeights, AppIcons.equipmentDumbbell),
  'kettlebell': (EquipmentCategory.freeWeights, AppIcons.equipmentKettlebell),
  'disque': (EquipmentCategory.freeWeights, AppIcons.equipmentPlate),
  'medecine-ball': (EquipmentCategory.freeWeights, AppIcons.equipmentBall),
  'machine': (EquipmentCategory.machines, AppIcons.equipmentMachine),
  'poulie': (EquipmentCategory.machines, AppIcons.equipmentCable),
  'poids-du-corps': (
    EquipmentCategory.bodyweight,
    AppIcons.equipmentBodyweight,
  ),
  'barre-de-traction': (
    EquipmentCategory.bodyweight,
    AppIcons.equipmentPullUpBar,
  ),
  'rouleau': (EquipmentCategory.bodyweight, AppIcons.equipmentRoller),
  'tapis': (EquipmentCategory.bodyweight, AppIcons.equipmentMat),
  'banc': (EquipmentCategory.accessories, AppIcons.equipmentBench),
  'elastique': (EquipmentCategory.accessories, AppIcons.equipmentBand),
  'ballon': (EquipmentCategory.accessories, AppIcons.equipmentBall),
};

/// Le catalogue rangé par famille, dans l'ordre des familles puis du
/// catalogue ; une famille sans matériel n'apparaît pas.
List<(EquipmentCategory, List<EquipmentRef>)> groupEquipment(
  List<EquipmentRef> catalog,
) => [
  for (final category in EquipmentCategory.values)
    if (catalog.where((e) => EquipmentCategory.of(e.slug) == category).toList()
        case final items when items.isNotEmpty)
      (category, items),
];

/// Le glyphe d'un matériel du catalogue, par son slug ; [AppIcons.exercises]
/// pour un matériel que l'appli ne connaît pas encore.
IconData equipmentIcon(String slug) => _known[slug]?.$2 ?? AppIcons.exercises;
