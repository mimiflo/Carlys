import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/notifications/data/repositories/device_token_repository_impl.dart';
import 'package:carlys_mobile/features/notifications/data/services/firebase_push_messenger.dart';
import 'package:carlys_mobile/features/notifications/domain/repositories/device_token_repository.dart';
import 'package:carlys_mobile/features/notifications/domain/services/push_messenger.dart';
import 'package:carlys_mobile/features/notifications/presentation/controllers/notification_preferences.dart';
import 'package:carlys_mobile/features/notifications/presentation/widgets/push_foreground_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_push_messenger.dart';

/// CE QU'ON ACCEPTE DE RECEVOIR, et ce qui arrive quand on est déjà là.
///
/// Deux exigences distinctes : le refus doit partir au SERVEUR, seul capable
/// de couper l'envoi ; et une notification reçue pendant qu'on utilise
/// l'application doit se voir, puisque le système ne l'affiche pas lui-même
/// dans ce cas.
class _Repository implements DeviceTokenRepository {
  _Repository({Map<NotificationCategory, bool>? initial})
    : stored = {...?initial};

  final Map<NotificationCategory, bool> stored;
  final List<(NotificationCategory, bool)> writes = [];

  @override
  Future<Map<NotificationCategory, bool>> preferences() async => stored;

  @override
  Future<void> setPreference(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    writes.add((category, enabled));
    stored[category] = enabled;
  }

  @override
  Future<void> register({
    required String token,
    required DevicePlatform platform,
  }) async {}

  @override
  Future<void> unregister(String token) async {}
}

/// Sans configuration Firebase : aucune notification n'a lancé l'application.
const _environment = AppEnvironment(
  flavor: AppFlavor.development,
  apiBaseUrl: 'http://localhost:3000',
);

/// Rapport de contraste WCAG entre deux couleurs opaques.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final light = first > second ? first : second;
  final dark = first > second ? second : first;
  return (light + 0.05) / (dark + 0.05);
}

void main() {
  group('préférences', () {
    test('une catégorie jamais réglée est ACCEPTÉE, sans écriture', () async {
      // Personne ne doit ouvrir les réglages pour que l'application se
      // comporte normalement.
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          deviceTokenRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final preferences = await container.read(
        notificationPreferencesProvider.future,
      );

      expect(preferences[NotificationCategory.encouragements], isNull);
      expect(repository.writes, isEmpty);
    });

    test('refuser une famille part au SERVEUR, et relit après', () async {
      // Une préférence gardée sur le téléphone laisserait la notification
      // arriver quand même : elle ne servirait à rien.
      final repository = _Repository();
      final container = ProviderContainer(
        overrides: [
          deviceTokenRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      await container.read(notificationPreferencesProvider.future);

      await container
          .read(notificationPreferenceActionsProvider)
          .set(NotificationCategory.encouragements, enabled: false);

      expect(repository.writes.single, (
        NotificationCategory.encouragements,
        false,
      ));
      final reread = await container.read(
        notificationPreferencesProvider.future,
      );
      expect(reread[NotificationCategory.encouragements], isFalse);
    });
  });

  group('réception application ouverte', () {
    testWidgets('une notification reçue se VOIT', (tester) async {
      final messenger = FakePushMessenger(token: null);
      addTearDown(messenger.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appEnvironmentProvider.overrideWithValue(_environment),
            pushMessengerProvider.overrideWithValue(messenger),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const PushForegroundHost(
              child: Scaffold(body: SizedBox.shrink()),
            ),
          ),
        ),
      );

      messenger.notices.add(
        const PushNotice(
          title: 'Encouragement de Léa',
          body: 'Ta série tient bon.',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Encouragement de Léa'), findsOneWidget);
      expect(find.text('Ta série tient bon.'), findsOneWidget);

      // Au MILIEU de l'écran, dans la carte des popups de l'application :
      // plus un bandeau clair posé en bas, hors thème.
      final card = tester.getCenter(find.byType(AppPopupCard));
      final screen = tester.getCenter(find.byType(Scaffold));
      expect((card - screen).distance, lessThan(1));

      // Et se LIT : chaque texte tient AA sur la surface de la carte.
      final surface = tester
          .widget<Material>(
            find
                .descendant(
                  of: find.byType(AppPopupCard),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color!;
      for (final text in ['Encouragement de Léa', 'Ta série tient bon.']) {
        final ink = tester.widget<Text>(find.text(text)).style!.color!;
        expect(
          _contrast(ink, surface),
          greaterThanOrEqualTo(4.5),
          reason: '« $text » sur la carte',
        );
      }
    });

    testWidgets('deux d’affilée n’empilent pas deux popups', (tester) async {
      final messenger = FakePushMessenger(token: null);
      addTearDown(messenger.close);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appEnvironmentProvider.overrideWithValue(_environment),
            pushMessengerProvider.overrideWithValue(messenger),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const PushForegroundHost(
              child: Scaffold(body: SizedBox.shrink()),
            ),
          ),
        ),
      );

      messenger.notices
        ..add(const PushNotice(title: 'Première', body: ''))
        ..add(const PushNotice(title: 'Seconde', body: ''));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AppPopupCard), findsOneWidget);
      expect(find.text('Seconde'), findsOneWidget);
      expect(find.text('Première'), findsNothing);
    });
  });
}
