/// Les champs de la feuille de repas, extraits de la feuille elle-même.
///
/// Ils ont deux appelants — ajouter et corriger — et la feuille dépassait
/// son budget en les gardant. Chacun porte SES bornes, alignées sur celles
/// du contrat serveur : une borne recopiée dans deux fichiers est une borne
/// qu'on oubliera de corriger dans l'un des deux.
library;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/meal_entry.dart';

/// Un champ de macro : même libellé facultatif, mêmes bornes, même message.
///
/// Extrait parce qu'il y en a TROIS : recopier le validateur trois fois, ce
/// serait trois endroits où corriger une borne, et deux occasions d'oublier.
class MealMacroField extends StatelessWidget {
  const MealMacroField({
    required this.label,
    required this.controller,
    this.onSubmitted,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Fourni sur le DERNIER champ seulement : la touche de validation du
  /// clavier y enregistre au lieu de passer au champ suivant.
  final VoidCallback? onSubmitted;

  /// Bornes du contrat serveur (`@Min(0) @Max(1_000)`), en un seul endroit.
  static const int maxGrams = 1000;

  @override
  Widget build(BuildContext context) {
    final valider = onSubmitted;

    return AppTextField(
      label: label,
      controller: controller,
      hint: 'facultatif',
      keyboardType: TextInputType.number,
      textInputAction: valider == null
          ? TextInputAction.next
          : TextInputAction.done,
      validator: (value) {
        final raw = value?.trim() ?? '';
        // Vide n'est PAS zéro : c'est « on ne sait pas », et le serveur
        // accepte l'absence.
        if (raw.isEmpty) {
          return null;
        }
        final grams = int.tryParse(raw);
        if (grams == null || grams < 0 || grams > maxGrams) {
          return 'Entre 0 et ${maxGrams ~/ 1000} 000.';
        }
        return null;
      },
      onFieldSubmitted: valider == null ? null : (_) => valider(),
    );
  }
}

/// La quantité mangée : un nombre et l'unité dans laquelle il se dit.
///
/// DESCRIPTIVE et non multiplicatrice — les calories saisies restent celles
/// du repas entier. Le libellé le dit à l'écran, parce que « 250 g » à côté
/// de « 350 kcal » se lit sinon comme « 350 kcal pour 100 g ».
class MealQuantityField extends StatelessWidget {
  const MealQuantityField({
    required this.controller,
    required this.unit,
    required this.onUnit,
    super.key,
  });

  final TextEditingController controller;
  final MealQuantityUnit unit;
  final ValueChanged<MealQuantityUnit> onUnit;

  /// Borne de la colonne (`Decimal(7, 2)`) : au-delà, le serveur refuse.
  static const double maxQuantity = 9999.99;

  /// La virgule est la séparatrice décimale française : l'accepter évite un
  /// refus incompréhensible sur un clavier numérique français.
  static double? parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.'));

  static String? validate(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }
    final quantity = parse(raw);
    if (quantity == null || quantity <= 0 || quantity > maxQuantity) {
      return 'Entre 0,01 et 9 999.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          label: 'Quantité',
          controller: controller,
          hint: 'facultatif : 250, 1,5…',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          validator: validate,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final value in MealQuantityUnit.values)
              AppPill(
                label: value.pick,
                selected: value == unit,
                // VIOLET : l'accent orange est réservé aux filtres de la
                // bibliothèque d'exercices.
                selectedTone: AppPillTone.primary,
                onTap: () => onUnit(value),
              ),
          ],
        ),
      ],
    );
  }
}
