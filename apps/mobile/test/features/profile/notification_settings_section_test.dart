import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/account_bound_cache.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/presentation/providers/notification_preferences.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_settings_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// LA SECTION NOTIFICATIONS DES RÉGLAGES, dans ses trois états.
///
/// Elle disparaissait « quand le serveur ne répond pas » : `valueOrNull`
/// confondait le chargement et l'ÉCHEC. Hors connexion, la section n'existait
/// simplement pas, sans un mot — on pouvait conclure que l'application
/// n'avait pas de réglage de notifications. Le même défaut, sur le catalogue
/// d'offres, laissait croire que Premium ne se vendait pas. L'attente garde
/// son silence ; l'échec, lui, se dit, avec un geste pour relire.
void main() {
  Widget monte(Future<Map<NotificationCategory, bool>> Function() lire) =>
      ProviderScope(
        overrides: [
          notificationPreferencesProvider.overrideWith(
            () => AccountBoundCache((ref) => lire(), none: const {}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SingleChildScrollView(child: NotificationSettingsSection()),
          ),
        ),
      );

  testWidgets('hors connexion, la section le dit, et relit au geste', (
    tester,
  ) async {
    var lectures = 0;
    await tester.pumpWidget(
      monte(() {
        lectures++;
        return Future.error(const NetworkException('Pas de réseau'));
      }),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Hors connexion'), findsOneWidget);
    expect(lectures, 1);

    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(lectures, 2);
  });

  testWidgets('un autre échec se dit aussi', (tester) async {
    await tester.pumpWidget(
      monte(
        () => Future.error(const ServerException('Erreur', statusCode: 500)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Indisponible pour l’instant'), findsOneWidget);
  });

  testWidgets('pendant le chargement, rien ne s’affiche', (tester) async {
    final jamais = Completer<Map<NotificationCategory, bool>>();
    await tester.pumpWidget(monte(() => jamais.future));
    await tester.pump();

    expect(find.text('NOTIFICATIONS'), findsNothing);
  });

  testWidgets('servies, les préférences donnent une bascule par famille', (
    tester,
  ) async {
    await tester.pumpWidget(monte(() async => const {}));
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(
      find.byType(Switch),
      findsNWidgets(NotificationCategory.values.length),
    );
  });
}
