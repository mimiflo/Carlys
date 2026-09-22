import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/academy/domain/entities/academy.dart';
import 'package:carlys_mobile/features/academy/presentation/controllers/academy_controllers.dart';
import 'package:carlys_mobile/features/academy/presentation/screens/journey_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// LE PARCOURS DISTINGUE « ÇA CHARGE » DE « ÇA A ÉCHOUÉ ».
///
/// L'écran se décidait sur `academyJourneyProgressProvider == null`, qui vaut
/// `null` pendant le chargement ET en cas d'échec de lecture du pack. Une
/// panne laissait donc tourner l'indicateur indéfiniment, sans un mot et
/// sans reprise — alors que l'écran d'Academy et celui d'une étape, juste à
/// côté, branchent les trois branches depuis toujours.
void main() {
  Widget ecran(List<Override> overrides) => ProviderScope(
    overrides: overrides,
    child: const MaterialApp(home: JourneyScreen()),
  );

  testWidgets('une lecture en ÉCHEC se dit, et propose de réessayer', (
    tester,
  ) async {
    await tester.pumpWidget(
      ecran([
        academyPackProvider.overrideWith(
          (ref) => Future<List<Lesson>>.error(
            StateError('pack injoignable (voulu par le test)'),
          ),
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.text('Parcours indisponible'), findsOneWidget);
    expect(find.byType(AppErrorState), findsOneWidget);
  });

  testWidgets('une lecture QUI DURE garde l’indicateur, elle', (tester) async {
    // La distinction est le propos : tant que la lecture est en vol, tourner
    // est la bonne réponse.
    await tester.pumpWidget(
      ecran([
        academyPackProvider.overrideWith(
          (ref) => Completer<List<Lesson>>().future,
        ),
      ]),
    );
    await tester.pump();

    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.text('Parcours indisponible'), findsNothing);
  });
}
