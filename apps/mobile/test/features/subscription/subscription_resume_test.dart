import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_controllers.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_resume_refresh.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_lifecycle.dart';
import '../../support/fake_subscription_repository.dart';
import '../../support/first_run_prefs.dart';
import '../../support/subscription_app.dart';

/// LE RETOUR DANS L'APPLICATION.
///
/// Le paiement se fait dehors. Le seul moment où l'écran peut apprendre que
/// l'argent est encaissé, c'est quand l'utilisateur revient ; et comme le
/// webhook peut arriver quelques secondes après lui, une relance suit. Ce
/// qui se vérifie ici n'est pas qu'un droit s'affiche : c'est que l'écran
/// RELIT le serveur au bon moment, et n'invente rien entre-temps.
void main() {
  setUp(() {
    seedCompletedFirstRun();
    // Scène 3D et bordure animée en boucle : animations réduites pour que
    // pumpAndSettle converge.
    TestWidgetsFlutterBinding.ensureInitialized();
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

  testWidgets('de retour dans l’application, Gratuit devient Premium', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository();
    await tester.pumpWidget(appWith(subscription: repository));
    await tester.pumpAndSettle();
    await openSubscription(tester);
    expect(find.text('GRATUIT'), findsOneWidget);

    // Pendant que l'utilisateur payait, le webhook a accordé le droit.
    repository.isPremium = true;
    await leaveAndComeBack(tester);
    await tester.pumpAndSettle();

    expect(find.text('ACTIF'), findsOneWidget);
    expect(find.text('GRATUIT'), findsNothing);
    expect(find.textContaining('Renouvellement le '), findsOneWidget);

    // La relance différée part ensuite, et confirme le même état.
    await tester.pump(SubscriptionResumeRefresh.webhookGrace);
    await tester.pumpAndSettle();
    expect(find.text('ACTIF'), findsOneWidget);
  });

  testWidgets('webhook en retard : la relance différée rattrape le droit', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository();
    await tester.pumpWidget(appWith(subscription: repository));
    await tester.pumpAndSettle();
    await openSubscription(tester);

    // Retour AVANT que le webhook n'ait atteint le serveur : le plan relu
    // est encore Gratuit, et l'écran le dit tel quel.
    await leaveAndComeBack(tester);
    await tester.pumpAndSettle();
    expect(find.text('GRATUIT'), findsOneWidget);

    repository.isPremium = true;
    await tester.pump(SubscriptionResumeRefresh.webhookGrace);
    await tester.pumpAndSettle();

    expect(find.text('ACTIF'), findsOneWidget);
    expect(find.text('GRATUIT'), findsNothing);
  });

  testWidgets('un retour relit tout de suite, puis UNE seule fois plus tard', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository();
    final container = ProviderContainer(
      overrides: [subscriptionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    // Un écran regarde le plan : sans lui, le provider `autoDispose` serait
    // relu à chaque `read`, ce qui ne prouverait rien.
    final watching = container.listen(planStatusProvider, (_, __) {});
    addTearDown(watching.close);
    await container.read(planStatusProvider.future);
    expect(repository.planStatusReads, 1);

    final refresh = container.read(subscriptionResumeRefreshProvider);
    refresh.onResume();
    await container.read(planStatusProvider.future);
    await tester.pump();
    expect(repository.planStatusReads, 2);

    // Un second retour, deux secondes plus tard, REMPLACE la relance armée
    // par le premier : si elle n'était pas annulée, elle tomberait à sa
    // propre échéance, avant celle du second retour.
    const half = Duration(seconds: 2);
    await tester.pump(half);
    refresh.onResume();
    await container.read(planStatusProvider.future);
    await tester.pump();
    expect(repository.planStatusReads, 3);

    // Échéance du PREMIER minuteur, s'il avait survécu : rien ne bouge.
    await tester.pump(SubscriptionResumeRefresh.webhookGrace - half);
    await container.read(planStatusProvider.future);
    expect(repository.planStatusReads, 3);

    // Échéance du second : la relance, une seule.
    await tester.pump(half);
    await container.read(planStatusProvider.future);
    expect(repository.planStatusReads, 4);

    // Et plus rien ensuite : la relance est unique.
    await tester.pump(SubscriptionResumeRefresh.webhookGrace);
    await container.read(planStatusProvider.future);
    expect(repository.planStatusReads, 4);
  });
}
