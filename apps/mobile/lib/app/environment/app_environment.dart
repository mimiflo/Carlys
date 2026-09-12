import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flavors de l'application, alignés sur les environnements serveur.
enum AppFlavor { development, staging, production }

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

  /// Préfixe complet des routes métier.
  String get apiV1Url => '$apiBaseUrl/api/v1';

  /// Politique de confidentialité, servie par l'application web.
  Uri get privacyPolicyUrl => Uri.parse('$publicWebBaseUrl/privacy');

  /// Conditions d'utilisation, servies par l'application web.
  Uri get termsOfServiceUrl => Uri.parse('$publicWebBaseUrl/terms');

  /// Refuse de démarrer sur une configuration qui ne peut pas fonctionner.
  ///
  /// `publicWebBaseUrl` a un défaut commode en développement, et c'est
  /// exactement ce qui le rend dangereux : un build de `staging` ou de
  /// `production` qui oublie le `--dart-define` embarque deux liens légaux
  /// morts (`localhost:3001/privacy` et `/terms`) sans que rien n'échoue ni
  /// au build ni au lancement. Ce sont précisément les liens qu'un
  /// examinateur de magasin ouvre, et deux liens morts font refuser une
  /// soumission. Un lancement bruyamment raté en interne coûte
  /// incomparablement moins cher.
  ///
  /// `development` est épargné : le défaut y est le bon réglage.
  /// L'ADRESSE DE L'API EST CONTRÔLÉE PAR LA MÊME RÈGLE, et pour une raison
  /// pire encore : son oubli ne se voit nulle part. Un build `production` sans
  /// `CARLYS_API_BASE_URL` se compile, se lance, affiche son écran d'accueil —
  /// puis chaque appel réseau part sur `http://localhost:3000`. Sur un
  /// téléphone, cette adresse n'existe pas ; et Android bloque de toute façon
  /// le trafic en clair en release. L'application paraît « lente », puis
  /// « hors ligne », sans qu'aucun message ne nomme la cause. Le lien légal
  /// mort, au moins, se voit à l'œil ; celui-ci ne se voit qu'au support.
  void assertUsable() {
    if (flavor == AppFlavor.development) return;
    if (!_isPublicWebAddress(apiBaseUrl)) {
      throw StateError(
        'CARLYS_API_BASE_URL manque ou pointe en local pour le flavor '
        '${flavor.name} : tous les appels réseau iraient sur « $apiBaseUrl ». '
        'Relance avec --dart-define=CARLYS_API_BASE_URL=https://…',
      );
    }
    if (!_isPublicWebAddress(publicWebBaseUrl)) {
      throw StateError(
        'CARLYS_PUBLIC_WEB_BASE_URL manque ou pointe en local pour le flavor '
        '${flavor.name} : les liens légaux ouvriraient « $publicWebBaseUrl ». '
        'Relance avec --dart-define=CARLYS_PUBLIC_WEB_BASE_URL=https://…',
      );
    }
  }

  /// Une adresse absolue dont l'hôte n'est ni vide ni celui de la machine de
  /// développement. `10.0.2.2` est la boucle locale vue par l'émulateur
  /// Android : elle est aussi morte qu'un `localhost` sur un vrai téléphone.
  static bool _isPublicWebAddress(String url) {
    const localHosts = {'localhost', '127.0.0.1', '::1', '0.0.0.0', '10.0.2.2'};
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    return !localHosts.contains(uri.host);
  }
}

/// Renseigné au bootstrap via `overrideWithValue` — jamais utilisé sans override.
final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw UnimplementedError(
    'appEnvironmentProvider doit être surchargé dans bootstrap()',
  ),
);
