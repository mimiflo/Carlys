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
    this.publicWebBaseUrl = defaultPublicWebBaseUrl,
    this.push,
  });

  /// Application web publique en développement : le Next.js d'`apps/admin`
  /// sert les pages ouvertes (vérification d'adresse, nouveau mot de passe,
  /// confidentialité, conditions) sur le port 3001.
  static const String defaultPublicWebBaseUrl = 'http://localhost:3001';

  factory AppEnvironment.fromDartDefine() {
    const flavorName = String.fromEnvironment(
      'CARLYS_FLAVOR',
      defaultValue: 'development',
    );
    const apiBaseUrl = String.fromEnvironment(
      'CARLYS_API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    );
    // Adresse publique du web, DISTINCTE de celle de l'API : c'est elle que
    // portent les liens des e-mails (`PUBLIC_APP_URL` côté serveur) et c'est
    // elle qu'ouvrent les lignes « Politique de confidentialité » et
    // « Conditions d'utilisation » des réglages.
    const publicWebBaseUrl = String.fromEnvironment(
      'CARLYS_PUBLIC_WEB_BASE_URL',
      defaultValue: defaultPublicWebBaseUrl,
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
      publicWebBaseUrl: publicWebBaseUrl,
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

  /// Base de l'application web publique, sans barre finale
  /// (ex. https://carlys.app) : c'est elle qui sert `/privacy` et `/terms`.
  final String publicWebBaseUrl;

  /// Null tant que la configuration Firebase n'est pas injectée : le push
  /// est alors inactif, le reste de l'application vit normalement.
  final FirebasePushOptions? push;

  bool get isDevelopment => flavor == AppFlavor.development;
  bool get isProduction => flavor == AppFlavor.production;
  bool get isDemo => flavor == AppFlavor.demo;

  /// Préfixe complet des routes métier.
  String get apiV1Url => '$apiBaseUrl/api/v1';

  /// Politique de confidentialité, servie par l'application web.
  Uri get privacyPolicyUrl => Uri.parse('$publicWebBaseUrl/privacy');

  /// Conditions d'utilisation, servies par l'application web.
  Uri get termsOfServiceUrl => Uri.parse('$publicWebBaseUrl/terms');
}

/// Renseigné au bootstrap via `overrideWithValue` — jamais utilisé sans override.
final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw UnimplementedError(
    'appEnvironmentProvider doit être surchargé dans bootstrap()',
  ),
);
