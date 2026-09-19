import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../../carlys_profile/presentation/controllers/carlys_profile_controllers.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../workout_program/domain/entities/training_goal.dart';
import '../../../workout_program/presentation/controllers/training_goal_controllers.dart';
import '../../data/first_run_store.dart';
import '../../domain/first_run_step.dart';
import '../../domain/onboarding_answers.dart';

/// État du parcours de première ouverture.
class FirstRunState {
  const FirstRunState({required this.step, required this.restored});

  /// Avant lecture des préférences : l'étape réelle n'est pas encore connue.
  const FirstRunState.unknown() : step = FirstRunStep.welcome, restored = false;

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
  /// un compte existe déjà, mises de côté sinon — et le parcours avance
  /// TOUJOURS. Un enregistrement qui échoue (hors ligne, serveur
  /// indisponible) rejoint la même mise de côté que le chemin sans compte :
  /// les réponses repartiront via `_flushPendingAnswers`, jamais perdues,
  /// jamais bloquantes. C'est la parité offline-first du dépôt.
  ///
  /// L'identité Carlys et le profil métabolique partent chacun vers leur
  /// endpoint : on n'écrit que ce qui a réellement été répondu.
  Future<void> submitOnboarding(OnboardingAnswers answers) async {
    if (!answers.isEmpty) {
      if (ref.read(authControllerProvider) is AuthAuthenticated) {
        try {
          if (answers.hasMetabolicAnswers) {
            await _saveProfile(answers);
          }
          if (answers.carlysProfile != null) {
            await _saveCarlysProfile(answers.carlysProfile!);
          }
          if (answers.trainingGoal != null) {
            await _saveTrainingGoal(answers.trainingGoal!);
          }
        } on Exception catch (error) {
          // Réécrire plus tard ce qui a déjà abouti est sans danger : ces
          // enregistrements sont idempotents (mêmes valeurs, mêmes PATCH).
          _logger.warning(
            'Réponses d’onboarding mises de côté : enregistrement échoué',
            error: error,
          );
          await _rememberAnswers(answers);
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
        'Étape du parcours non enregistrée : elle sera reproposée',
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
      // Des réponses en attente peuvent être PLUS VIEILLES qu'un choix fait
      // entre-temps (depuis le profil, ou sur un autre appareil) : ce que le
      // compte porte déjà ne se réécrit pas.
      final auth = ref.read(authControllerProvider);
      if (auth is! AuthAuthenticated) {
        return;
      }
      final user = auth.user;
      if (user == null) {
        // LE PROFIL N'EST PAS ENCORE REVENU DU SERVEUR. Au démarrage, la
        // restauration pose `AuthAuthenticated()` sans profil, puis le
        // remplace une fois `me()` rendu — et ce premier état déclenchait
        // déjà ce report. Le garde-fou juste en dessous lisait alors un
        // profil vide, croyait le compte vierge, et réécrivait par-dessus
        // un choix plus RÉCENT fait ailleurs. On attend : les réponses
        // restent sur le disque, et l'arrivée du profil rappelle cette
        // méthode (l'écoute de session se redéclenche sur le nouvel état).
        _logger.info('Report différé : profil du compte pas encore lu');
        return;
      }
      if (answers.hasMetabolicAnswers) {
        await _saveProfile(answers);
      }
      if (answers.carlysProfile != null && user.carlysProfile == null) {
        await _saveCarlysProfile(answers.carlysProfile!);
      }
      if (answers.trainingGoal != null && user.trainingGoal == null) {
        await _saveTrainingGoal(answers.trainingGoal!);
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

  /// L'enregistrement passe par le cas d'usage nutrition, qui rafraîchit le
  /// rapport métabolique une fois le profil écrit. `nutritionActionsProvider`
  /// n'est PAS auto-disposé (comme toutes les actions) : un simple `read`
  /// suffit — la danse `listen`/`close` qui vivait ici gardait en vie un
  /// provider qui ne meurt jamais.
  Future<void> _saveProfile(OnboardingAnswers answers) =>
      ref.read(nutritionActionsProvider).saveProfile(answers.toProfileUpdate());

  /// L'identité Carlys suit le chemin normal du choix de profil
  /// (`PATCH /users/me` puis rafraîchissement de la session) ; le provider
  /// n'est pas auto-disposé, un simple `read` suffit.
  Future<void> _saveCarlysProfile(CarlysProfile profile) =>
      ref.read(carlysProfileActionsProvider).choose(profile);

  /// L'objectif d'entraînement suit le même chemin que l'identité :
  /// `PATCH /users/me` puis rafraîchissement de la session.
  Future<void> _saveTrainingGoal(TrainingGoal goal) =>
      ref.read(trainingGoalActionsProvider).choose(goal);
}

final firstRunControllerProvider =
    NotifierProvider<FirstRunController, FirstRunState>(FirstRunController.new);

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
