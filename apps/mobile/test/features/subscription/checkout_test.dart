import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/subscription/domain/entities/subscription.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_controllers.dart';
import 'package:carlys_mobile/features/subscription/presentation/widgets/subscription_offers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_subscription_repository.dart';

/// LE CHEMIN D'ACHAT.
///
/// Ce qui compte n'est pas qu'un bouton s'anime : c'est que l'application ne
/// s'accorde JAMAIS Premium elle-même. Elle ouvre une page de paiement, et
/// le droit revient du serveur, sur webhook signé, une fois l'argent
/// encaissé. Un écran qui déciderait du droit au retour de la page suffirait
/// à contourner la caisse.
void main() {
  ProviderContainer containerFor(
    FakeSubscriptionRepository repository, {
    List<Uri>? opened,
    bool canOpen = true,
  }) {
    final container = ProviderContainer(
      overrides: [
        subscriptionRepositoryProvider.overrideWithValue(repository),
        urlOpenerProvider.overrideWithValue((url) async {
          opened?.add(url);
          return canOpen;
        }),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  const offer = SubscriptionOffer(
    id: 'premium-annuel',
    name: 'Premium annuel',
    period: OfferPeriod.year,
    amountCents: 7990,
    currency: 'EUR',
    monthlyEquivalentCents: 666,
    trialDays: 7,
    isRecommended: true,
    savingPercent: 33,
  );

  test('l’achat ouvre la page du prestataire, et rien d’autre', () async {
    final repository = FakeSubscriptionRepository(checkoutAvailable: true);
    final opened = <Uri>[];
    final container = containerFor(repository, opened: opened);

    final outcome =
        await container.read(subscriptionActionsProvider).buy(offer);

    expect(outcome, CheckoutOutcome.opened);
    expect(opened.single.toString(), 'https://paiement.exemple/session');
    // Le plan reste celui du serveur : l'app n'a rien accordé.
    final plan = await container.read(planStatusProvider.future);
    expect(plan.isPremium, isFalse);
  });

  test('l’identifiant d’appareil voyage : rejouer n’ouvre pas deux paiements',
      () async {
    final repository = FakeSubscriptionRepository(checkoutAvailable: true);
    final container = containerFor(repository);

    await container.read(subscriptionActionsProvider).buy(offer);

    expect(repository.checkouts.single.offerId, 'premium-annuel');
    expect(repository.checkouts.single.id, isNotEmpty);
  });

  test('un serveur qui refuse le paiement ne fait pas semblant', () async {
    final repository = FakeSubscriptionRepository(
      checkoutAvailable: true,
      checkoutError: StateError('paiement non configuré'),
    );
    final opened = <Uri>[];
    final container = containerFor(repository, opened: opened);

    final outcome =
        await container.read(subscriptionActionsProvider).buy(offer);

    expect(outcome, CheckoutOutcome.unavailable);
    expect(opened, isEmpty);
  });

  test('un appareil sans navigateur le DIT au lieu de rester muet', () async {
    final container = containerFor(
      FakeSubscriptionRepository(checkoutAvailable: true),
      canOpen: false,
    );

    expect(
      await container.read(subscriptionActionsProvider).buy(offer),
      CheckoutOutcome.cannotOpen,
    );
  });

  group('affichage des prix', () {
    test('les centimes ne s’affichent que s’ils existent', () {
      // « 80,00 € » alourdit une comparaison de prix pour ne rien dire de
      // plus que « 80 € ».
      expect(formatOfferPrice(999, 'EUR'), '9,99 €');
      expect(formatOfferPrice(8000, 'EUR'), '80 €');
      expect(formatOfferPrice(7990, 'EUR'), '79,90 €');
    });

    test('une devise inconnue s’écrit telle quelle, sans symbole inventé', () {
      expect(formatOfferPrice(1200, 'CHF'), '12 CHF');
    });
  });
}
