import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/progress_controllers.dart';
import 'add_weight_sheet.dart';

/// Ouvre la feuille d'ajout et enregistre la mesure.
///
/// Le geste est le MÊME depuis la section poids et depuis l'amorçage du
/// premier jour : une seule façon de noter son poids, un seul message
/// d'échec.
Future<void> addBodyWeight(
  BuildContext context,
  WidgetRef ref, {
  double? initialKg,
}) async {
  final valueKg = await showAddWeightSheet(context, initialKg: initialKg);
  if (valueKg == null) {
    return;
  }
  try {
    await ref.read(bodyMetricActionsProvider).addWeight(valueKg);
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’enregistrer la mesure.')),
      );
    }
  }
}
