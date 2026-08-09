/// DTO du coach — parsing manuel du JSON de l'API.
///
/// Le regroupement des séries par exercice se fait **ici**, une fois : c'est
/// une transformation de données, pas un travail d'affichage à refaire à
/// chaque image.
library;

import '../../../../core/utilities/formatting.dart';
import '../../../workout_session/domain/entities/workout.dart';
import '../../domain/entities/coach.dart';

CoachProposalSet coachProposalSetFromJson(Map<String, dynamic> json) =>
    CoachProposalSet(
      id: json['id'] as String,
      exercisePosition: (json['exercisePosition'] as num).toInt(),
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      setPosition: (json['setPosition'] as num).toInt(),
      kind: SetKind.fromApi(json['kind'] as String? ?? 'NORMAL'),
      targetReps: (json['targetReps'] as num?)?.toInt(),
      targetWeightKg: (json['targetWeightKg'] as num?)?.toDouble(),
      restSeconds: (json['restSeconds'] as num?)?.toInt(),
    );

CoachSessionProposal coachProposalFromJson(Map<String, dynamic> json) {
  final sets = (json['items'] as List<dynamic>? ?? const [])
      .whereType<Map<String, dynamic>>()
      .map(coachProposalSetFromJson)
      .toList()
    ..sort(_byPosition);

  return CoachSessionProposal(
    id: json['id'] as String,
    name: json['name'] as String,
    estimatedMinutes: (json['estimatedMinutes'] as num).toInt(),
    exercises: groupProposalSets(sets),
    sets: sets,
    acceptedSessionId: json['acceptedSessionId'] as String?,
  );
}

int _byPosition(CoachProposalSet a, CoachProposalSet b) {
  final exercises = a.exercisePosition.compareTo(b.exercisePosition);
  return exercises != 0 ? exercises : a.setPosition.compareTo(b.setPosition);
}

/// Regroupe les séries à plat en une ligne par exercice, dans l'ordre du plan.
///
/// Le résumé décrit la série **la plus représentative** — la première série
/// normale, sinon la première tout court : une carte de proposition annonce un
/// format, elle ne détaille pas chaque série.
List<CoachProposedExercise> groupProposalSets(List<CoachProposalSet> sets) {
  final byPosition = <int, List<CoachProposalSet>>{};
  for (final set in sets) {
    byPosition.putIfAbsent(set.exercisePosition, () => []).add(set);
  }

  final positions = byPosition.keys.toList()..sort();
  return [
    for (final position in positions)
      if (byPosition[position] case final group? when group.isNotEmpty)
        CoachProposedExercise(
          name: group.first.exerciseName,
          setCount: group.length,
          detail: _detailOf(
            group.firstWhere(
              (set) => set.kind == SetKind.normal,
              orElse: () => group.first,
            ),
          ),
        ),
  ];
}

/// « 8 reps · 60 kg », « 12 reps », « 60 kg », ou vide quand le coach n'a fixé
/// aucune cible — un tiret inventé vaudrait moins que rien.
String _detailOf(CoachProposalSet set) {
  final parts = <String>[
    if (set.targetReps != null) '${set.targetReps} reps',
    if (set.targetWeightKg != null) '${formatDecimal(set.targetWeightKg!)} kg',
  ];
  return parts.join(' · ');
}

CoachMessage coachMessageFromJson(Map<String, dynamic> json) {
  final proposal = json['proposal'];
  return CoachMessage(
    id: json['id'] as String,
    role: CoachRole.fromApi(json['role'] as String),
    content: json['content'] as String,
    proposal: proposal is Map<String, dynamic>
        ? coachProposalFromJson(proposal)
        : null,
  );
}

CoachConversationSummary coachSummaryFromJson(Map<String, dynamic> json) =>
    CoachConversationSummary(
      id: json['id'] as String,
      title: json['title'] as String?,
      messagesCount: (json['messagesCount'] as num).toInt(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

CoachConversation coachConversationFromJson(Map<String, dynamic> json) =>
    CoachConversation(
      id: json['id'] as String,
      title: json['title'] as String?,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(coachMessageFromJson)
          .toList(),
    );

CoachReply coachReplyFromJson(Map<String, dynamic> json) => CoachReply(
      userMessage:
          coachMessageFromJson(json['userMessage'] as Map<String, dynamic>),
      assistantMessage: coachMessageFromJson(
        json['assistantMessage'] as Map<String, dynamic>,
      ),
      remainingToday: (json['remainingToday'] as num).toInt(),
    );
