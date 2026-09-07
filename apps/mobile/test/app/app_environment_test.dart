import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';

/// UNE CONFIGURATION QUI NE PEUT PAS MARCHER DOIT FAIRE ÉCHOUER LE LANCEMENT.
///
/// `publicWebBaseUrl` a un défaut commode en développement, et c'est
/// précisément ce qui le rend dangereux : un build de production qui oublie
/// son `--dart-define` embarque deux liens légaux morts, ceux-là mêmes qu'un
/// examinateur de magasin ouvre. Rien n'échouait ni au build ni au lancement.
void main() {
  AppEnvironment environmentOn(AppFlavor flavor, {String? publicWeb}) =>
      AppEnvironment(
        flavor: flavor,
        apiBaseUrl: 'https://api.exemple.test',
        publicWebBaseUrl: publicWeb ?? AppEnvironment.defaultPublicWebBaseUrl,
      );

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
