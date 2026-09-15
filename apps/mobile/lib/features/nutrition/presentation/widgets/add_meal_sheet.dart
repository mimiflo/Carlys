import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Ce que la feuille d'ajout rend : un repas nommé et chiffré.
class MealDraft {
  const MealDraft({
    required this.name,
    required this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  final String name;
  final int kcal;

  /// Les trois macros, toutes facultatives et INDÉPENDANTES : on peut ne
  /// connaître que les protéines d'un plat, et `null` veut alors dire « on
  /// ne sait pas », pas « zéro ».
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
}

/// Feuille « Ajouter un repas » : nom, calories, et les trois macros, toutes
/// facultatives. Rend `null` si la personne renonce.
///
/// L'écran affiche quatre macros CIBLES et n'en journalisait que deux : sur
/// les deux tiers de ce qu'il montrait, la comparaison consommé / objectif
/// n'était pas possible.
Future<MealDraft?> showAddMealSheet(BuildContext context) {
  return showAppSheet<MealDraft>(context, builder: (_) => const _AddMealForm());
}

class _AddMealForm extends StatefulWidget {
  const _AddMealForm();

  @override
  State<_AddMealForm> createState() => _AddMealFormState();
}

class _AddMealFormState extends State<_AddMealForm> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(
      MealDraft(
        name: _name.text.trim(),
        kcal: int.parse(_kcal.text.trim()),
        proteinG: int.tryParse(_protein.text.trim()),
        carbsG: int.tryParse(_carbs.text.trim()),
        fatG: int.tryParse(_fat.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajouter un repas',
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Repas',
              controller: _name,
              hint: 'Poulet, riz, brocoli…',
              textInputAction: TextInputAction.next,
              maxLength: 120,
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Nomme ton repas.' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Calories (kcal)',
                    controller: _kcal,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final kcal = int.tryParse(value?.trim() ?? '');
                      if (kcal == null || kcal < 1 || kcal > 10000) {
                        return 'Entre 1 et 10 000.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MacroField(
                    label: 'Protéines (g)',
                    controller: _protein,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MacroField(label: 'Glucides (g)', controller: _carbs),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MacroField(
                    label: 'Lipides (g)',
                    controller: _fat,
                    onSubmitted: _submit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(label: 'Ajouter au journal', onPressed: _submit),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

/// Un champ de macro : même libellé facultatif, mêmes bornes, même message.
///
/// Extrait parce qu'il y en a TROIS : recopier le validateur trois fois, ce
/// serait trois endroits où corriger une borne, et deux occasions d'oublier.
class _MacroField extends StatelessWidget {
  const _MacroField({
    required this.label,
    required this.controller,
    this.onSubmitted,
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
