import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/nutrition/presentation/screens/food_barcode_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../support/fake_camera.dart';

/// Le scanner du code-barres d'un produit. L'autorisation et le cycle de vie
/// de la caméra sont ceux du scan de code ami (même `CodeScannerView`,
/// éprouvé par `friend_code_scanner_screen_test.dart`) ; ici, ce qui lui est
/// propre : la caméra refusée laisse taper le code, et seul un code au
/// chiffre de contrôle juste est rendu.
void main() {
  late FakeCamera camera;

  setUp(() {
    camera = FakeCamera();
    MobileScannerPlatform.instance = camera;
  });

  /// Ouvre l'écran par-dessus une page, et rend ce qu'il dépile.
  Future<List<String?>> ouvrir(WidgetTester tester) async {
    final popped = <String?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => popped.add(
              await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const FoodBarcodeScannerScreen(),
                ),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('caméra refusée : l’écran le dit, le code se tape quand même', (
    tester,
  ) async {
    final popped = await ouvrir(tester);
    expect(camera.starts, 1);
    expect(find.text('Caméra non autorisée'), findsOneWidget);

    await tester.tap(find.text('Taper le code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3017620422003');
    await tester.pump();
    await tester.tap(find.text('Chercher'));
    await tester.pumpAndSettle();

    expect(popped, ['3017620422003']);
  });

  testWidgets('un chiffre de contrôle faux ne part pas', (tester) async {
    final popped = await ouvrir(tester);
    await tester.tap(find.text('Taper le code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '3017620422004');
    await tester.pump();
    await tester.tap(find.text('Chercher'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ce code ne se lit pas : vérifie ses chiffres.'),
      findsOne,
    );
    expect(popped, isEmpty);
  });
}
