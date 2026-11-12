import 'package:carlys_mobile/core/utilities/formatting.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/health/data/health_prefs_store.dart';
import 'package:carlys_mobile/features/health/domain/health_data_source.dart';
import 'package:carlys_mobile/features/health/presentation/providers/health_providers.dart';
import 'package:carlys_mobile/features/health/presentation/widgets/health_settings_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_health_data_source.dart';

/// LE RÉGLAGE « SANTÉ CONNECTÉE » : l'interrupteur et ses quatre issues —
/// accordé, refusé, Health Connect à installer, téléphone qui ne le permet
/// pas — plus l'autorisation retirée après coup et l'objectif de pas.
void main() {
  late FakeHealthDataSource source;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    source = FakeHealthDataSource();
  });

  Future<void> monte(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          healthDataSourceProvider.overrideWithValue(source),
          healthAccountIdProvider.overrideWithValue('user-1'),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(child: HealthSettingsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool bascule(WidgetTester tester) =>
      tester.widget<Switch>(find.byType(Switch)).value;

  Future<void> active(WidgetTester tester) async {
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
  }

  testWidgets('non connecté : la ligne et sa bascule, rien d’autre', (
    tester,
  ) async {
    await monte(tester);

    expect(find.text('SANTÉ CONNECTÉE'), findsOneWidget);
    expect(find.text('Health Connect'), findsOneWidget);
    expect(bascule(tester), isFalse);
    expect(find.text('Objectif de pas'), findsNothing);
    expect(source.accessRequests, 0);
  });

  testWidgets('accordé : connecté, mémorisé, objectif de 8 000 pas', (
    tester,
  ) async {
    await monte(tester);
    await active(tester);

    expect(source.accessRequests, 1);
    expect(bascule(tester), isTrue);
    expect(find.text('Objectif de pas'), findsOneWidget);
    expect(find.text('${formatThousands(8000)} pas'), findsOneWidget);
    expect(await const HealthPrefsStore().isConnected('user-1'), isTrue);
  });

  testWidgets('refusé : l’explication et la marche à suivre, puis la ligne '
      'qui y ramène', (tester) async {
    source.grants = false;
    await monte(tester);
    await active(tester);

    expect(find.text('Accès refusé'), findsOneWidget);
    expect(
      find.textContaining('Autorisations des applications'),
      findsOneWidget,
    );
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();

    expect(bascule(tester), isFalse);
    expect(
      find.text('Accès refusé : voir comment l’autoriser'),
      findsOneWidget,
    );
    expect(await const HealthPrefsStore().isConnected('user-1'), isFalse);

    // Réessayer depuis la ligne : accordé cette fois.
    source.grants = true;
    await tester.tap(find.text('Accès refusé : voir comment l’autoriser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(bascule(tester), isTrue);
  });

  testWidgets('Android sans Health Connect : le dire, proposer de '
      'l’installer', (tester) async {
    source.available = HealthAvailability.needsInstall;
    await monte(tester);
    await active(tester);

    expect(find.text('Health Connect à installer'), findsOneWidget);
    await tester.tap(find.text('Installer Health Connect'));
    await tester.pumpAndSettle();

    expect(source.installRequests, 1);
    expect(source.accessRequests, 0);
    expect(find.text('Health Connect n’est pas installé'), findsOneWidget);
  });

  testWidgets('téléphone qui ne le permet pas : indisponible, sans demande', (
    tester,
  ) async {
    source.available = HealthAvailability.unsupported;
    await monte(tester);
    await active(tester);

    expect(source.accessRequests, 0);
    expect(bascule(tester), isFalse);
    expect(
      find.text('Health Connect ne fonctionne pas sur ce téléphone'),
      findsOneWidget,
    );
  });

  testWidgets('autorisation retirée dans Health Connect : refusée, pas '
      '« connectée » à zéro pas', (tester) async {
    await const HealthPrefsStore().setConnected('user-1', connected: true);
    source.grants = false;
    await monte(tester);

    expect(bascule(tester), isFalse);
    expect(
      find.text('Accès refusé : voir comment l’autoriser'),
      findsOneWidget,
    );
  });

  testWidgets('l’objectif se règle, borné, et se mémorise', (tester) async {
    await monte(tester);
    await active(tester);

    await tester.tap(find.text('Objectif de pas'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '500');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Entre ${formatThousands(1000)} et'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), '10000');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('${formatThousands(10000)} pas'), findsOneWidget);
    expect(await const HealthPrefsStore().stepsGoal('user-1'), 10000);
  });

  testWidgets('désactiver : Carlys cesse de lire', (tester) async {
    await monte(tester);
    await active(tester);
    await active(tester);

    expect(bascule(tester), isFalse);
    expect(await const HealthPrefsStore().isConnected('user-1'), isFalse);
  });
}
