import 'dart:async';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/account_session.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/community/data/repositories/community_repository_impl.dart';
import 'package:carlys_mobile/features/community/presentation/providers/community_providers.dart';
import 'package:carlys_mobile/features/community/presentation/widgets/privacy_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_community_repository.dart';

class _Session extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(user: fakeUser);
}

/// L'interrupteur « Partager ma progression » bascule SOUS LE DOIGT : il
/// attendait l'écriture PUIS une relecture — deux allers-retours avant de
/// bouger. Le serveur confirme ensuite, ou l'interrupteur se remet.
void main() {
  late FakeCommunityRepository community;
  late ProviderContainer container;

  setUp(() async {
    community = FakeCommunityRepository()..sharesGate = Completer<void>();
    container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_Session.new),
        communityRepositoryProvider.overrideWithValue(community),
      ],
    );
    addTearDown(container.dispose);
    container.listen(sharesProgressProvider, (_, _) {});
    await container.read(sharesProgressProvider.future);
  });

  bool? shown() => container.read(sharesProgressProvider).valueOrNull;
  CommunityActions actions() => container.read(communityActionsProvider);

  test('la bascule se voit avant la réponse, et y reste', () async {
    final bascule = actions().setSharesProgress(value: false);

    expect(shown(), isFalse);
    community.sharesGate!.complete();
    await bascule;
    expect(shown(), isFalse);
    expect(community.sharesWrites, [false]);
  });

  test('une bascule refusée se remet, l’échec remonte', () async {
    community.failSharesWrite = true;
    final bascule = actions().setSharesProgress(value: false);
    expect(shown(), isFalse);

    community.sharesGate!.complete();
    await expectLater(bascule, throwsA(anything));
    expect(shown(), isTrue);
    expect(community.shares, isTrue);
  });

  test('deux bascules d’affilée : la dernière tient, dans l’ordre', () async {
    final premiere = actions().setSharesProgress(value: false);
    final seconde = actions().setSharesProgress(value: true);
    expect(shown(), isTrue);

    community.sharesGate!.complete();
    await Future.wait([premiere, seconde]);
    expect(community.sharesWrites, [false, true]);
    expect(shown(), isTrue);
  });

  test('changement de compte pendant une écriture : le geste du suivant '
      'part, et lui seul est montré', () async {
    final premier = actions().setSharesProgress(value: false);
    // A part, B arrive — l'écriture de A est encore en vol.
    final session = container.read(accountSessionProvider.notifier)
      ..follow(const AuthUnauthenticated());
    session.follow(const AuthAuthenticated(user: fakeUser));
    await container.read(sharesProgressProvider.future);
    final second = actions().setSharesProgress(value: false);

    community.sharesGate!.complete();
    await Future.wait([premier, second]);
    // L'écriture de A, pas encore partie, ne part pas avec le jeton de B ;
    // celle de B part. Avant : la file gardait la session de A, et la
    // bascule de B s'arrêtait sans rien envoyer, sans erreur.
    expect(community.sharesWrites, [false]);
    expect(shown(), isFalse);
  });

  testWidgets('lecture ratée : la carte le dit et réessaie', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: PrivacyCard(
            sharesProgress: null,
            onChanged: (_) {},
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Ton réglage n’a pas pu être lu.'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.byTooltip('Réessayer'));
    expect(retries, 1);
  });
}
