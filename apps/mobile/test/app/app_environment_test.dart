import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

/// UNE CONFIGURATION QUI NE PEUT PAS MARCHER DOIT FAIRE ÉCHOUER LE LANCEMENT.
///
/// `publicWebBaseUrl` a un défaut commode en développement, et c'est
/// précisément ce qui le rend dangereux : un build de production qui oublie
/// son `--dart-define` embarque deux liens légaux morts, ceux-là mêmes qu'un
/// examinateur de magasin ouvre. Rien n'échouait ni au build ni au lancement.
void main() {
  AppEnvironment environmentOn(
    AppFlavor flavor, {
    String? publicWeb,
    String api = 'https://api.exemple.test',
  }) => AppEnvironment(
    flavor: flavor,
    apiBaseUrl: api,
    publicWebBaseUrl: publicWeb ?? AppEnvironment.defaultPublicWebBaseUrl,
  );

  // L'ADRESSE DE L'API EST LE CAS LE PLUS SILENCIEUX DES DEUX. Un lien légal
  // mort se voit à l'œil dès qu'on ouvre l'écran ; une API restée sur
  // localhost ne se voit qu'au support, sous la forme d'une application
  // « lente » puis « hors ligne ». Elle est donc tenue à la même règle.
  group('adresse de l’API', () {
    test('production sans --dart-define : le lancement est refusé', () {
      expect(
        () => environmentOn(
          AppFlavor.production,
          publicWeb: 'https://app.exemple.test',
          api: 'http://localhost:3000',
        ).assertUsable(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(contains('CARLYS_API_BASE_URL'), contains('production')),
          ),
        ),
      );
    });

    test('staging est tenu à la même règle', () {
      expect(
        () => environmentOn(
          AppFlavor.staging,
          publicWeb: 'https://app-staging.exemple.test',
          api: 'http://localhost:3000',
        ).assertUsable(),
        throwsStateError,
      );
    });

    test('10.0.2.2, la boucle locale de l’émulateur, ne passe pas', () {
      expect(
        () => environmentOn(
          AppFlavor.production,
          publicWeb: 'https://app.exemple.test',
          api: 'http://10.0.2.2:3000',
        ).assertUsable(),
        throwsStateError,
      );
    });

    test('development et demo gardent leur défaut local', () {
      for (final flavor in [AppFlavor.development, AppFlavor.demo]) {
        expect(
          () => environmentOn(
            flavor,
            api: 'http://localhost:3000',
          ).assertUsable(),
          returnsNormally,
          reason: flavor.name,
        );
      }
    });

    test('les deux adresses publiques ensemble : le lancement passe', () {
      expect(
        () => environmentOn(
          AppFlavor.production,
          publicWeb: 'https://app.exemple.test',
          api: 'https://api.exemple.test',
        ).assertUsable(),
        returnsNormally,
      );
    });
  });

  group('adresse du web public', () {
    test('production sans --dart-define : le lancement est refusé', () {
      expect(
        () => environmentOn(AppFlavor.production).assertUsable(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('CARLYS_PUBLIC_WEB_BASE_URL'),
              contains('production'),
            ),
          ),
        ),
      );
    });

    test('staging est tenu à la même règle que production', () {
      expect(
        () => environmentOn(AppFlavor.staging).assertUsable(),
        throwsStateError,
      );
    });

    test('une adresse locale explicite ne passe pas davantage', () {
      // Le défaut recopié à la main, et la boucle locale telle que
      // l'émulateur Android la voit : aussi morts l'un que l'autre sur un
      // vrai téléphone.
      for (final url in [
        'http://localhost:3001',
        'http://127.0.0.1:3001',
        'http://10.0.2.2:3001',
      ]) {
        expect(
          () => environmentOn(
            AppFlavor.production,
            publicWeb: url,
          ).assertUsable(),
          throwsStateError,
          reason: url,
        );
      }
    });

    test('une adresse sans schéma ne passe pas non plus', () {
      // « carlys.app » donnerait « carlys.app/privacy », qu'aucun navigateur
      // n'ouvre : un hôte vide est un défaut de configuration, pas un choix.
      expect(
        () => environmentOn(
          AppFlavor.production,
          publicWeb: 'carlys.app',
        ).assertUsable(),
        throwsStateError,
      );
    });

    test('une vraie adresse publique passe', () {
      expect(
        () => environmentOn(
          AppFlavor.production,
          publicWeb: 'https://carlys.app',
        ).assertUsable(),
        returnsNormally,
      );
    });

    test('développement et démo gardent leur défaut', () {
      // Le défaut y est le bon réglage : le Next.js d'apps/admin sert les
      // pages publiques sur le port 3001, et la démo n'a pas de serveur.
      expect(
        () => environmentOn(AppFlavor.development).assertUsable(),
        returnsNormally,
      );
      expect(
        () => environmentOn(AppFlavor.demo).assertUsable(),
        returnsNormally,
      );
    });
  });

  test('les adresses légales se construisent depuis la base', () {
    const environment = AppEnvironment(
      flavor: AppFlavor.production,
      apiBaseUrl: 'https://api.carlys.app',
      publicWebBaseUrl: 'https://carlys.app',
    );

    expect(
      environment.privacyPolicyUrl,
      Uri.parse('https://carlys.app/privacy'),
    );
    expect(
      environment.termsOfServiceUrl,
      Uri.parse('https://carlys.app/terms'),
    );
    expect(environment.apiV1Url, 'https://api.carlys.app/api/v1');
  });
}
