import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/authentication/presentation/widgets/auth_form_error.dart';
import 'package:flutter_test/flutter_test.dart';

/// CE QUE CE FICHIER PROTÈGE : une erreur de validation dit QUOI corriger.
///
/// L'API écrit des messages destinés à un humain — « Adresse e-mail
/// invalide. » — et les rattache à leur champ. Le client les rangeait déjà
/// dans `fieldErrors`, mais l'écran n'affichait que le message général,
/// « Certaines données sont invalides. », qui ne désigne rien. Les deux
/// moitiés du chemin existaient ; il manquait la jonction.
void main() {
  test('les messages PAR CHAMP l’emportent sur le message général', () {
    const erreur = ValidationException(
      'Certaines données sont invalides.',
      fieldErrors: {
        'email': 'Adresse e-mail invalide.',
        'password': 'Mot de passe trop court.',
      },
    );

    final affiche = authErrorMessage(erreur);

    expect(affiche, contains('Adresse e-mail invalide.'));
    expect(affiche, contains('Mot de passe trop court.'));
    // Le générique disparaît : il ne dit rien que les deux autres ne disent.
    expect(affiche, isNot(contains('Certaines données sont invalides.')));
  });

  test('sans détail par champ, le message général reste', () {
    // Toutes les erreurs de validation ne viennent pas d'un formulaire : une
    // validation locale, ou un 409, n'a pas de champ à désigner.
    const erreur = ValidationException('Cet identifiant est déjà utilisé.');

    expect(authErrorMessage(erreur), 'Cet identifiant est déjà utilisé.');
  });

  test('les autres familles d’erreur sont inchangées', () {
    // Contre-épreuve : la branche ajoutée ne doit pas déborder sur les
    // voisines, dont les messages sont choisis pour ne rien révéler.
    expect(
      authErrorMessage(const NetworkException('peu importe')),
      'Connexion impossible. Vérifie ton accès Internet.',
    );
    expect(
      authErrorMessage(
        const ServerException('détail interne', statusCode: 500),
      ),
      'Le serveur est momentanément indisponible.',
    );
    expect(
      authErrorMessage(const UnauthorizedException('Identifiants incorrects.')),
      'Identifiants incorrects.',
    );
  });
}
