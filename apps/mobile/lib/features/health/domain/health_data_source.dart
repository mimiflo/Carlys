import '../../progress/domain/entities/progress.dart';

/// Ce que ce téléphone permet de la santé connectée.
enum HealthAvailability {
  /// Health Connect (Android) ou Apple Santé (iOS) répond.
  available,

  /// Android 9 à 13 sans l'application Health Connect : elle s'installe
  /// depuis le Play Store.
  needsInstall,

  /// Rien à faire sur ce téléphone (Android 8 et moins, profil de travail…).
  unsupported,
}

/// Une pesée qu'une balance (ou une autre application) a écrite dans Health
/// Connect ou Apple Santé.
class HealthWeighing {
  const HealthWeighing({
    required this.kind,
    required this.value,
    required this.measuredAt,
    required this.sourceApp,
  });

  /// [BodyMetricKind.weightKg] ou [BodyMetricKind.bodyFatPercent].
  final BodyMetricKind kind;

  /// En kilos, ou en POURCENT (de 0 à 100) : l'adaptateur ramène la fraction
  /// d'Apple Santé (0,25) au pourcentage (25).
  final double value;
  final DateTime measuredAt;

  /// Le paquet (Android) ou l'identifiant (iOS) de l'application qui a écrit
  /// la mesure : « com.withings.wiscale2 ».
  final String sourceApp;
}

/// LE PORT de la santé connectée : Carlys y LIT, et n'y écrit jamais.
///
/// Deux implémentations : `data/health_plugin_data_source.dart` (le greffon
/// `health`) et, dans les tests seulement, `FakeHealthDataSource`. Aucun
/// widget ne l'appelle : contrôleur → cas d'usage → ce port.
abstract interface class HealthDataSource {
  Future<HealthAvailability> availability();

  /// Ouvre la demande de LECTURE des pas, du poids et de la masse grasse.
  ///
  /// `true` si les trois sont accordées. Sur iOS, Apple ne dit jamais si une
  /// lecture est refusée : `true` veut dire « la demande a été montrée », et
  /// un refus se lit ensuite comme une absence de données.
  Future<bool> requestReadAccess();

  /// Les trois lectures sont-elles TOUJOURS accordées ? Sur Android, on peut
  /// les retirer dans Health Connect à tout moment ; sur iOS, toujours `true`
  /// (même silence d'Apple).
  Future<bool> hasReadAccess();

  /// Ouvre la fiche Health Connect du Play Store (Android).
  Future<void> installHealthConnect();

  /// Les pas comptés entre [start] et [end], dédoublonnés par la plateforme
  /// (téléphone + montre ne comptent pas deux fois). `null` si la lecture
  /// échoue.
  Future<int?> stepsBetween(DateTime start, DateTime end);

  /// Les pesées mesurées entre [since] et [until].
  Future<List<HealthWeighing>> weighingsBetween(DateTime since, DateTime until);
}

/// Où l'import des pesées en est, par compte. Implémenté sur l'appareil
/// (`data/health_prefs_store.dart`).
abstract interface class HealthImportLedger {
  Future<DateTime?> lastImportAt(String userId);

  Future<void> markImported(String userId, DateTime at);
}
