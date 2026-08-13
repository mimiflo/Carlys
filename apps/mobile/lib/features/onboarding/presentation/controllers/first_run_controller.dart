import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../../carlys_profile/presentation/controllers/carlys_profile_controllers.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../data/first_run_store.dart';
import '../../domain/first_run_step.dart';
import '../../domain/onboarding_answers.dart';

/// État du parcours de première ouverture.
class FirstRunState {
  const FirstRunState({required this.step, required this.restored});

  /// Avant lecture des préférences : l'étape réelle n'est pas encore connue.
  const FirstRunState.unknown()
      : step = FirstRunStep.welcome,
        restored = false;

  final FirstRunStep step;

  /// `false` tant que les préférences locales n'ont pas été lues.
  final bool restored;
}

/// Source de vérité du parcours de première ouverture : étape atteinte,
/// persistée, et report des réponses d'onboarding sur le profil dès qu'un
/// compte existe.
///
/// Le routeur en dérive ses redirections : aucun `push` impératif n'est
/// nécessaire pour enchaîner les étapes.
class FirstRunController extends Notifier<FirstRunState> {
  static const _logger = AppLogger('FirstRunController');

  bool _flushing = false;

  FirstRunStore get _store => ref.read(firstRunStoreProvider);

  @override
  FirstRunState build() {
    // Le compte peut naître à tout moment du tunnel (inscription) ou en
    // dehors (connexion) : les réponses en attente partent aussitôt.
    ref.listen(authControllerProvider, (previous, next) {
      if (next is AuthAuthenticated) {
        unawaited(_flushPendingAnswers());
      }
    });
    unawaited(_restore());
    return const FirstRunState.unknown();
  }

  /// Fin de l'onboarding : les réponses sont enregistrées tout de suite si
  /// un compte existe déjà, mises de côté sinon. L'échec d'enregistrement
  /// remonte à l'écran (qui l'affiche) ; l'étape n'avance alors pas.
  ///
  /// L'identité Carlys et le profil métabolique partent chacun vers leur
  /// endpoint : on n'écrit que ce qui a réellement été répondu.
  Future<void> submitOnboarding(OnboardingAnswers answers) async {
    if (!answers.isEmpty) {
      if (ref.read(authControllerProvider) is AuthAuthenticated) {
        if (answers.hasMetabolicAnswers) {
          await _saveProfile(answers);
        }
        if (answers.carlysProfile != null) {
          await _saveCarlysProfile(answers.carlysProfile!);
        }
      } else {
        await _rememberAnswers(answers);
      }
    }
    await completeOnboarding();
  }

  /// La page de marque est vue : au tour des questions de profil.
  Future<void> completeWelcome() => markReached(FirstRunStep.onboarding);

  /// L'onboarding est franchi (répondu ou passé) : au tour du compte.
  Future<void> completeOnboarding() => markReached(FirstRunStep.account);

  /// Premium proposé et tranché (souscription ou repli gratuit) : le
  /// parcours est terminé et ne se rejouera plus.
  Future<void> completeJourney() => markReached(FirstRunStep.done);

  /// Avance jusqu'à `step` — jamais en arrière, et idempotent.
  Future<void> markReached(FirstRunStep step) async {
    if (state.step.index >= step.index) {
      return;
    }
    state = FirstRunState(step: step, restored: true);
    try {
      await _store.writeStep(step);
    } on Exception catch (error) {
      _logger.warning(
        'Étape du parcours non enregistrée — elle sera reproposée',
        error: error,
      );
    }
  }

  Future<void> _restore() async {
    var step = FirstRunStep.welcome;
    try {
      step = await _store.readStep();
    } on Exception catch (error) {
      // Préférences illisibles : on repropose le parcours plutôt que de
      // sauter des étapes qui n'ont peut-être jamais été vues.
      _logger.warning('Étape du parcours illisible', error: error);
    }
    state = FirstRunState(step: step, restored: true);

    // Session déjà ouverte au démarrage : rien n'aura déclenché l'écoute.
    if (ref.read(authControllerProvider) is AuthAuthenticated) {
      await _flushPendingAnswers();
    }
  }

  Future<void> _rememberAnswers(OnboardingAnswers answers) async {
    try {
      await _store.writeAnswers(answers);
    } on Exception catch (error) {
      // Le parcours continue : le profil se complète aussi depuis Nutrition.
      _logger.warning('Réponses d’onboarding non conservées', error: error);
    }
  }

  Future<void> _flushPendingAnswers() async {
    if (_flushing) {
      return;
    }
    _flushing = true;
    try {
      final answers = await _store.readAnswers();
      if (answers == null || answers.isEmpty) {
        return;
      }
      if (answers.hasMetabolicAnswers) {
        await _saveProfile(answers);
      }
      if (answers.carlysProfile != null) {
        await _saveCarlysProfile(answers.carlysProfile!);
      }
      await _store.clearAnswers();
      _logger.info('Réponses d’onboarding reportées sur le profil');
    } on Exception catch (error) {
      // Hors ligne ou serveur indisponible : les réponses restent en
      // attente et repartiront à la prochaine ouverture de session.
      _logger.warning('Réponses d’onboarding non enregistrées', error: error);
    } finally {
      _flushing = false;
    }
  }

  /// L'enregistrement passe par le cas d'usage nutrition, maintenu vivant
  /// le temps de l'appel : `nutritionActionsProvider` est auto-disposé, et
  /// il rafraîchit le rapport métabolique une fois le profil écrit.
  Future<void> _saveProfile(OnboardingAnswers answers) async {
    final subscription = ref.listen(nutritionActionsProvider, (_, __) {});
    try {
      await subscription.read().saveProfile(answers.toProfileUpdate());
    } finally {
      subscription.close();
    }
  }

  /// L'identité Carlys suit le chemin normal du choix de profil
  /// (`PATCH /users/me` puis rafraîchissement de la session) ; le provider
  /// n'est pas auto-disposé, un simple `read` suffit.
  Future<void> _saveCarlysProfile(CarlysProfile profile) =>
      ref.read(carlysProfileActionsProvider).choose(profile);
}

final firstRunControllerProvider =
    NotifierProvider<FirstRunController, FirstRunState>(
  FirstRunController.new,
);

/// Étape EFFECTIVE du parcours, croisée avec l'état de session, ou `null`
/// tant qu'elle n'est pas connue (préférences en cours de lecture ou session
/// pas encore restaurée). Le routeur et l'écran d'abonnement s'y accordent.
final firstRunStepProvider = Provider<FirstRunStep?>((ref) {
  final firstRun = ref.watch(firstRunControllerProvider);
  final auth = ref.watch(authControllerProvider);
  if (!firstRun.restored || auth is AuthUnknown) {
    return null;
  }
  return firstRun.step.resolved(authenticated: auth is AuthAuthenticated);
});
