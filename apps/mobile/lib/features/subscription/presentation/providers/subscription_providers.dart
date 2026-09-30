import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utilities/external_links.dart';
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
///
/// Scellé plutôt qu'énuméré, pour la même raison que [PortalOutcome] : un
/// refus du serveur porte SON message — « cet abonnement est déjà actif »,
/// « cet accès a été suspendu, contacte le support » — et l'écran le montre
/// tel quel. Il répondait « la page de paiement n'a pas pu s'ouvrir » à ces
/// deux cas-là, ce qui est faux et n'indique aucune suite.
sealed class CheckoutOutcome {
  const CheckoutOutcome();
}

/// La page de paiement s'est ouverte. Le droit, lui, arrivera par le
/// serveur : rien n'est accordé ici.
final class CheckoutOpened extends CheckoutOutcome {
  const CheckoutOpened();
}

/// Le serveur n'ouvre pas encore de paiement (503, prestataire non
/// configuré).
final class CheckoutUnavailable extends CheckoutOutcome {
  const CheckoutUnavailable();
}

/// Pas de réseau : la page de paiement vit chez le prestataire.
final class CheckoutOffline extends CheckoutOutcome {
  const CheckoutOffline();
}

/// Le serveur refuse, et dit pourquoi.
final class CheckoutRefused extends CheckoutOutcome {
  const CheckoutRefused(this.message);

  final String message;
}

/// L'appareil n'a pas pu ouvrir de navigateur.
final class CheckoutCannotOpen extends CheckoutOutcome {
  const CheckoutCannotOpen();
}

/// Panne, réponse invalide : l'écran le dit au lieu de rester muet.
final class CheckoutFailed extends CheckoutOutcome {
  const CheckoutFailed();
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
  SubscriptionActions(this._ref, {this._uuid = const Uuid()});

  final Ref _ref;
  final Uuid _uuid;

  /// L'identifiant de paiement DÉJÀ engendré pour une offre.
  ///
  /// Le commentaire promettait « rejouer la demande rend la même page de
  /// paiement » ; le code appelait `_uuid.v4()` à chaque `buy()`, donc deux
  /// appuis donnaient deux clés d'idempotence différentes, donc deux
  /// sessions de paiement chez le fournisseur. Un double appui — le geste le
  /// plus banal sur un bouton qui met une seconde à ouvrir un navigateur —
  /// suffisait à en ouvrir deux.
  ///
  /// L'identifiant est donc RETENU par offre, pour la durée du fournisseur
  /// (permanent : l'application entière). Le rejeu rend alors la même page,
  /// ce que la clé d'idempotence côté Stripe garantit.
  final Map<String, String> _paiementsEnCours = {};

  Future<CheckoutOutcome> buy(SubscriptionOffer offer) async {
    final repository = _ref.read(subscriptionRepositoryProvider);
    final String url;
    try {
      // L'identifiant est engendré ICI, hors ligne, et CONSERVÉ : rejouer la
      // demande rend la même page de paiement plutôt que d'en ouvrir une
      // seconde.
      final id = _paiementsEnCours.putIfAbsent(offer.id, () => _uuid.v4());
      url = await repository.startCheckout(offerId: offer.id, id: id);
    } on NetworkException {
      return const CheckoutOffline();
    } on ValidationException catch (exception) {
      // Refus MÉTIER (409 « abonnement déjà actif ») : le serveur explique
      // et donne la suite, l'écran répète.
      return CheckoutRefused(exception.message);
    } on ForbiddenException catch (exception) {
      // 403 « accès suspendu par notre équipe » : surtout pas un message
      // d'échec technique, il y a une démarche à faire.
      return CheckoutRefused(exception.message);
    } on ServerException catch (exception) {
      // Le paiement n'est pas configuré côté serveur : 503, et c'est le
      // seul cas qui mérite « pas encore ouvert ». Le `on StateError` d'avant
      // n'attrapait RIEN — le dépôt ne lève que des `AppException` — donc ce
      // cas-là tombait dans l'échec générique, comme tous les autres.
      return exception.statusCode == 503
          ? const CheckoutUnavailable()
          : const CheckoutFailed();
    } on Object {
      return const CheckoutFailed();
    }

    // Rien n'est relu ici : `launchUrl` rend la main dès que le navigateur
    // s'ouvre, l'utilisateur n'a pas encore payé. La relecture se fait au
    // retour au premier plan (`SubscriptionResumeRefresh`).
    final opened = await _ref.read(externalLinkOpenerProvider)(Uri.parse(url));
    return opened ? const CheckoutOpened() : const CheckoutCannotOpen();
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

    final opened = await _ref.read(externalLinkOpenerProvider)(Uri.parse(url));
    return opened ? const PortalOpened() : const PortalCannotOpen();
  }
}

final subscriptionActionsProvider = Provider<SubscriptionActions>(
  SubscriptionActions.new,
);
