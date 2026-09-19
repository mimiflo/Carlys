import 'package:carlys_mobile/app/environment/app_environment.dart';
import 'package:carlys_mobile/core/database/local_account_switch.dart';
import 'package:carlys_mobile/features/authentication/data/repositories/auth_repository_impl.dart';
import 'package:carlys_mobile/features/authentication/domain/entities/auth_user.dart';
import 'package:carlys_mobile/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:carlys_mobile/features/carlys_profile/data/repositories/carlys_profile_repository_impl.dart';
import 'package:carlys_mobile/features/carlys_profile/domain/entities/carlys_profile.dart';
import 'package:carlys_mobile/features/onboarding/data/first_run_store.dart';
import 'package:carlys_mobile/features/onboarding/domain/onboarding_answers.dart';
import 'package:carlys_mobile/features/onboarding/presentation/controllers/first_run_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_carlys_profile_repository.dart';

/// CE QUE CE FICHIER PROTÈGE : un choix RÉCENT ne se fait pas écraser par une
/// réponse d'onboarding restée en attente.
///
/// Au démarrage, la restauration de session pose `AuthAuthenticated()` SANS
/// profil, puis le remplace une fois `me()` revenu. Ce premier état
/// déclenchait déjà le report : le garde-fou lisait un profil vide, croyait
/// le compte vierge, et réécrivait par-dessus une identité choisie
/// entre-temps — depuis les réglages, ou sur un autre appareil.

/// Auth de test dont le profil met un temps à revenir, comme un vrai réseau.
class _SlowMeAuth extends FakeAuthRepository {
  _SlowMeAuth({required super.user}) : super(storedSession: true);

  static const Duration delay = Duration(milliseconds: 50);

  @override
  Future<AuthUser> me() async {
    await Future<void>.delayed(delay);
    return super.me();
  }
}

/// Bascule de compte inerte : ce test ne juge pas la frontière de compte.
class _NoopSwitch implements LocalAccountSwitch {
  @override
  Future<void> claimDevice() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('le report ATTEND le profil du compte, il ne l’écrase pas', () async {
    SharedPreferences.setMockInitialValues({});
    // Une identité répondue hors ligne, restée en attente d'envoi.
    await const FirstRunStore().writeAnswers(
      const OnboardingAnswers(carlysProfile: CarlysProfile.stratege),
    );
    // Le compte, lui, en porte DÉJÀ une autre — choisie depuis, ailleurs.
    final auth = _SlowMeAuth(
      user: const AuthUser(
        id: 'user-1',
        email: 'camille@example.com',
        displayName: 'Camille',
        emailVerified: true,
        locale: 'fr',
        timezone: 'Europe/Paris',
        carlysProfile: CarlysProfile.athlete,
      ),
    );
    final carlys = FakeCarlysProfileRepository();
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        carlysProfileRepositoryProvider.overrideWithValue(carlys),
        localAccountSwitchProvider.overrideWithValue(_NoopSwitch()),
      ],
    );
    addTearDown(container.dispose);

    container.read(firstRunControllerProvider);
    await container.read(authControllerProvider.notifier).restore();
    // Le temps que tout report en vol se termine.
    await Future<void>.delayed(_SlowMeAuth.delay * 3);

    // Rien n'a été réécrit : le compte garde l'identité la plus récente.
    // Avant le correctif, le premier état sans profil faisait écrire
    // « stratège » par-dessus « athlète ».
    expect(carlys.chosen, isEmpty);
    // La réponse périmée est consommée une fois le profil connu : elle n'a
    // plus rien à apporter, et la garder la ferait rejouer à chaque
    // démarrage.
    expect(await const FirstRunStore().readAnswers(), isNull);
  });

  test('un compte SANS identité reçoit bien la réponse en attente', () async {
    // Contre-épreuve : attendre le profil ne doit pas bloquer le report
    // légitime, celui pour lequel ce mécanisme existe.
    SharedPreferences.setMockInitialValues({});
    await const FirstRunStore().writeAnswers(
      const OnboardingAnswers(carlysProfile: CarlysProfile.stratege),
    );
    final auth = _SlowMeAuth(
      user: const AuthUser(
        id: 'user-1',
        email: 'camille@example.com',
        displayName: 'Camille',
        emailVerified: true,
        locale: 'fr',
        timezone: 'Europe/Paris',
      ),
    );
    final carlys = FakeCarlysProfileRepository();
    final container = ProviderContainer(
      overrides: [
        appEnvironmentProvider.overrideWithValue(
          const AppEnvironment(
            flavor: AppFlavor.development,
            apiBaseUrl: 'http://localhost:3000',
          ),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        carlysProfileRepositoryProvider.overrideWithValue(carlys),
        localAccountSwitchProvider.overrideWithValue(_NoopSwitch()),
      ],
    );
    addTearDown(container.dispose);

    container.read(firstRunControllerProvider);
    await container.read(authControllerProvider.notifier).restore();
    await Future<void>.delayed(_SlowMeAuth.delay * 3);

    expect(carlys.chosen, [CarlysProfile.stratege]);
    expect(await const FirstRunStore().readAnswers(), isNull);
  });
}
