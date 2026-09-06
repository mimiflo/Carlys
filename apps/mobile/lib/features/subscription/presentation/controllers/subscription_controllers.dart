import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/subscription.dart';

/// Plan effectif de l'utilisateur (décidé côté serveur).
final planStatusProvider = FutureProvider.autoDispose<PlanStatus>((ref) {
  return ref.watch(subscriptionRepositoryProvider).planStatus();
});

/// Droits effectifs, dans l'ordre servi par le serveur.
final entitlementsProvider = FutureProvider.autoDispose<List<EntitlementEntry>>(
  (ref) {
    return ref.watch(subscriptionRepositoryProvider).entitlements();
  },
);

/// Le catalogue d'offres, prix compris.
final offerCatalogProvider = FutureProvider.autoDispose<OfferCatalog>((ref) {
  return ref.watch(subscriptionRepositoryProvider).offers();
});

/// Comment un achat se termine, du point de vue de l'écran.
enum CheckoutOutcome {
  /// La page de paiement s'est ouverte. Le droit, lui, arrivera par le
  /// serveur : rien n'est accordé ici.
  opened,

  /// Le serveur n'ouvre pas encore de paiement.
  unavailable,

  /// L'appareil n'a pas pu ouvrir de navigateur.
  cannotOpen,

  /// Réseau, refus, panne : l'écran le dit au lieu de rester muet.
  failed,
}

/// Ce que l'écran d'abonnement sait FAIRE.
///
/// L'ouverture du navigateur vit ici et non dans un widget : c'est une
/// action, pas un rendu, et l'écran doit pouvoir être éprouvé sans ouvrir
/// quoi que ce soit.
class SubscriptionActions {
  const SubscriptionActions(this._ref, {this._uuid = const Uuid()});

  final Ref _ref;
  final Uuid _uuid;

  Future<CheckoutOutcome> buy(SubscriptionOffer offer) async {
    final repository = _ref.read(subscriptionRepositoryProvider);
    final String url;
    try {
      // L'identifiant est engendré ICI, hors ligne : rejouer la demande rend
      // la même page de paiement plutôt que d'en ouvrir une seconde.
      url = await repository.startCheckout(offerId: offer.id, id: _uuid.v4());
    } on StateError {
      return CheckoutOutcome.unavailable;
    } on Object {
      return CheckoutOutcome.failed;
    }

    // Rien n'est relu ici : `launchUrl` rend la main dès que le navigateur
    // s'ouvre, l'utilisateur n'a pas encore payé. La relecture se fait au
    // retour au premier plan (`SubscriptionResumeRefresh`).
    final opened = await _ref.read(urlOpenerProvider)(Uri.parse(url));
    return opened ? CheckoutOutcome.opened : CheckoutOutcome.cannotOpen;
  }
}

/// Ouverture d'une adresse externe, injectable pour les tests : ils ne
/// doivent jamais lancer un navigateur.
typedef UrlOpener = Future<bool> Function(Uri url);

final urlOpenerProvider = Provider<UrlOpener>((ref) {
  return (url) => launchUrl(url, mode: LaunchMode.externalApplication);
});

final subscriptionActionsProvider = Provider<SubscriptionActions>(
  SubscriptionActions.new,
);
