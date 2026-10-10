import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/presentation/screens/friend_code_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../support/fake_camera.dart';

void main() {
  late FakeCamera camera;

  setUp(() {
    camera = FakeCamera();
    MobileScannerPlatform.instance = camera;
  });

  Future<void> ouvrir(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const FriendCodeScannerScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ouvrir l’écran démarre la caméra, donc demande l’autorisation', (
    tester,
  ) async {
    await ouvrir(tester);
    expect(camera.starts, 1);
  });

  testWidgets('refusée : l’écran le dit, sans redemander en boucle', (
    tester,
  ) async {
    await ouvrir(tester);
    expect(find.text('Caméra non autorisée'), findsOneWidget);

    // La boîte d'autorisation ne rend l'appli qu'« inactive » : son retour
    // ne relance rien, sans quoi le refus redemanderait aussitôt.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.starts, 1);
  });

  testWidgets('autorisée dans les réglages : au retour, la caméra repart', (
    tester,
  ) async {
    await ouvrir(tester);
    expect(find.text('Caméra non autorisée'), findsOneWidget);

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    camera.authorized = true;
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    expect(camera.starts, 2);
    expect(find.text('Caméra non autorisée'), findsNothing);
  });

  testWidgets('en arrière-plan, la caméra se coupe', (tester) async {
    camera.authorized = true;
    await ouvrir(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(camera.stops, greaterThanOrEqualTo(1));
  });

  testWidgets('« Autoriser » pendant le démarrage : pas de second démarrage', (
    tester,
  ) async {
    await ouvrir(tester);
    camera
      ..authorized = true
      ..hold = Completer<void>();
    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    // La réponse arrive, puis l'appli revient au premier plan, caméra encore
    // en route.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    camera.hold!.complete();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(camera.starts, 2);
  });

  testWidgets('« Réessayer » redemande l’autorisation', (tester) async {
    await ouvrir(tester);
    camera.authorized = true;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();

    expect(camera.starts, 2);
    expect(find.text('Caméra non autorisée'), findsNothing);
  });
}
