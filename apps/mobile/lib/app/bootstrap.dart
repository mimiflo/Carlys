import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import 'app.dart';
import 'environment/app_environment.dart';
import 'observers/app_provider_observer.dart';

/// Point d'entrée unique : initialise l'environnement, la capture d'erreurs
/// et le conteneur Riverpod avant de lancer l'application.
Future<void> bootstrap() async {
  const logger = AppLogger('bootstrap');

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final environment = AppEnvironment.fromDartDefine();
      logger.info(
        'Démarrage Carlys — flavor: ${environment.flavor.name}, '
        'API: ${environment.apiBaseUrl}',
      );

      FlutterError.onError = (details) {
        logger.error(
          'Erreur Flutter non interceptée',
          error: details.exception,
          stackTrace: details.stack,
        );
        FlutterError.presentError(details);
      };

      runApp(
        ProviderScope(
          observers: const [AppProviderObserver()],
          overrides: [
            appEnvironmentProvider.overrideWithValue(environment),
          ],
          child: const CarlysApp(),
        ),
      );
    },
    (error, stackTrace) {
      // Sentry sera branché ici (avec son DSN par environnement).
      logger.error(
        'Erreur non interceptée',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}
