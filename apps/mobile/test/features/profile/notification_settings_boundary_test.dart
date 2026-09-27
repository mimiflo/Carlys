import 'dart:async';

import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_state.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/account_bound_cache.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/account_session.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/presentation/controllers/notification_preferences.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_settings_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// LES BASCULES DE NOTIFICATIONS À LA FRONTIÈRE DE SESSION.
///
/// On se déconnecte depuis l'écran même qui montre ces bascules. À l'entrée
/// du compte suivant, le cache repart de sa valeur VIDE — pas de celle du
/// compte parti — le temps de sa première lecture. Une carte vide, lue par
/// `valueOrNull`, se montrait pourtant comme trois bascules « acceptées »
/// que le serveur n'avait jamais dites ; et si cette lecture échouait, elles
/// restaient là, sans un mot sur l'échec.
void main() {
  late Future<Map<NotificationCategory, bool>> Function() lire;
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        notificationPreferencesProvider.overrideWith(
          () => AccountBoundCache((ref) => lire(), none: const {}),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> monte(WidgetTester tester) => tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        home: const AppDarkScaffold(
          body: SingleChildScrollView(child: NotificationSettingsSection()),
        ),
      ),
    ),
  );

  /// A se déconnecte, B se connecte : la lecture de B est en route.
  Future<Completer<Map<NotificationCategory, bool>>> changeDeCompte(
    WidgetTester tester,
  ) async {
    final lectureDeB = Completer<Map<NotificationCategory, bool>>();
    lire = () => lectureDeB.future;
    final session = container.read(accountSessionProvider.notifier);
    session.follow(const AuthUnauthenticated());
    await tester.pump();
    session.follow(const AuthAuthenticated());
    await tester.pump();
    return lectureDeB;
  }

  testWidgets('la lecture du compte suivant se tait tant qu’elle est en '
      'route', (tester) async {
    lire = () async => {NotificationCategory.friendRequests: false};
    await monte(tester);
    await tester.pumpAndSettle();
    expect(
      find.byType(Switch),
      findsNWidgets(NotificationCategory.values.length),
    );

    final lectureDeB = await changeDeCompte(tester);

    expect(find.byType(Switch), findsNothing);
    lectureDeB.complete(const {});
    await tester.pumpAndSettle();
    expect(
      find.byType(Switch),
      findsNWidgets(NotificationCategory.values.length),
    );
  });

  testWidgets('et son échec se dit, sans bascule inventée', (tester) async {
    lire = () async => {NotificationCategory.friendRequests: false};
    await monte(tester);
    await tester.pumpAndSettle();

    final lectureDeB = await changeDeCompte(tester);
    lectureDeB.completeError(const NetworkException('Pas de réseau'));
    await tester.pumpAndSettle();

    expect(find.byType(Switch), findsNothing);
    expect(find.text('Hors connexion'), findsOneWidget);
  });
}
