import 'package:carlys_mobile/app/app.dart';
import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
      ],
      child: const CarlysApp(),
    );
  }

  testWidgets('affiche le splash puis navigue vers l’accueil', (tester) async {
    await tester.pumpWidget(buildApp());

    expect(find.text('Carlys'), findsWidgets);
    expect(find.text('Votre entraînement, partout.'), findsOneWidget);

    // Le splash navigue après AppMotion.deliberate * 2 (1 200 ms).
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.text('Fondation prête'), findsOneWidget);
    expect(find.textContaining('http://localhost:3000'), findsOneWidget);
  });
}
