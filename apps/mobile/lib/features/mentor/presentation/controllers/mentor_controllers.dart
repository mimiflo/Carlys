import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../progression/domain/reward.dart';
import '../../../progression/presentation/controllers/reward_controllers.dart';
import '../../data/mentor_prefs_store.dart';
import '../../data/repositories/mentor_repository_impl.dart';
import '../../domain/entities/mentor_prefs.dart';
import '../../domain/entities/mentor_style.dart';
import '../../domain/mentor_tour.dart';
import '../../domain/mentor_word.dart';

/// Choix de la voix : écrit au serveur PUIS rafraîchit l'utilisateur — la
/// sélection affichée vient toujours de `AuthUser.mentorStyle`, une seule
/// source de vérité, comme pour le profil Carlys.
///
/// `Provider` simple (PAS autoDispose) : la référence est capturée dans des
/// callbacks tardifs — même leçon que les actions communauté.
class MentorActions {
  static const _logger = AppLogger('MentorActions');

  MentorActions(this._ref);

  final Ref _ref;

  Future<void> chooseStyle(MentorStyle style) async {
    await _ref.read(mentorRepositoryProvider).chooseStyle(style);
    // Le choix serveur a RÉUSSI : un rafraîchissement de session qui échoue
    // juste après ne doit pas le déguiser en échec du choix. Meilleur
    // effort — l'affichage se remettra au prochain rafraîchissement.
    try {
      await _ref.read(authControllerProvider.notifier).refreshProfile();
    } on Exception catch (error) {
      _logger.warning('Session non rafraîchie après le choix', error: error);
    }
  }

  Future<void> setInterventionsActives({required bool actives}) async {
    await _ref
        .read(mentorPrefsStoreProvider)
        .setInterventionsActives(actives: actives);
    _ref.invalidate(mentorPrefsProvider);
  }

  Future<void> setFrequence(MentorFrequency frequence) async {
    await _ref.read(mentorPrefsStoreProvider).setFrequence(frequence);
    _ref.invalidate(mentorPrefsProvider);
  }

  Future<void> marquerEtapeVue(String stepId) async {
    await _ref.read(mentorPrefsStoreProvider).marquerEtapeVue(stepId);
    _ref.invalidate(mentorTourVuesProvider);
  }

  Future<void> rejouerVisite() async {
    await _ref.read(mentorPrefsStoreProvider).reinitialiserVisite();
    _ref.invalidate(mentorTourVuesProvider);
  }

  Future<void> marquerCelebrationDite(String rewardId) async {
    await _ref.read(mentorPrefsStoreProvider).marquerCelebrationDite(rewardId);
    _ref.invalidate(mentorCelebrationsDitesProvider);
  }
}

final mentorActionsProvider = Provider<MentorActions>(MentorActions.new);

/// Préférences d'intervention, lues une fois puis invalidées à l'écriture.
/// Non auto-disposé : l'accueil et le profil les lisent tous deux.
final mentorPrefsProvider = FutureProvider<MentorPrefs>((ref) {
  return ref.read(mentorPrefsStoreProvider).read();
});

/// Étapes de la visite déjà vues sur cet appareil.
final mentorTourVuesProvider = FutureProvider<Set<String>>((ref) {
  return ref.read(mentorPrefsStoreProvider).readVisiteVues();
});

/// Où en est la visite — dérivé pur, `null` tant que rien n'est lu.
final mentorTourProgressProvider = Provider<MentorTourProgress?>((ref) {
  final vues = ref.watch(mentorTourVuesProvider).valueOrNull;
  return vues == null ? null : computeMentorTour(vues);
});

/// Récompenses que le Mentor a déjà dites — son journal de déduplication.
final mentorCelebrationsDitesProvider = FutureProvider<Set<String>>((ref) {
  return ref.read(mentorPrefsStoreProvider).readCelebrationsDites();
});

/// Le MOT du Mentor pour l'accueil, ou `null` quand il se tait (interventions
/// coupées, ou préférences pas encore lues).
///
/// La célébration passe devant le mot ordinaire : la récompense la plus
/// récente dont `isNew` est vrai — le franchissement de CETTE session, la
/// garde de première lecture du journal étant déjà passée — et que le Mentor
/// n'a pas déjà dite. Toucher l'entrée la marque « dite ».
final mentorWordProvider = Provider<MentorWord?>((ref) {
  final prefs = ref.watch(mentorPrefsProvider).valueOrNull;
  if (prefs == null || !prefs.interventionsActives) {
    return null;
  }
  final style = ref.watch(currentMentorStyleProvider);
  final dites = ref.watch(mentorCelebrationsDitesProvider).valueOrNull ?? {};
  final recompenses = ref.watch(earnedRewardsProvider).valueOrNull ?? const [];
  final aFeter = recompenses
      .where(
        (EarnedReward earned) =>
            earned.isNew && !dites.contains(earned.reward.id),
      )
      .firstOrNull;
  return mentorWord(
    style: style,
    frequence: prefs.frequence,
    now: DateTime.now(),
    aFeter: aFeter,
  );
});

/// Voix du Mentor de l'utilisateur courant, ou `null` tant qu'elle n'est
/// pas choisie : `null` signifie « la voix neutre du coach », jamais un
/// style deviné.
final currentMentorStyleProvider = Provider<MentorStyle?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return switch (auth) {
    AuthAuthenticated(:final user) => user?.mentorStyle,
    _ => null,
  };
});
