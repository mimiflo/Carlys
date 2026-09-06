import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
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

/// Comment l'ouverture du portail de facturation se termine.
///
/// Scellé plutôt qu'énuméré : un refus du serveur porte SON message
/// (« aucun client chez le prestataire », par exemple), et l'écran le
/// montre tel quel plutôt qu'une phrase générique.
sealed class PortalOutcome {
  const PortalOutcome();
}

/// Le portail s'est ouvert dans le navigateur. Ce qui s'y fait revient par
/// webhook : l'écran relit le plan au retour, comme pour l'achat.
final class PortalOpened extends PortalOutcome {
  const PortalOpened();
}

/// Pas de réseau : le portail vit chez le prestataire, hors ligne il
/// n'existe pas.
final class PortalOffline extends PortalOutcome {
  const PortalOffline();
}

/// Le serveur refuse, et dit pourquoi.
final class PortalRefused extends PortalOutcome {
  const PortalRefused(this.message);

  final String message;
}

/// L'appareil n'a pas pu ouvrir de navigateur.
final class PortalCannotOpen extends PortalOutcome {
  const PortalCannotOpen();
}

/// Panne, réponse invalide : l'écran le dit au lieu de rester muet.
final class PortalFailed extends PortalOutcome {
  const PortalFailed();
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

  /// Ouvre le portail de facturation du prestataire : moyen de paiement,
  /// factures, résiliation. Rien ne se décide ici non plus.
  Future<PortalOutcome> manage() async {
    final repository = _ref.read(subscriptionRepositoryProvider);
    final String url;
    try {
      url = await repository.startBillingPortal();
    } on NetworkException {
      return const PortalOffline();
    } on ValidationException catch (exception) {
      // Refus MÉTIER (400, 409, 422) : le serveur explique, l'écran répète.
      return PortalRefused(exception.message);
    } on ForbiddenException catch (exception) {
      return PortalRefused(exception.message);
    } on Object {
      return const PortalFailed();
    }

    final opened = await _ref.read(urlOpenerProvider)(Uri.parse(url));
    return opened ? const PortalOpened() : const PortalCannotOpen();
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
