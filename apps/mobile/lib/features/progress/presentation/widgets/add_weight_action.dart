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
  final saisie = await showAddWeightSheet(context, initialKg: initialKg);
  // La feuille est une attente : l'écran a pu partir entre-temps.
  if (saisie == null || !context.mounted) {
    return;
  }
  await _tenter(
    context,
    () => ref
        .read(bodyMetricActionsProvider)
        .addWeight(saisie.valueKg, measuredAt: saisie.measuredAt),
    echec: 'Impossible d’enregistrer la mesure.',
  );
}

/// Ouvre la MÊME feuille en mode correction, sur une mesure existante.
///
/// Même geste, même validation, même message d'échec : corriger n'est pas
/// un formulaire à part, c'est le même formulaire pré-rempli.
Future<void> correctBodyWeight(
  BuildContext context,
  WidgetRef ref, {
  required String metricId,
  required double valueKg,
  required DateTime measuredAt,
}) async {
  final saisie = await showAddWeightSheet(
    context,
    initialKg: valueKg,
    initialDate: measuredAt.toLocal(),
    correction: true,
  );
  if (saisie == null || !context.mounted) {
    return;
  }
  await _tenter(
    context,
    () => ref
        .read(bodyMetricActionsProvider)
        .correct(
          metricId,
          valueKg: saisie.valueKg,
          measuredAt: saisie.measuredAt,
        ),
    echec: 'Impossible de corriger la mesure.',
  );
}

/// Un échec réseau ne doit jamais disparaître en silence : il se dit, une
/// fois, au même endroit pour les deux gestes.
Future<void> _tenter(
  BuildContext context,
  Future<void> Function() action, {
  required String echec,
}) async {
  try {
    await action();
  } on Exception {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(echec)));
    }
  }
}
