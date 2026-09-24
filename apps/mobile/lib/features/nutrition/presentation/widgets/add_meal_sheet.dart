import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/meal_entry.dart';
import 'meal_draft.dart';
import 'meal_form_fields.dart';
import 'meal_moment_rows.dart';

/// Feuille du journal alimentaire, dans ses DEUX usages.
///
/// [existing] nul : on ajoute un repas, daté de [day] (le jour affiché par le
/// journal) à l'heure courante. [existing] non nul : on CORRIGE — le
/// formulaire s'ouvre rempli, et ce que la personne y laisse fait foi, y
/// compris les cases qu'elle vide.
///
/// Un seul formulaire pour les deux, parce que ce sont les mêmes champs, les
/// mêmes bornes et les mêmes pièges : deux copies, ce serait deux endroits
/// où corriger la borne des calories.
Future<MealDraft?> showMealSheet(
  BuildContext context, {
  MealEntry? existing,
  DateTime? day,
}) {
  return showAppSheet<MealDraft>(
    context,
    builder: (_) => _MealForm(existing: existing, day: day),
  );
}

class _MealForm extends StatefulWidget {
  const _MealForm({this.existing, this.day});

  final MealEntry? existing;
  final DateTime? day;

  @override
  State<_MealForm> createState() => _MealFormState();
}

class _MealFormState extends State<_MealForm> {
  late final MealEntry? _existing = widget.existing;
  late final _name = TextEditingController(text: _existing?.name ?? '');
  late final _kcal = TextEditingController(
    text: _existing == null ? '' : '${_existing.kcal}',
  );
  late final _quantity = TextEditingController(
    text: _quantiteInitiale(_existing?.quantity),
  );
  late final _protein = TextEditingController(
    text: _grammes(_existing?.proteinG),
  );
  late final _carbs = TextEditingController(text: _grammes(_existing?.carbsG));
  late final _fat = TextEditingController(text: _grammes(_existing?.fatG));
  final _formKey = GlobalKey<FormState>();

  late MealQuantityUnit _unit =
      _existing?.quantityUnit ?? MealQuantityUnit.gram;

  /// L'heure LOCALE : le serveur stocke en UTC, l'écran montre l'heure du
  /// poignet. Un repas ajouté sur le jour affiché par le journal en hérite —
  /// consulter mardi puis ajouter, c'est ajouter À MARDI.
  late DateTime _eatenAt = _instantInitial();

  static String _grammes(int? value) => value == null ? '' : '$value';

  /// Une quantité entière s'écrit sans décimale, et la virgule est la
  /// séparatrice française : « 1,5 », jamais « 1.50 ».
  static String _quantiteInitiale(double? value) {
    if (value == null) {
      return '';
    }
    return value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(2).replaceAll('.', ',');
  }

  DateTime _instantInitial() {
    final existing = _existing;
    if (existing != null) {
      return existing.eatenAt.toLocal();
    }
    final now = DateTime.now();
    final jour = widget.day;
    if (jour == null || _memeJour(jour, now)) {
      return now;
    }
    // Un jour passé : midi, l'heure la plus plausible d'un repas qu'on
    // rattrape, et jamais dans le futur.
    return DateTime(jour.year, jour.month, jour.day, 12);
  }

  static bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _correction => _existing != null;

  @override
  void dispose() {
    _name.dispose();
    _kcal.dispose();
    _quantity.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    // Le serveur refuse un repas daté du futur ; l'écran le dit AVANT
    // l'aller-retour, faute de quoi le refus arriverait sous forme d'un
    // « Enregistrement impossible » qui ne nomme pas la cause.
    if (_eatenAt.isAfter(DateTime.now())) {
      AppNotices.of(context).show(
        'On ne mange pas demain : choisis un moment passé.',
        tone: AppNoticeTone.error,
      );
      return;
    }
    final quantity = MealQuantityField.parse(_quantity.text);
    Navigator.of(context).pop(
      MealDraft(
        name: _name.text.trim(),
        kcal: int.parse(_kcal.text.trim()),
        eatenAt: _eatenAt,
        // La paire est indivisible : sans nombre, l'unité ne part pas.
        quantity: quantity,
        quantityUnit: quantity == null ? null : _unit,
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
      // DÉFILANTE : le formulaire porte désormais la quantité, son unité, le
      // jour et l'heure — il dépasse la hauteur d'un petit écran, et une
      // colonne nue y aurait simplement CACHÉ son bouton de validation
      // (débordement de 110 px, mesuré). La feuille reste à la taille de son
      // contenu tant qu'il tient, et défile au-delà.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _correction ? 'Corriger ce repas' : 'Ajouter un repas',
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
                  child: MealMacroField(
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
                  child: MealMacroField(
                    label: 'Glucides (g)',
                    controller: _carbs,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: MealMacroField(label: 'Lipides (g)', controller: _fat),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            MealQuantityField(
              controller: _quantity,
              unit: _unit,
              onUnit: (unit) => setState(() => _unit = unit),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'La quantité décrit ton assiette : elle ne multiplie pas les '
              'calories saisies, qui restent celles du repas entier.',
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            MealMomentRows(
              eatenAt: _eatenAt,
              onChanged: (moment) => setState(() => _eatenAt = moment),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: _correction
                    ? 'Enregistrer la correction'
                    : 'Ajouter au journal',
                onPressed: _submit,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
