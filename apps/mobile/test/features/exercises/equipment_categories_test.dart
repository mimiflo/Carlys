import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/exercises/domain/entities/exercise.dart';
import 'package:carlys_mobile/features/exercises/presentation/utils/equipment_categories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  EquipmentRef ref(String slug) =>
      EquipmentRef(id: slug, slug: slug, name: slug);

  test('le catalogue se range par famille, dans l’ordre de l’écran', () {
    final groups = groupEquipment([
      ref('tapis'),
      ref('halteres'),
      ref('poulie'),
      ref('barre'),
      ref('inconnu'),
    ]);

    expect(
      [for (final (category, _) in groups) category],
      [
        EquipmentCategory.freeWeights,
        EquipmentCategory.machines,
        EquipmentCategory.bodyweight,
        EquipmentCategory.accessories,
      ],
    );
    // L'ordre du catalogue tient à l'intérieur d'une famille.
    expect([for (final e in groups.first.$2) e.slug], ['halteres', 'barre']);
    // Un matériel que l'appli ne connaît pas reste cochable.
    expect(groups.last.$2.single.slug, 'inconnu');
  });

  test('les quinze slugs du catalogue ont chacun leur famille', () {
    // `catalog-data.ts` côté API : un slug mal orthographié ici tomberait
    // sans bruit dans les accessoires.
    const attendu = {
      'barre': EquipmentCategory.freeWeights,
      'barre-ez': EquipmentCategory.freeWeights,
      'halteres': EquipmentCategory.freeWeights,
      'kettlebell': EquipmentCategory.freeWeights,
      'disque': EquipmentCategory.freeWeights,
      'medecine-ball': EquipmentCategory.freeWeights,
      'machine': EquipmentCategory.machines,
      'poulie': EquipmentCategory.machines,
      'poids-du-corps': EquipmentCategory.bodyweight,
      'barre-de-traction': EquipmentCategory.bodyweight,
      'rouleau': EquipmentCategory.bodyweight,
      'tapis': EquipmentCategory.bodyweight,
      'banc': EquipmentCategory.accessories,
      'elastique': EquipmentCategory.accessories,
      'ballon': EquipmentCategory.accessories,
    };
    // Quinze glyphes DISTINCTS : la barre EZ ne retombe plus sur la barre.
    expect(attendu.keys.map(equipmentIcon).toSet(), hasLength(15));
    attendu.forEach((slug, famille) {
      expect(EquipmentCategory.of(slug), famille, reason: slug);
      expect(equipmentIcon(slug), isNot(AppIcons.exercises), reason: slug);
    });
  });

  test('une famille sans matériel n’apparaît pas', () {
    expect(
      groupEquipment([ref('machine')]).single.$1,
      EquipmentCategory.machines,
    );
    expect(groupEquipment(const []), isEmpty);
  });
}
