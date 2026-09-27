import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_state.dart';

/// LA FRONTIÈRE DE SESSION, telle que la voient les caches serveur du compte.
///
/// L'état est le NUMÉRO de la session ouverte, ou `null` quand aucune ne
/// l'est. Chaque ouverture (connexion, inscription, restauration après une
/// déconnexion) prend un numéro neuf : un cache qui en dépend se relit donc
/// pour le compte qui arrive, et sait que la valeur qu'il tenait appartenait
/// à la session d'avant.
///
/// Pourquoi un provider à part, et pas `authControllerProvider` lui-même :
/// le contrôleur de session tire le client HTTP, l'environnement et le
/// trousseau. Un cache de compte qui le regardait les aurait tous tirés avec
/// lui, jusque dans les tests qui n'ont que faire de la session. Celui-ci ne
/// dépend de rien ; `AuthController` le tient à jour à chaque changement
/// d'état (`follow`), de façon SYNCHRONE : la frontière est franchie pour
/// les caches à l'instant même où elle l'est pour l'interface.
///
/// Ouvert par défaut (session 0) : avant que la restauration ne tranche,
/// l'état est inconnu, pas fermé — rien ne lit un cache de compte à ce
/// moment-là, et un banc de test sans session garde des caches qui lisent.
class AccountSession extends Notifier<int?> {
  int _opened = 0;

  @override
  int? build() => _opened;

  /// Suit l'état de session : fermé seulement quand il n'y a PLUS de session.
  void follow(AuthState auth) {
    if (auth is AuthUnauthenticated) {
      state = null;
    } else if (state == null) {
      state = ++_opened;
    }
  }
}

final accountSessionProvider = NotifierProvider<AccountSession, int?>(
  AccountSession.new,
);
