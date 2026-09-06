import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_controllers.dart';
import 'package:carlys_mobile/features/subscription/presentation/widgets/subscription_manage_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_subscription_repository.dart';

/// LA LIGNE « GÉRER MON ABONNEMENT ».
///
/// Elle ouvre le portail de facturation du prestataire et ne décide de
/// rien. Ce qui se vérifie ici : qu'elle ouvre la bonne adresse, qu'elle
/// attend visiblement sans doubler la demande, et qu'elle dit la vérité
/// quand le portail ne s'ouvre pas (hors ligne, refus, panne, navigateur).
void main() {
  Widget harness(
    FakeSubscriptionRepository repository, {
    List<Uri>? opened,
    bool canOpen = true,
  }) => ProviderScope(
    overrides: [
      subscriptionRepositoryProvider.overrideWithValue(repository),
      urlOpenerProvider.overrideWithValue((url) async {
        opened?.add(url);
        return canOpen;
      }),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: const Scaffold(body: SubscriptionManageRow()),
    ),
  );

  Future<void> tapRow(WidgetTester tester) async {
    await tester.tap(find.text(SubscriptionManageRow.label));
    await tester.pumpAndSettle();
  }

  testWidgets('ouvre le portail du prestataire, sans rien dire de plus', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(isPremium: true);
    final opened = <Uri>[];
    await tester.pumpWidget(harness(repository, opened: opened));

    // Le sous-titre d'une ligne de liste se rend en mono MAJUSCULES.
    expect(find.text('PAIEMENT, FACTURES, RÉSILIATION'), findsOneWidget);
    await tapRow(tester);

    expect(opened.single.toString(), 'https://portail.exemple/session');
    expect(repository.portalOpenings, 1);
    expect(find.byIcon(AppIcons.error), findsNothing);
    expect(find.byIcon(AppIcons.offline), findsNothing);
  });

  testWidgets('pendant l’ouverture : attente visible, aucune double demande', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(isPremium: true)
      ..portalGate = Completer<String>();
    final opened = <Uri>[];
    await tester.pumpWidget(harness(repository, opened: opened));

    await tester.tap(find.text(SubscriptionManageRow.label));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Réappuyer pendant l'attente ne demande pas un second portail.
    await tester.tap(
      find.text(SubscriptionManageRow.label),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repository.portalOpenings, 1);

    repository.portalGate!.complete('https://portail.exemple/session');
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(opened, hasLength(1));
  });

  testWidgets('hors ligne : le dit, et n’ouvre rien', (tester) async {
    final repository = FakeSubscriptionRepository(
      isPremium: true,
      portalError: const NetworkException('Serveur injoignable'),
    );
    final opened = <Uri>[];
    await tester.pumpWidget(harness(repository, opened: opened));

    await tapRow(tester);

    expect(find.textContaining('Tu es hors ligne'), findsOneWidget);
    expect(find.byIcon(AppIcons.offline), findsOneWidget);
    expect(opened, isEmpty);
    // La ligne reste là : le réseau revenu, on réessaie en la touchant.
    expect(find.text(SubscriptionManageRow.label), findsOneWidget);
  });

  testWidgets('refus du serveur : son message, tel quel', (tester) async {
    final repository = FakeSubscriptionRepository(
      isPremium: true,
      portalError: const ValidationException(
        'Aucun client Stripe pour ce compte.',
      ),
    );
    await tester.pumpWidget(harness(repository));

    await tapRow(tester);

    expect(find.text('Aucun client Stripe pour ce compte.'), findsOneWidget);
    expect(find.byIcon(AppIcons.info), findsOneWidget);
  });

  testWidgets('panne : le dit au lieu de rester muet', (tester) async {
    final repository = FakeSubscriptionRepository(
      isPremium: true,
      portalError: const ServerException('Bad Gateway', statusCode: 502),
    );
    await tester.pumpWidget(harness(repository));

    await tapRow(tester);

    expect(
      find.text('Le portail n’a pas pu s’ouvrir. Réessaie dans un instant.'),
      findsOneWidget,
    );
    expect(find.byIcon(AppIcons.error), findsOneWidget);
  });

  testWidgets('sans navigateur : le dit', (tester) async {
    await tester.pumpWidget(
      harness(FakeSubscriptionRepository(isPremium: true), canOpen: false),
    );

    await tapRow(tester);

    expect(
      find.text('Aucun navigateur n’a pu s’ouvrir sur cet appareil.'),
      findsOneWidget,
    );
  });

  testWidgets('une nouvelle tentative efface le message précédent', (
    tester,
  ) async {
    final repository = FakeSubscriptionRepository(
      isPremium: true,
      portalError: const NetworkException('Serveur injoignable'),
    );
    await tester.pumpWidget(harness(repository));
    await tapRow(tester);
    expect(find.textContaining('Tu es hors ligne'), findsOneWidget);

    // Le réseau est revenu : la même ligne, retouchée, ouvre le portail.
    repository.portalGate = Completer<String>()
      ..complete('https://portail.exemple/session');
    await tapRow(tester);

    expect(find.textContaining('Tu es hors ligne'), findsNothing);
    expect(repository.portalOpenings, 2);
  });
}
