import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Feuille de saisie du poids corporel (pas de 0,5 kg).
Future<double?> showAddWeightSheet(BuildContext context, {double? initialKg}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _AddWeightForm(initialKg: initialKg),
    ),
  );
}

class _AddWeightForm extends StatefulWidget {
  const _AddWeightForm({this.initialKg});

  final double? initialKg;

  @override
  State<_AddWeightForm> createState() => _AddWeightFormState();
}

class _AddWeightFormState extends State<_AddWeightForm> {
  static const double _min = 30;
  static const double _max = 400;
  static const double _step = 0.5;

  late double _weightKg = (widget.initialKg ?? 70).clamp(_min, _max).toDouble();

  String get _formatted => _weightKg == _weightKg.roundToDouble()
      ? _weightKg.toStringAsFixed(0)
      : _weightKg.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mon poids du jour', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: _weightKg - _step >= _min
                      ? () => setState(() => _weightKg -= _step)
                      : null,
                  tooltip: 'Diminuer le poids',
                  icon: const Icon(Icons.remove),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    '$_formatted kg',
                    textAlign: TextAlign.center,
                    style: AppTypography.metric.copyWith(
                      fontSize: 32,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: _weightKg + _step <= _max
                      ? () => setState(() => _weightKg += _step)
                      : null,
                  tooltip: 'Augmenter le poids',
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Enregistrer',
              isExpanded: true,
              onPressed: () => Navigator.of(context).pop(_weightKg),
            ),
          ],
        ),
      ),
    );
  }
}
