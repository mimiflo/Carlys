import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flavors de l'application, alignés sur les environnements serveur.
/// `demo` : visite hors ligne sur données intégrées, aucun serveur requis.
enum AppFlavor { development, staging, production, demo }

/// Options du projet Firebase (notifications push), reprises de
/// `google-services.json` et injectées au lancement — voir
/// `config/firebase.example.json`. Valeurs CLIENT, pas des secrets : elles
/// restent néanmoins hors du dépôt, chacun fournit celles de son projet.
class FirebasePushOptions {
  const FirebasePushOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
  });

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
}

/// Configuration d'exécution injectée au lancement via --dart-define :
///   flutter run \
///     --dart-define=CARLYS_FLAVOR=development \
///     --dart-define=CARLYS_API_BASE_URL=http://localhost:3000
class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.apiBaseUrl,
    this.push,
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
    // Notifications push : les quatre valeurs viennent ensemble (fichier
    // --dart-define-from-file) ou pas du tout — jamais à moitié.
    const firebaseApiKey = String.fromEnvironment('CARLYS_FIREBASE_API_KEY');
    const firebaseAppId = String.fromEnvironment('CARLYS_FIREBASE_APP_ID');
    const firebaseSenderId = String.fromEnvironment(
      'CARLYS_FIREBASE_SENDER_ID',
    );
    const firebaseProjectId = String.fromEnvironment(
      'CARLYS_FIREBASE_PROJECT_ID',
    );
    const firebaseConfigured =
        firebaseApiKey != '' &&
        firebaseAppId != '' &&
        firebaseSenderId != '' &&
        firebaseProjectId != '';

    final flavor = AppFlavor.values.firstWhere(
      (value) => value.name == flavorName,
      orElse: () => AppFlavor.development,
    );

    return AppEnvironment(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      push: firebaseConfigured
          ? const FirebasePushOptions(
              apiKey: firebaseApiKey,
              appId: firebaseAppId,
              messagingSenderId: firebaseSenderId,
              projectId: firebaseProjectId,
            )
          : null,
    );
  }

  final AppFlavor flavor;

  /// Base de l'API sans préfixe de version (ex. http://localhost:3000).
  final String apiBaseUrl;

  /// Null tant que la configuration Firebase n'est pas injectée : le push
  /// est alors inactif, le reste de l'application vit normalement.
  final FirebasePushOptions? push;

  bool get isDevelopment => flavor == AppFlavor.development;
  bool get isProduction => flavor == AppFlavor.production;
  bool get isDemo => flavor == AppFlavor.demo;

  /// Préfixe complet des routes métier.
  String get apiV1Url => '$apiBaseUrl/api/v1';
}

/// Renseigné au bootstrap via `overrideWithValue` — jamais utilisé sans override.
final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw UnimplementedError(
    'appEnvironmentProvider doit être surchargé dans bootstrap()',
  ),
);
