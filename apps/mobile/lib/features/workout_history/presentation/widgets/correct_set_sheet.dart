import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../workout_session/domain/entities/workout.dart';

/// Ce que la feuille de correction rend : la série telle qu'elle aurait dû
/// être saisie. `null` sur les deux champs veut dire « rien n'a changé ».
class SetCorrection {
  const SetCorrection({this.reps, this.weightKg});

  final int? reps;
  final double? weightKg;

  bool get isEmpty => reps == null && weightKg == null;
}

/// Bornes du contrat serveur, en un seul endroit.
///
/// Elles ne sont pas décoratives : c'est un 200 saisi au lieu d'un 20 qui
/// pose le record faux que cette feuille existe pour réparer. Les refuser
/// n'est PAS la réponse — une charge de 200 kg est légitime pour quelqu'un —
/// mais laisser passer 2000 ne l'est pas.
const int _repsMax = 1000;
const double _weightMax = 1000;

/// Feuille « Corriger la série ». Rend `null` si la personne renonce.
///
/// POURQUOI ELLE EXISTE. Une séance terminée était définitivement figée :
/// aucun écran n'offrait de corriger une série ni d'en supprimer une, la
/// suppression n'existant que PENDANT la séance. Or les records se
/// recalculent à partir de ces séries : une charge saisie 100 au lieu de 10
/// posait un record faux, définitif, qui polluait aussi les statistiques et
/// la courbe par exercice. Le serveur savait corriger — `PATCH
/// /workout-sets/{id}` était livré, validé et testé — mais aucun client ne
/// l'appelait.
///
/// L'incohérence sautait aux yeux depuis que les mesures corporelles sont
/// redevenues corrigeables : une PESÉE se corrigeait, une SÉRIE non.
Future<SetCorrection?> showCorrectSetSheet(
  BuildContext context,
  WorkoutSetEntry set,
) {
  return showAppSheet<SetCorrection>(
    context,
    builder: (_) => _CorrectSetForm(set: set),
  );
}

class _CorrectSetForm extends StatefulWidget {
  const _CorrectSetForm({required this.set});

  final WorkoutSetEntry set;

  @override
  State<_CorrectSetForm> createState() => _CorrectSetFormState();
}

class _CorrectSetFormState extends State<_CorrectSetForm> {
  late final TextEditingController _reps = TextEditingController(
    text: widget.set.reps?.toString() ?? '',
  );
  late final TextEditingController _weight = TextEditingController(
    text: widget.set.weightKg == null
        ? ''
        : formatDecimal(widget.set.weightKg!),
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _reps.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Ne renvoie QUE ce qui a bougé : un champ inchangé ne part pas au
  /// serveur, et deux champs inchangés ferment la feuille sans rien écrire.
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final reps = int.tryParse(_reps.text.trim());
    final poids = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    final correction = SetCorrection(
      reps: reps == widget.set.reps ? null : reps,
      weightKg: poids == widget.set.weightKg ? null : poids,
    );
    Navigator.of(context).pop(correction.isEmpty ? null : correction);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Corriger la série', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(widget.set.exerciseName, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _NombreField(
                  label: 'Répétitions',
                  controller: _reps,
                  max: _repsMax,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _NombreField(
                  label: 'Charge (kg)',
                  controller: _weight,
                  max: _weightMax,
                  decimal: true,
                  onSubmitted: _submit,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // La conséquence, dite avant le geste : c'est la raison d'être de
          // la correction, et personne ne devine qu'un record peut descendre.
          Text(
            'Tes records et tes statistiques seront recalculés sur la valeur '
            'corrigée. Un record que cette série portait à tort redescendra.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(label: 'Corriger', onPressed: _submit),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// Un champ numérique borné. Vide n'est PAS zéro : c'est « on ne note pas
/// cette grandeur », et le serveur accepte l'absence.
class _NombreField extends StatelessWidget {
  const _NombreField({
    required this.label,
    required this.controller,
    required this.max,
    this.decimal = false,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final num max;
  final bool decimal;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final valider = onSubmitted;

    return AppTextField(
      label: label,
      controller: controller,
      hint: 'facultatif',
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: valider == null
          ? TextInputAction.next
          : TextInputAction.done,
      validator: (value) {
        final raw = value?.trim().replaceAll(',', '.') ?? '';
        if (raw.isEmpty) {
          return null;
        }
        final nombre = decimal ? double.tryParse(raw) : int.tryParse(raw);
        if (nombre == null || nombre <= 0 || nombre > max) {
          return 'Entre 1 et ${formatThousands(max.round())}.';
        }
        return null;
      },
      onFieldSubmitted: valider == null ? null : (_) => valider(),
    );
  }
}
