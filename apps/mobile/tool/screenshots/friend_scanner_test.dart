// Capture du scan de code ami, caméra refusée — OUTIL, exécuté à la demande :
//   flutter test tool/screenshots/friend_scanner_test.dart --update-goldens
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/community/presentation/screens/friend_code_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../test/support/fake_camera.dart';
import 'capture_test.dart' show loadRealFonts;

void main() {
  setUpAll(loadRealFonts);

  testWidgets('scan ami — caméra refusée', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    MobileScannerPlatform.instance = FakeCamera();

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const FriendCodeScannerScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/amis-scan-camera-refusee.png'),
    );
  });
}
