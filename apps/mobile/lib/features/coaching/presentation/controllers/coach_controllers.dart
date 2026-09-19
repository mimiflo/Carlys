/// Providers du coach — **seule porte d'entrée de l'écran**.
///
/// Aucun widget n'appelle l'API : écran → contrôleur → repository.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../carlys_profile/presentation/controllers/carlys_profile_controllers.dart';
import '../../../progress/domain/entities/progress.dart';
import '../../../progress/presentation/controllers/progress_controllers.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../data/repositories/coach_session_launcher.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coach_thread_state.dart';
import '../../domain/services/coach_suggestions.dart';

// L'état du fil vit dans le domaine ; il se relit par ce fichier, comme
// avant, pour que l'écran et ses tests n'aient pas à changer d'import.
export '../../domain/entities/coach_thread_state.dart';

/// Le fil de discussion courant.
///
/// **Le fil n'est créé qu'au premier message.** Ouvrir l'onglet pour regarder
/// ne doit pas laisser derrière soi une conversation vide : l'identifiant est
/// généré sur l'appareil, gardé en local, et le fil naît côté serveur au
/// moment où il a quelque chose à contenir.
class CoachThread extends AutoDisposeAsyncNotifier<CoachThreadState> {
  static const Uuid _uuid = Uuid();

  /// Le fil existe côté serveur (créé, ou rapatrié depuis la liste).
  bool _created = false;

  @override
  Future<CoachThreadState> build() async {
    final repository = ref.watch(coachRepositoryProvider);
    final threads = await repository.conversations();

    if (threads.isEmpty) {
      _created = false;
      return CoachThreadState(
        conversation: CoachConversation(id: _uuid.v4(), messages: const []),
      );
    }

    _created = true;
    return CoachThreadState(
      conversation: await repository.conversation(threads.first.id),
    );
  }

  /// Envoie une question et attend la réplique.
  ///
  /// Rend `true` quand le message est parti — l'écran vide alors son champ de
  /// saisie. Sur échec, le texte reste : rien n'est perdu.
  Future<bool> send(String content) async {
    final trimmed = content.trim();
    final current = state.valueOrNull;
    if (trimmed.isEmpty || current == null || current.isSending) return false;

    state = AsyncData(
      current.copyWith(isSending: true, isOffline: false, clearNotice: true),
    );

    final repository = ref.read(coachRepositoryProvider);
    try {
      if (!_created) {
        await repository.createConversation(current.conversation.id);
        _created = true;
      }

      final reply = await repository.sendMessage(
        conversationId: current.conversation.id,
        messageId: _uuid.v4(),
        content: trimmed,
      );

      state = AsyncData(
        current.copyWith(
          conversation: CoachConversation(
            id: current.conversation.id,
            title: current.conversation.title,
            messages: [
              ...current.conversation.messages,
              reply.userMessage,
              reply.assistantMessage,
            ],
          ),
          isSending: false,
          remainingToday: reply.remainingToday,
        ),
      );
      return true;
    } on AppException catch (exception) {
      state = AsyncData(
        current.copyWith(
          isSending: false,
          isOffline: exception is NetworkException,
          notice: _noticeFor(exception),
        ),
      );
      return false;
    }
  }

  /// Rouvre le composeur après une coupure.
  ///
  /// POURQUOI CETTE MÉTHODE EXISTE. Le drapeau hors ligne ne se levait que
  /// dans `send()` — or hors ligne, le composeur ET les suggestions sont
  /// masqués, donc `send()` était devenu inatteignable : le coach restait
  /// muet jusqu'à ce qu'on quitte l'écran et qu'on le rouvre, réseau revenu
  /// ou pas. Une fonctionnalité payante condamnée par deux secondes de
  /// métro.
  void clearOffline() {
    final current = state.valueOrNull;
    if (current == null || !current.isOffline) {
      return;
    }
    state = AsyncData(current.copyWith(isOffline: false, clearNotice: true));
  }

  /// Texte utilisateur d'un refus du serveur. Hors ligne, le composeur dit
  /// déjà ce qu'il faut : pas de second message redondant.
  String? _noticeFor(AppException exception) {
    if (exception is NetworkException) return null;
    if (exception is ServerException) {
      return switch (exception.statusCode) {
        429 =>
          'Tu as atteint le nombre de messages du jour. '
              'Le coach revient demain.',
        503 => 'Le coach est momentanément indisponible.',
        _ => 'Le coach n’a pas pu répondre. Réessaie dans un instant.',
      };
    }
    return 'Le coach n’a pas pu répondre. Réessaie dans un instant.';
  }
}

final coachThreadProvider =
    AsyncNotifierProvider.autoDispose<CoachThread, CoachThreadState>(
      CoachThread.new,
    );

/// Lance la séance proposée et signale l'acceptation au serveur.
///
/// L'ordre compte : la séance est écrite en local **d'abord**. Si la note au
/// serveur échoue, l'utilisateur s'entraîne quand même — c'est une statistique
/// qui manque, pas une séance perdue.
class CoachProposalActions {
  const CoachProposalActions(this._ref);

  final Ref _ref;

  Future<String> start(CoachSessionProposal proposal) async {
    final sessionId = await _ref
        .read(coachSessionLauncherProvider)
        .start(proposal);

    try {
      await _ref
          .read(coachRepositoryProvider)
          .markProposalAccepted(proposalId: proposal.id, sessionId: sessionId);
    } on AppException {
      // Volontairement avalé : la séance existe, elle est en file de
      // synchronisation, et l'écran de séance s'ouvre. Rien à dire ici.
    }

    return sessionId;
  }
}

final coachProposalActionsProvider = Provider<CoachProposalActions>(
  CoachProposalActions.new,
);

/// Amorces de conversation, calculées depuis l'état réel de l'utilisateur.
///
/// Les trois sources sont déjà chargées par ailleurs (modèles en local,
/// records et poids en cache Riverpod) : la bande de puces n'ajoute aucun
/// appel réseau. Une source en échec ne fait pas échouer les autres — sans
/// donnée, il reste la puce générique.
final coachSuggestionsProvider = Provider.autoDispose<List<String>>((ref) {
  final templates = ref.watch(workoutTemplatesProvider).valueOrNull;
  final records = ref.watch(personalRecordsProvider).valueOrNull;
  final weights = ref.watch(bodyWeightMetricsProvider).valueOrNull;
  final history = ref.watch(workoutHistoryProvider).valueOrNull;

  final freshest = _freshestRecord(records);
  final now = DateTime.now().toUtc();

  return coachSuggestions(
    CoachContext(
      carlysProfile: ref.watch(currentCarlysProfileProvider),
      templateName: (templates == null || templates.isEmpty)
          ? null
          : templates.first.name,
      recordExerciseName: freshest?.exerciseName,
      recordAgeDays: freshest == null
          ? null
          : now.difference(freshest.achievedAt).inDays,
      weightTrendKg: _weightTrend(weights),
      hasHistory: history != null && history.isNotEmpty,
    ),
  );
});

PersonalRecordEntry? _freshestRecord(List<PersonalRecordEntry>? records) {
  if (records == null || records.isEmpty) return null;
  return records.reduce(
    (best, entry) => entry.achievedAt.isAfter(best.achievedAt) ? entry : best,
  );
}

/// Écart entre la dernière mesure et la précédente. `null` en deçà de deux
/// mesures : une seule pesée ne fait pas une tendance.
double? _weightTrend(List<BodyMetricEntry>? weights) {
  if (weights == null || weights.length < 2) return null;
  return weights.last.value - weights[weights.length - 2].value;
}
