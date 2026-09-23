import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_card.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_plan_section.dart';
import 'package:carlys_mobile/features/subscription/domain/entities/subscription.dart';
import 'package:carlys_mobile/features/subscription/presentation/controllers/subscription_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'ABONNEMENT NE MENT PAS PAR OMISSION.
///
/// Les réglages le lisaient au `valueOrNull` : hors réseau, la bannière
/// disparaissait SANS UN MOT, et l'écran affirmait par son absence que
/// l'utilisateur n'avait pas d'abonnement.
///
/// Ce fichier défend la distinction entre « pas pu » et « rien ».
void main() {
  const plan = PlanStatus(planName: 'Premium', isPremium: true);

  Future<void> pumpSection(WidgetTester tester, Override source) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [source],
        child: MaterialApp(
          home: Scaffold(body: ProfilePlanSection(onOpenPlan: () {})),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('hors ligne : l’écran le DIT, il ne se contente pas de vider', (
    tester,
  ) async {
    await pumpSection(
      tester,
      planStatusProvider.overrideWith(
        (ref) async => throw const NetworkException('socket'),
      ),
    );

    expect(find.text('Hors connexion'), findsOneWidget);
    expect(
      find.text(
        'Ton abonnement vit sur le serveur. Il revient avec le réseau.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ProfilePlanCard), findsNothing);
  });

  testWidgets('serveur en panne : l’échec générique, avec un réessai', (
    tester,
  ) async {
    await pumpSection(
      tester,
      planStatusProvider.overrideWith(
        (ref) async => throw const ServerException('500'),
      ),
    );

    expect(find.text('Abonnement indisponible'), findsOneWidget);
    expect(
      find.text('L’état de ton abonnement n’a pas pu être chargé.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.text('Hors connexion'), findsNothing);
  });

  testWidgets('serveur qui tarde : rien n’est affirmé', (tester) async {
    await pumpSection(
      tester,
      planStatusProvider.overrideWith((ref) => Completer<PlanStatus>().future),
    );

    expect(find.text('Abonnement indisponible'), findsNothing);
    expect(find.text('Hors connexion'), findsNothing);
    expect(find.byType(ProfilePlanCard), findsNothing);
  });

  testWidgets('serveur qui répond : la bannière', (tester) async {
    await pumpSection(
      tester,
      planStatusProvider.overrideWith((ref) async => plan),
    );
    await tester.pump();

    expect(find.byType(ProfilePlanCard), findsOneWidget);
    expect(find.text('Premium'), findsWidgets);
    expect(find.text('Hors connexion'), findsNothing);
  });

  testWidgets('« Réessayer » relit VRAIMENT l’abonnement', (tester) async {
    // Un bouton de réessai qui ne relit rien vaut moins qu'aucun bouton :
    // l'utilisateur croit avoir agi. On compte donc les lectures.
    var lectures = 0;
    await pumpSection(
      tester,
      planStatusProvider.overrideWith((ref) async {
        lectures++;
        if (lectures == 1) {
          throw const NetworkException('socket');
        }
        return plan;
      }),
    );

    expect(find.text('Hors connexion'), findsOneWidget);
    expect(lectures, 1);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump();

    expect(lectures, 2);
    expect(find.text('Hors connexion'), findsNothing);
    expect(find.byType(ProfilePlanCard), findsOneWidget);
  });
}
