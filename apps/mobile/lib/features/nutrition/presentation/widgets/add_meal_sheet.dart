import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Ce que la feuille d'ajout rend : un repas nommé et chiffré.
class MealDraft {
  const MealDraft({required this.name, required this.kcal, this.proteinG});

  final String name;
  final int kcal;
  final int? proteinG;
}

/// Feuille « Ajouter un repas » : nom, calories, protéines (facultatif).
/// Rend `null` si la personne renonce.
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
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _protein.dispose();
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
                  child: AppTextField(
                    label: 'Protéines (g)',
                    controller: _protein,
                    hint: 'facultatif',
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      final raw = value?.trim() ?? '';
                      if (raw.isEmpty) {
                        return null;
                      }
                      final grams = int.tryParse(raw);
                      if (grams == null || grams < 0 || grams > 1000) {
                        return 'Entre 0 et 1 000.';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
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
