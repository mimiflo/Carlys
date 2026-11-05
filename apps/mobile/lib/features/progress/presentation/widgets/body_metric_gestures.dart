import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/progress.dart';
import '../providers/progress_providers.dart';
import 'add_measurement_sheet.dart';
import 'add_weight_sheet.dart';

/// Ouvre la feuille d'ajout du poids et enregistre la mesure.
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
        .add(
          BodyMetricKind.weightKg,
          saisie.valueKg,
          measuredAt: saisie.measuredAt,
        ),
    echec: 'Impossible d’enregistrer la mesure.',
  );
}

/// Ouvre la feuille des mensurations et enregistre le tour saisi.
///
/// [initialKind] présélectionne la zone et [initialValue] pré-remplit le
/// tour : depuis l'historique d'une zone, on ajoute à CETTE zone, à partir
/// de sa dernière valeur — comme la pesée part de la dernière pesée.
Future<void> addBodyMeasurement(
  BuildContext context,
  WidgetRef ref, {
  BodyMetricKind? initialKind,
  double? initialValue,
}) async {
  final saisie = await showAddMeasurementSheet(
    context,
    initialKind: initialKind,
    initialValue: initialValue,
  );
  if (saisie == null || !context.mounted) {
    return;
  }
  await _tenter(
    context,
    () => ref
        .read(bodyMetricActionsProvider)
        .add(saisie.kind, saisie.value, measuredAt: saisie.measuredAt),
    echec: 'Impossible d’enregistrer la mensuration.',
  );
}

/// Ouvre la feuille de SON type en mode correction, sur une mesure
/// existante : la feuille du poids pour une pesée, celle des mensurations
/// pour un tour — zone verrouillée, un tour de bras ne devient pas un tour
/// de cou.
///
/// Même geste, même validation, même message d'échec que l'ajout :
/// corriger n'est pas un formulaire à part, c'est le même formulaire
/// pré-rempli.
Future<void> correctBodyMetric(
  BuildContext context,
  WidgetRef ref,
  BodyMetricEntry entry,
) async {
  final ({double value, DateTime measuredAt})? saisie;
  if (entry.kind.isMeasurement) {
    final mesure = await showAddMeasurementSheet(
      context,
      initialKind: entry.kind,
      initialValue: entry.value,
      initialDate: entry.measuredAt.toLocal(),
      correction: true,
    );
    saisie = mesure == null
        ? null
        : (value: mesure.value, measuredAt: mesure.measuredAt);
  } else {
    final pesee = await showAddWeightSheet(
      context,
      initialKg: entry.value,
      initialDate: entry.measuredAt.toLocal(),
      correction: true,
    );
    saisie = pesee == null
        ? null
        : (value: pesee.valueKg, measuredAt: pesee.measuredAt);
  }
  if (saisie == null || !context.mounted) {
    return;
  }
  final (:value, :measuredAt) = saisie;
  await _tenter(
    context,
    () => ref
        .read(bodyMetricActionsProvider)
        .correct(entry, value: value, measuredAt: measuredAt),
    echec: 'Impossible de corriger la mesure.',
  );
}

/// Un échec réseau ne doit jamais disparaître en silence : il se dit, une
/// fois, au même endroit pour tous les gestes.
Future<void> _tenter(
  BuildContext context,
  Future<void> Function() action, {
  required String echec,
}) async {
  try {
    await action();
  } on Exception {
    if (context.mounted) {
      AppNotices.of(context).show(echec, tone: AppNoticeTone.error);
    }
  }
}
