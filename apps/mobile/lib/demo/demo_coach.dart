/// Coach du MODE DÉMO (flavor `demo` uniquement) — aucun réseau, aucun modèle.
///
/// Le coach réel lit les données de l'utilisateur et interroge un modèle ;
/// sans serveur, ni l'un ni l'autre n'existe. Ce dépôt sert donc une
/// conversation d'exemple et **le dit** : la réponse annonce qu'elle est une
/// démonstration plutôt que de se faire passer pour un raisonnement.
///
/// Sans lui, l'onglet Coach de l'APK de démonstration serait un écran mort.
library;

import '../features/coaching/data/repositories/coach_session_launcher.dart';
import '../features/coaching/domain/entities/coach.dart';
import '../features/coaching/domain/repositories/coach_repository.dart';
import '../features/workout_session/domain/entities/workout.dart';
import '../features/workout_session/domain/repositories/workout_repository.dart';

/// Séance proposée en exemple, bâtie sur de vrais exercices du catalogue de
/// démonstration — les identifiants existent, la séance se lance vraiment.
CoachSessionProposal _demoProposal() {
  const sets = [
    CoachProposalSet(
      id: 'demo-proposal-set-1',
      exercisePosition: 0,
      exerciseId: 'developpe-couche',
      exerciseName: 'Développé couché',
      setPosition: 0,
      kind: SetKind.normal,
      targetReps: 8,
      targetWeightKg: 70,
      restSeconds: 120,
    ),
    CoachProposalSet(
      id: 'demo-proposal-set-2',
      exercisePosition: 0,
      exerciseId: 'developpe-couche',
      exerciseName: 'Développé couché',
      setPosition: 1,
      kind: SetKind.normal,
      targetReps: 8,
      targetWeightKg: 70,
      restSeconds: 120,
    ),
    CoachProposalSet(
      id: 'demo-proposal-set-3',
      exercisePosition: 1,
      exerciseId: 'tractions',
      exerciseName: 'Tractions',
      setPosition: 0,
      kind: SetKind.normal,
      targetReps: 6,
      restSeconds: 90,
    ),
    CoachProposalSet(
      id: 'demo-proposal-set-4',
      exercisePosition: 1,
      exerciseId: 'tractions',
      exerciseName: 'Tractions',
      setPosition: 1,
      kind: SetKind.normal,
      targetReps: 6,
      restSeconds: 90,
    ),
  ];

  return const CoachSessionProposal(
    id: 'demo-proposal',
    name: 'Haut du corps — format court',
    estimatedMinutes: 28,
    exercises: [
      CoachProposedExercise(
        name: 'Développé couché',
        setCount: 2,
        detail: '8 reps · 70 kg',
      ),
      CoachProposedExercise(name: 'Tractions', setCount: 2, detail: '6 reps'),
    ],
    sets: sets,
  );
}

class DemoCoachRepository implements CoachRepository {
  DemoCoachRepository();

  static const String _threadId = 'demo-coach-thread';
  static const int _dailyLimit = 30;

  final List<CoachMessage> _messages = [
    const CoachMessage(
      id: 'demo-coach-1',
      role: CoachRole.user,
      content: 'J’ai seulement 30 minutes aujourd’hui.',
    ),
    CoachMessage(
      id: 'demo-coach-2',
      role: CoachRole.assistant,
      content: 'On garde les deux mouvements principaux et on resserre les '
          'repos. Les charges ne bougent pas : c’est le volume qui tombe, '
          'pas l’intensité.',
      proposal: _demoProposal(),
    ),
  ];

  int _sent = 0;

  @override
  Future<List<CoachConversationSummary>> conversations() async => [
        CoachConversationSummary(
          id: _threadId,
          title: 'Séance courte',
          messagesCount: _messages.length,
          updatedAt: DateTime.now().toUtc(),
        ),
      ];

  @override
  Future<CoachConversationSummary> createConversation(String id) async =>
      CoachConversationSummary(
        id: id,
        messagesCount: 0,
        updatedAt: DateTime.now().toUtc(),
      );

  @override
  Future<CoachConversation> conversation(String id) async => CoachConversation(
        id: id,
        title: 'Séance courte',
        messages: List.unmodifiable(_messages),
      );

  @override
  Future<CoachReply> sendMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    // Le vrai coach met quelques secondes ; sans ce délai, l'indicateur de
    // frappe n'apparaîtrait jamais et l'écran mentirait sur son propre rythme.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    final question = CoachMessage(
      id: messageId,
      role: CoachRole.user,
      content: content,
    );
    final answer = CoachMessage(
      id: 'demo-answer-$_sent',
      role: CoachRole.assistant,
      content: 'Mode démonstration : je réponds sans serveur et sans lire tes '
          'données. Voici tout de même à quoi ressemble une séance adaptée.',
      proposal: _demoProposal(),
    );

    _messages.addAll([question, answer]);
    _sent++;

    return CoachReply(
      userMessage: question,
      assistantMessage: answer,
      remainingToday: (_dailyLimit - _sent).clamp(0, _dailyLimit),
    );
  }

  @override
  Future<void> markProposalAccepted({
    required String proposalId,
    required String sessionId,
  }) async {}
}

/// Lance la séance proposée sur le dépôt de séances en mémoire : la démo n'a
/// pas de base locale, mais la séance doit vraiment s'ouvrir.
///
/// **Limite assumée** : le plan (cibles, repos) n'est pas matérialisé — le
/// dépôt de démonstration ne stocke pas de plan. La séance porte le nom de la
/// proposition et s'ouvre vide, comme une séance libre.
class DemoCoachSessionLauncher implements CoachSessionLauncher {
  const DemoCoachSessionLauncher(this._workouts);

  final WorkoutRepository _workouts;

  @override
  Future<String> start(CoachSessionProposal proposal) {
    return _workouts.startWorkout(name: proposal.name);
  }
}
