import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../workout_program/presentation/providers/program_providers.dart';
import '../../../workout_program/presentation/providers/training_goal_providers.dart';
import '../../../workout_program/presentation/providers/training_profile_providers.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../domain/entities/coach.dart';

/// Crée le programme qu'a proposé le coach, par les chemins EXISTANTS.
///
/// Le coach n'a choisi que des réglages. On les pose sur le profil
/// d'entraînement — les mêmes gestes que l'écran de préparation —, puis le
/// générateur de Carlys construit le programme, qui naît INACTIF : la
/// personne le relit avant de l'activer. Aucune écriture n'est inventée ici.
class CoachProgramActions {
  const CoachProgramActions(this._ref);

  static const _logger = AppLogger('CoachProgramActions');

  final Ref _ref;

  /// Rend l'identifiant du programme à ouvrir. Un profil incomplet (niveau
  /// ou matériel jamais renseignés) remonte en [ValidationException] : le
  /// serveur y nomme ce qui manque, l'écran le dit tel quel.
  Future<String> start(CoachProgramProposal proposal) async {
    // Déjà créé : y ramener, jamais en engendrer un second.
    final already = proposal.acceptedProgramId;
    if (already != null) return already;

    await _ref.read(trainingGoalActionsProvider).choose(proposal.goal);
    await _ref
        .read(trainingProfileActionsProvider)
        .setRhythm(
          weeklySessions: proposal.weeklySessions,
          minutes: proposal.sessionMinutes,
        );

    final programId = await _ref.read(programActionsProvider).generate();

    try {
      await _ref
          .read(coachRepositoryProvider)
          .markProgramProposalAccepted(
            proposalId: proposal.id,
            programId: programId,
          );
    } on AppException catch (error) {
      // Le programme existe : c'est une mesure qui manque, pas un échec.
      _logger.warning('Acceptation du programme non notée', error: error);
    }
    return programId;
  }
}

final coachProgramActionsProvider = Provider<CoachProgramActions>(
  CoachProgramActions.new,
);
