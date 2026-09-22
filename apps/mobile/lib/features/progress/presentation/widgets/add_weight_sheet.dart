import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Ce qu'une saisie de poids rapporte : une valeur ET sa date.
///
/// La date n'était pas demandée jusqu'ici — toute mesure était datée de
/// l'instant. On ne pouvait donc ni rattraper un oubli de la veille, ni
/// corriger une pesée mal datée, alors que c'est la date qui décide quelle
/// mesure fait foi pour le rapport métabolique.
@immutable
class BodyWeightInput {
  const BodyWeightInput({required this.valueKg, required this.measuredAt});

  final double valueKg;
  final DateTime measuredAt;
}

/// Feuille de saisie du poids corporel.
///
/// [initialKg] pré-remplit la valeur. [metricId] non nul bascule en mode
/// CORRECTION : le titre, le bouton et l'avertissement changent, car corriger
/// une mesure déjà enregistrée déplace les objectifs nutritionnels.
Future<BodyWeightInput?> showAddWeightSheet(
  BuildContext context, {
  double? initialKg,
  DateTime? initialDate,
  bool correction = false,
}) {
  return showAppSheet<BodyWeightInput>(
    context,
    builder: (_) => _AddWeightForm(
      initialKg: initialKg,
      initialDate: initialDate,
      correction: correction,
    ),
  );
}

class _AddWeightForm extends StatefulWidget {
  const _AddWeightForm({
    this.initialKg,
    this.initialDate,
    required this.correction,
  });

  final double? initialKg;
  final DateTime? initialDate;
  final bool correction;

  @override
  State<_AddWeightForm> createState() => _AddWeightFormState();
}

class _AddWeightFormState extends State<_AddWeightForm> {
  /// Bornes alignées sur celles que l'API applique (1 à 500) mais resserrées
  /// sur le plausible : au-delà, c'est une faute de frappe, pas une pesée.
  static const double _min = 30;
  static const double _max = 400;
  static const double _step = 0.5;

  late double _weightKg = (widget.initialKg ?? 70).clamp(_min, _max).toDouble();
  late DateTime _measuredAt = widget.initialDate ?? DateTime.now();
  late final TextEditingController _champ = TextEditingController(
    text: _formatted,
  );
  String? _erreur;

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  String get _formatted => _weightKg == _weightKg.roundToDouble()
      ? _weightKg.toStringAsFixed(0)
      : _weightKg.toStringAsFixed(1);

  /// Les flèches gardent leur rôle — l'ajustement fin sans clavier — mais
  /// elles écrivent désormais dans le champ, qui reste la source de vérité.
  void _pas(double delta) {
    final suivant = (_weightKg + delta).clamp(_min, _max).toDouble();
    setState(() {
      _weightKg = suivant;
      _erreur = null;
      _champ.text = _formatted;
    });
  }

  void _saisie(String texte) {
    // La virgule est la séparatrice décimale française : l'accepter évite un
    // refus incompréhensible sur un clavier numérique français.
    final valeur = double.tryParse(texte.trim().replaceAll(',', '.'));
    setState(() {
      if (valeur == null) {
        _erreur = texte.trim().isEmpty
            ? null
            : 'Entre un nombre, par exemple 72,4.';
      } else if (valeur < _min || valeur > _max) {
        _erreur = 'Entre $_min et $_max kg.';
      } else {
        _erreur = null;
        _weightKg = valeur;
      }
    });
  }

  Future<void> _choisirLaDate() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: _measuredAt,
      // Deux ans en arrière : de quoi rattraper un historique, sans ouvrir un
      // calendrier infini. Aucune date future — on ne se pèse pas demain.
      firstDate: DateTime(maintenant.year - 2),
      lastDate: maintenant,
      helpText: 'Date de la pesée',
    );
    if (choisie != null) {
      setState(() => _measuredAt = choisie);
    }
  }

  String get _dateLisible {
    final aujourdHui = DateTime.now();
    final memeJour =
        _measuredAt.year == aujourdHui.year &&
        _measuredAt.month == aujourdHui.month &&
        _measuredAt.day == aujourdHui.day;
    if (memeJour) return 'Aujourd’hui';
    final j = _measuredAt.day.toString().padLeft(2, '0');
    final m = _measuredAt.month.toString().padLeft(2, '0');
    return '$j/$m/${_measuredAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valide = _erreur == null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.correction ? 'Corriger cette pesée' : 'Mon poids',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: _weightKg - _step >= _min
                      ? () => _pas(-_step)
                      : null,
                  tooltip: 'Diminuer le poids',
                  icon: const Icon(AppIcons.minus),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppTextField(
                    label: 'Poids (kg)',
                    controller: _champ,
                    errorText: _erreur,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autocorrect: false,
                    onChanged: _saisie,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.filledTonal(
                  onPressed: _weightKg + _step <= _max
                      ? () => _pas(_step)
                      : null,
                  tooltip: 'Augmenter le poids',
                  icon: const Icon(AppIcons.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppListRow(
              title: 'Date de la pesée',
              trailingText: _dateLisible,
              leading: AppIcons.date,
              onTap: _choisirLaDate,
            ),
            if (widget.correction) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ton poids le plus récent sert à calculer tes besoins '
                'caloriques : cette correction peut les faire bouger.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: widget.correction ? 'Corriger' : 'Enregistrer',
              isExpanded: true,
              onPressed: valide
                  ? () => Navigator.of(context).pop(
                      BodyWeightInput(
                        valueKg: _weightKg,
                        measuredAt: _measuredAt,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
