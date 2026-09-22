import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/subscription/presentation/widgets/subscription_offers.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_subscription_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/subscription_app.dart';

/// LA PORTE D'ACHAT NE DISPARAÎT PAS EN SILENCE.
///
/// Le catalogue d'offres rendait `SizedBox.shrink()` sur erreur, avec le même
/// argument que pour le chargement : « le catalogue n'est pas le cœur de
/// l'écran ». Mais sans offres il n'y a plus de porte d'achat DU TOUT, et la
/// faire disparaître sans un mot laisse croire que Premium ne se vend pas.
///
/// Le chargement, lui, garde son silence : c'est la distinction que ce
/// fichier défend.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures.allOn;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('un catalogue en panne se DIT, avec sa reprise', (tester) async {
    await tester.pumpWidget(
      appWith(
        subscription: FakeSubscriptionRepository(
          checkoutAvailable: true,
          offersError: const ServerException('offres indisponibles'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSubscription(tester);

    expect(find.byType(SubscriptionOffers), findsNothing);
    expect(find.text('Offres indisponibles'), findsOneWidget);
    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets('hors ligne, le message nomme le réseau et non une panne', (
    tester,
  ) async {
    // « Réessaie une fois connecté » est une consigne que la personne peut
    // suivre ; « ça n'a pas fonctionné » n'en est pas une.
    await tester.pumpWidget(
      appWith(
        subscription: FakeSubscriptionRepository(
          checkoutAvailable: true,
          offersError: const NetworkException('hors ligne'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await openSubscription(tester);

    expect(find.textContaining('reviennent avec le réseau'), findsOneWidget);
  });

  testWidgets('un catalogue qui CHARGE reste muet, lui', (tester) async {
    // La distinction est le propos : un chargement ne doit pas faire
    // clignoter une page qui a déjà tout dit de Premium.
    await tester.pumpWidget(
      appWith(
        subscription: FakeSubscriptionRepository(checkoutAvailable: true),
      ),
    );
    await tester.pumpAndSettle();
    await openSubscription(tester);

    expect(find.byType(SubscriptionOffers), findsOneWidget);
    expect(find.text('Offres indisponibles'), findsNothing);
  });
}
