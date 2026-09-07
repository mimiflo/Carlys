import 'package:carlys_mobile/core/database/local_account_switch.dart';

/// Réclamation d'appareil inerte pour les tests : elle compte ses appels et
/// peut échouer sur commande, sans toucher au trousseau ni aux préférences.
class FakeLocalAccountSwitch implements LocalAccountSwitch {
  FakeLocalAccountSwitch({this.failure});

  /// Ce que `claimDevice` jette, quand il doit échouer.
  Object? failure;

  int claims = 0;

  @override
  Future<void> claimDevice() async {
    claims++;
    final error = failure;
    if (error != null) {
      throw error;
    }
  }
}
