import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/domain/repositories/progress_repository.dart';
import '../health_data_source.dart';

/// **Importer les pesées de la balance** comme mesures corporelles.
///
/// Elles empruntent le chemin d'une saisie à la main
/// (`ProgressRepository.addBodyMetric`, `POST /body-metrics`) : mêmes bornes,
/// même création idempotente par identifiant, même suppression.
///
/// Les garanties, chacune tenue par un test (`import_health_weighings_test`) :
///  - **jamais deux fois** : l'identifiant de la mesure DÉRIVE de la pesée
///    ([weighingMetricId]) ; la rejouer, depuis ce téléphone réinstallé ou
///    depuis un autre, retombe sur la même ligne ;
///  - **une pesée supprimée ne revient pas** : la suppression est LOGIQUE
///    côté serveur, la ligne reste, et recréer son identifiant ne la
///    ressuscite pas (test e2e « supprime une mesure ») — sur tous les
///    appareils, sans liste locale à tenir ;
///  - **bornes** : une valeur qu'aucune balance ne rend ([plausibleWeighing])
///    est écartée, jamais envoyée ;
///  - **rien de Carlys** : une mesure écrite par une application Carlys est
///    ignorée (Carlys n'écrit rien aujourd'hui, la règle tient pour demain) ;
///  - **depuis le dernier import**, avec un recouvrement : une balance
///    synchronise souvent APRÈS coup, sous l'heure de la pesée.
///
/// Ce qu'il NE fait PAS : reprendre une pesée corrigée, ou réattribuée à une
/// autre personne, dans l'application de la balance. Elle garde son heure,
/// donc son identifiant, et le serveur rend la ligne déjà là sans la toucher.
/// La personne la corrige ou la supprime dans Carlys (`sante-connectee.md`,
/// « Cas limites »). Pas de correction automatique : elle écraserait aussi
/// une correction faite à la main dans Carlys.
class ImportHealthWeighings {
  const ImportHealthWeighings({
    required this._source,
    required this._metrics,
    required this._ledger,
  });

  final HealthDataSource _source;
  final ProgressRepository _metrics;
  final HealthImportLedger _ledger;

  /// Premier import : Health Connect ne sert de toute façon que les 30 jours
  /// qui précèdent l'autorisation, sans la permission d'historique.
  static const Duration firstWindow = Duration(days: 30);

  /// Relu à chaque import : une pesée de 7 h synchronisée à 9 h par
  /// l'application de la balance arrive datée de 7 h — et une balance restée
  /// hors réseau un week-end livre ses pesées le lundi. Sept jours : relire
  /// ne coûte rien (même identifiant, aucune ligne créée).
  static const Duration overlap = Duration(days: 7);

  /// Ouvrir Progrès trois fois en dix minutes n'importe qu'une fois.
  static const Duration minInterval = Duration(minutes: 15);

  static const _log = AppLogger('ImportHealthWeighings');

  /// Rend les mesures que le serveur a renvoyées — créées OU déjà là : le
  /// rejeu est idempotent et répond pareil. Hors ligne, l'erreur remonte et
  /// le curseur ne bouge pas : le prochain import reprend au même endroit.
  Future<List<BodyMetricEntry>> call({
    required String userId,
    required DateTime now,
  }) async {
    final last = await _ledger.lastImportAt(userId);
    if (last != null && now.difference(last) < minInterval) {
      return const [];
    }
    final since = last == null
        ? now.subtract(firstWindow)
        : last.subtract(overlap);
    final weighings = await _source.weighingsBetween(since, now);

    final stored = <BodyMetricEntry>[];
    for (final weighing in weighings) {
      final value = plausibleWeighing(weighing);
      if (value == null ||
          isWrittenByCarlys(weighing.sourceApp) ||
          weighing.measuredAt.isAfter(now)) {
        continue;
      }
      try {
        stored.add(
          await _metrics.addBodyMetric(
            id: weighingMetricId(userId, weighing),
            kind: weighing.kind,
            value: value,
            measuredAt: weighing.measuredAt,
          ),
        );
      } on ValidationException catch (error) {
        // Refusée par le serveur (et pas par le réseau) : la renvoyer ne
        // changerait rien, et bloquer le curseur sur elle bloquerait toutes
        // les suivantes.
        _log.warning('pesée écartée par le serveur', error: error);
      }
    }
    await _ledger.markImported(userId, now);
    return stored;
  }
}

/// L'espace de noms des identifiants d'import — FIXE : le changer ferait
/// réimporter, sous de nouveaux identifiants, toutes les pesées déjà là.
const String healthWeighingNamespace = '5d29b8e9-c611-4505-8f1d-9d5517250899';

/// L'identifiant (UUID v5) de la mesure Carlys née d'une pesée.
///
/// Il dérive de la pesée elle-même — son compte, son type, sa SECONDE de
/// mesure — et non de l'identifiant de l'enregistrement source : Health
/// Connect numérote ses enregistrements PAR TÉLÉPHONE, si bien que la même
/// pesée, écrite par l'application de la balance sur deux téléphones, y
/// porte deux identifiants. Deux pesées distinctes d'une même personne à la
/// même seconde n'existent pas ; un même enregistrement relu, si.
///
/// Recalculable par quiconque connaît le compte et l'heure : ce n'est PAS un
/// secret. Le serveur le range donc dans l'espace du compte
/// (`storedBodyMetricId` : `uuidv5(userId, id)`), si bien qu'un autre compte
/// ne peut ni réserver cette pesée ni sonder ses heures. L'identifiant
/// STOCKÉ — celui que la réponse, la correction et la suppression portent —
/// diffère donc de celui-ci, et reste un v5.
///
/// Une mesure saisie à la main est un UUID v4 : la version suffit donc à
/// reconnaître une mesure importée ([BodyMetricEntry.imported]).
String weighingMetricId(String userId, HealthWeighing weighing) {
  final second = weighing.measuredAt.toUtc().millisecondsSinceEpoch ~/ 1000;
  return const Uuid().v5(
    healthWeighingNamespace,
    '$userId|${weighing.kind.apiValue}|$second',
  );
}

/// Les plages qu'une balance grand public peut rendre, plus serrées que les
/// bornes de l'API (`BodyMetricKind.min/max`, faites pour ne jamais refuser
/// une saisie vraie) : un 0 kg d'une balance qu'on a frôlée, ou un taux de
/// masse grasse lu en fraction, n'entrent pas dans les mesures.
const Map<BodyMetricKind, ({double min, double max})> plausibleWeighingRange = {
  BodyMetricKind.weightKg: (min: 20, max: 350),
  BodyMetricKind.bodyFatPercent: (min: 2, max: 75),
};

/// La valeur arrondie à la précision de l'API, ou `null` si la pesée est
/// hors plage (ou d'un type que l'import ne connaît pas).
double? plausibleWeighing(HealthWeighing weighing) {
  final range = plausibleWeighingRange[weighing.kind];
  final value = weighing.value;
  if (range == null || !value.isFinite) return null;
  if (value < range.min || value > range.max) return null;
  final factor = math.pow(10, weighing.kind.decimals);
  return (value * factor).round() / factor;
}

/// Une application Carlys (Android `com.carlys.carlys_mobile`, iOS
/// `com.carlys.carlysMobile`, et leurs variantes).
bool isWrittenByCarlys(String sourceApp) => sourceApp.startsWith('com.carlys.');
