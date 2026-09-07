import 'package:carlys_mobile/core/database/local_account_purge.dart';

/// Purge inerte pour les tests de widgets qui se déconnectent : sans elle,
/// la déconnexion ouvrirait la vraie base Drift pour la vider.
class NoopLocalAccountPurge implements LocalAccountPurge {
  int runs = 0;

  @override
  Future<void> run() async {
    runs++;
  }
}
