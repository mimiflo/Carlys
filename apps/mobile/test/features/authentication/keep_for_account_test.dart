import 'package:carlys_mobile/features/authentication/domain/entities/auth_state.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/account_session.dart';
import 'package:carlys_mobile/features/authentication/presentation/providers/keep_for_account.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Une lecture gardée deux minutes : un onglet quitté puis repris ne la
/// relance plus — sans garder un échec, ni la donnée d'un autre compte.
void main() {
  late int lectures;
  late bool echoue;
  final lu = FutureProvider.autoDispose<int>((ref) {
    lectures++;
    return keepForAccount(
      ref,
      () => echoue
          ? Future<int>.error(StateError('hors ligne'))
          : Future.value(lectures),
    );
  });

  setUp(() {
    lectures = 0;
    echoue = false;
  });

  Future<void> lire(ProviderContainer c) async {
    final sub = c.listen(lu, (_, _) {});
    try {
      await c.read(lu.future);
    } on StateError {
      // L'échec voulu par le test.
    }
    sub.close();
    await Future<void>.delayed(Duration.zero);
  }

  test('un retour dans les deux minutes : servi sans nouvelle requête', () {
    fakeAsync((async) {
      final c = ProviderContainer();
      lire(c);
      async.elapse(Duration.zero);
      async.elapse(const Duration(seconds: 30));
      lire(c);
      async.elapse(Duration.zero);
      expect(lectures, 1);

      async.elapse(const Duration(minutes: 3));
      lire(c);
      async.elapse(Duration.zero);
      expect(lectures, 2);
      c.dispose();
    });
  });

  test('un échec n’est jamais gardé : le retour réessaie', () {
    fakeAsync((async) {
      final c = ProviderContainer();
      echoue = true;
      lire(c);
      async.elapse(Duration.zero);
      echoue = false;
      lire(c);
      async.elapse(Duration.zero);
      expect(lectures, 2);
      c.dispose();
    });
  });

  test('un autre compte : relu, jamais la donnée du précédent', () {
    fakeAsync((async) {
      final c = ProviderContainer();
      lire(c);
      async.elapse(Duration.zero);
      final session = c.read(accountSessionProvider.notifier)
        ..follow(const AuthUnauthenticated());
      session.follow(const AuthAuthenticated());
      lire(c);
      async.elapse(Duration.zero);
      expect(lectures, 2);
      c.dispose();
    });
  });
}
