import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'subscription_controllers.dart';

/// Relit l'état d'abonnement au RETOUR dans l'application.
///
/// Le paiement se fait dehors, dans le navigateur. `launchUrl` rend la main
/// dès que le navigateur s'OUVRE, pas quand l'utilisateur revient : relire à
/// cet instant, c'est relire l'état d'avant l'achat, et l'écran restait sur
/// « Gratuit » jusqu'à ce qu'on le quitte. Le bon moment est le retour au
/// premier plan. Et comme le webhook signé qui accorde le droit peut arriver
/// quelques secondes APRÈS ce retour, une seconde lecture est programmée,
/// une seule, à [webhookGrace].
///
/// Aucun droit n'est accordé ici : on relit ce que le serveur décide.
class SubscriptionResumeRefresh {
  SubscriptionResumeRefresh(this._ref);

  /// Délai de la relance unique : le temps que le webhook parvienne au
  /// serveur et que le droit soit projeté. Assez long pour couvrir un
  /// webhook qui traîne, assez court pour que l'écran ne mente pas
  /// longtemps.
  static const Duration webhookGrace = Duration(seconds: 4);

  final Ref _ref;
  Timer? _retry;

  /// À appeler quand l'application revient au premier plan.
  void onResume() {
    _rereadPlan();
    // Un retour pendant qu'une relance est déjà armée la REMPLACE : jamais
    // deux relances en vol pour un seul retour.
    _retry?.cancel();
    _retry = Timer(webhookGrace, () {
      _retry = null;
      _rereadPlan();
    });
  }

  /// Invalider un provider `autoDispose` compte comme un rafraîchissement :
  /// l'écran garde la valeur précédente pendant la lecture, sans clignoter.
  void _rereadPlan() {
    _ref.invalidate(planStatusProvider);
    _ref.invalidate(entitlementsProvider);
  }

  void dispose() {
    _retry?.cancel();
    _retry = null;
  }
}

/// Vit avec le conteneur, pas avec l'écran : fermer l'abonnement avant que
/// la relance ne parte ne l'annule pas, et le profil, qui affiche le même
/// plan, en profite.
final subscriptionResumeRefreshProvider = Provider<SubscriptionResumeRefresh>((
  ref,
) {
  final refresh = SubscriptionResumeRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});
