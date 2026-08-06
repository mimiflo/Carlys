import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flavors de l'application, alignés sur les environnements serveur.
enum AppFlavor { development, staging, production }

/// Configuration d'exécution injectée au lancement via --dart-define :
///   flutter run \
///     --dart-define=CARLYS_FLAVOR=development \
///     --dart-define=CARLYS_API_BASE_URL=http://localhost:3000
class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.apiBaseUrl,
  });

  factory AppEnvironment.fromDartDefine() {
    const flavorName = String.fromEnvironment(
      'CARLYS_FLAVOR',
      defaultValue: 'development',
    );
    const apiBaseUrl = String.fromEnvironment(
      'CARLYS_API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    );

    final flavor = AppFlavor.values.firstWhere(
      (value) => value.name == flavorName,
      orElse: () => AppFlavor.development,
    );

    return AppEnvironment(flavor: flavor, apiBaseUrl: apiBaseUrl);
  }

  final AppFlavor flavor;

  /// Base de l'API sans préfixe de version (ex. http://localhost:3000).
  final String apiBaseUrl;

  bool get isDevelopment => flavor == AppFlavor.development;
  bool get isProduction => flavor == AppFlavor.production;

  /// Préfixe complet des routes métier.
  String get apiV1Url => '$apiBaseUrl/api/v1';
}

/// Renseigné au bootstrap via `overrideWithValue` — jamais utilisé sans override.
final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw UnimplementedError(
    'appEnvironmentProvider doit être surchargé dans bootstrap()',
  ),
);
