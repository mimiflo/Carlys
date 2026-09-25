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
