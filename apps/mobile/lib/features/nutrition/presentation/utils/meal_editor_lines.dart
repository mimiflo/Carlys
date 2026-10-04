/// Ce que devient l'état de l'écran de repas quand sa COMPOSITION bouge :
/// un aliment ajouté, requantifié ou retiré. Des fonctions pures, pour que
/// le contrôleur ne garde que sa conduite (quand écrire, quand refuser).
library;

import '../../domain/entities/nutrition.dart';
import 'meal_editor_state.dart';

extension MealEditorLines on MealEditorState {
  /// La ligne [line] ajoutée au bout. Les aliments font désormais la
  /// quantité : elle se dit en grammes. [source] est la mention de la base
  /// d'où vient l'aliment.
  MealEditorState withLine(MealLine line, FoodSource source) => copyWith(
    lines: [...lines, line],
    linesChanged: true,
    unit: MealQuantityUnit.gram,
    attribution: source,
  );

  /// Le résultat d'un scan d'assiette : chaque aliment RECONNU par la base
  /// devient une ligne (sous un identifiant de [newId]), la photo prise est
  /// jointe, et le nom du repas reprend leurs noms courts s'il est vide. Un
  /// aliment que la base n'a pas su nommer reste hors du repas : l'écran le
  /// dit, la personne l'ajoute à la main.
  MealEditorState withScan(MealScanSeed scan, String Function() newId) {
    var next = copyWith(photo: NewMealPhoto(scan.photo));
    final names = <String>[];
    for (final item in scan.items) {
      final food = item.food;
      if (food == null) continue;
      names.add(food.shortName);
      next = next.withLine(
        MealLine.fromFood(
          id: newId(),
          food: food,
          quantityG: item.grams.toDouble(),
          sourceVersion: scan.source.version,
        ),
        scan.source,
      );
    }
    if (name.trim().isEmpty && names.isNotEmpty) {
      next = next.copyWith(name: names.toSet().join(', '));
    }
    return next;
  }

  /// La quantité de la ligne [lineId] corrigée. Elle garde son identifiant :
  /// le serveur garde donc son instantané, et ne relit pas la base.
  MealEditorState withLineQuantity(String lineId, double grams) => copyWith(
    lines: [
      for (final line in lines)
        line.id == lineId ? line.withQuantity(grams) : line,
    ],
    linesChanged: true,
  );

  /// La ligne [lineId] retirée. La DERNIÈRE retirée, le repas redevient
  /// saisi à la main et GARDE ses derniers totaux, comme le fera le
  /// serveur : les cases se remplissent de ce qu'elles affichaient, à
  /// corriger au besoin.
  MealEditorState withoutLine(String lineId) {
    final kept = [
      for (final line in lines)
        if (line.id != lineId) line,
    ];
    if (kept.isNotEmpty) {
      return copyWith(lines: kept, linesChanged: true);
    }
    final last = totals;
    return copyWith(
      lines: const [],
      linesChanged: true,
      kcalText: '${last.kcal}',
      proteinText: last.proteinG?.toString() ?? '',
      carbsText: last.carbsG?.toString() ?? '',
      fatText: last.fatG?.toString() ?? '',
      quantityText: formatQuantityInput(last.quantityG),
      unit: MealQuantityUnit.gram,
    );
  }
}
