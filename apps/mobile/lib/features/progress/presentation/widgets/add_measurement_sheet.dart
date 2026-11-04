import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import 'measured_on_row.dart';

/// Ce qu'une saisie de mensuration rapporte : la zone, le tour, sa date.
@immutable
class BodyMeasurementInput {
  const BodyMeasurementInput({
    required this.kind,
    required this.value,
    required this.measuredAt,
  });

  final BodyMetricKind kind;

  /// En cm, à une décimale.
  final double value;
  final DateTime measuredAt;
}

/// Feuille de saisie d'une mensuration : la zone, le tour en cm, la date
/// (aujourd'hui par défaut).
///
/// [correction] VERROUILLE la zone — le type d'une mesure ne se corrige pas,
/// l'API refuse le champ — et change le titre et le bouton.
Future<BodyMeasurementInput?> showAddMeasurementSheet(
  BuildContext context, {
  BodyMetricKind? initialKind,
  double? initialValue,
  DateTime? initialDate,
  bool correction = false,
}) {
  return showAppSheet<BodyMeasurementInput>(
    context,
    builder: (_) => _AddMeasurementForm(
      initialKind: initialKind ?? BodyMetricKind.measurements.first,
      initialValue: initialValue,
      initialDate: initialDate,
      correction: correction,
    ),
  );
}

class _AddMeasurementForm extends StatefulWidget {
  const _AddMeasurementForm({
    required this.initialKind,
    required this.initialValue,
    required this.initialDate,
    required this.correction,
  });

  final BodyMetricKind initialKind;
  final double? initialValue;
  final DateTime? initialDate;
  final bool correction;

  @override
  State<_AddMeasurementForm> createState() => _AddMeasurementFormState();
}

class _AddMeasurementFormState extends State<_AddMeasurementForm> {
  late BodyMetricKind _kind = widget.initialKind;
  late DateTime _measuredAt = widget.initialDate ?? DateTime.now();
  late final TextEditingController _champ = TextEditingController(
    text: widget.initialValue == null
        ? ''
        : formatDecimalInput(widget.initialValue!, decimals: 1),
  );

  @override
  void dispose() {
    _champ.dispose();
    super.dispose();
  }

  double? get _value => parseDecimalInput(_champ.text);

  /// Le refus, ou `null` : les bornes de la ZONE choisie — 150 cm est un
  /// tour de taille possible, pas un tour de bras —, et une décimale, ce
  /// que lit un mètre ruban et ce que l'API accepte.
  String? get _erreur {
    final valeur = _value;
    if (_champ.text.trim().isEmpty) {
      return null;
    }
    if (valeur == null) {
      return 'Entre un nombre, par exemple 82,5.';
    }
    if (valeur < _kind.min || valeur > _kind.max) {
      return 'Entre ${formatDecimal(_kind.min)} et '
          '${formatDecimal(_kind.max)} cm.';
    }
    final dixiemes = valeur * 10;
    if ((dixiemes - dixiemes.round()).abs() > 1e-6) {
      return 'Une décimale au plus, par exemple 82,5.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final erreur = _erreur;
    final valeur = _value;
    final valide = erreur == null && valeur != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.correction ? 'Corriger cette mesure' : 'Mensuration',
              style: AppTypography.subheading.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const AppSectionLabel('Zone'),
            const SizedBox(height: AppSpacing.xs),
            AppChoicePills<BodyMetricKind>(
              choices: [
                for (final kind in BodyMetricKind.measurements)
                  AppChoice(kind, kind.label),
              ],
              selected: _kind,
              onSelected: widget.correction
                  ? null
                  : (kind) => setState(() => _kind = kind),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: '${_kind.label} (cm)',
              controller: _champ,
              errorText: erreur,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autocorrect: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.sm),
            MeasuredOnRow(
              title: 'Date de la mesure',
              value: _measuredAt,
              onChanged: (date) => setState(() => _measuredAt = date),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: widget.correction ? 'Corriger' : 'Enregistrer',
              isExpanded: true,
              onPressed: valide
                  ? () => Navigator.of(context).pop(
                      BodyMeasurementInput(
                        kind: _kind,
                        value: valeur,
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
