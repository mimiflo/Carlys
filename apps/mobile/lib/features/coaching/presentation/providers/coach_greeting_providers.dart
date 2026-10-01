/// L'ouverture de l'écran du coach : à qui il dit bonjour, quand, et les
/// amorces qu'il montre. Des providers DÉRIVÉS et deux décisions, sans
/// Notifier.
///
/// Le bonjour (`coachGreeting`) ne lit que le nom affiché et la voix du
/// Mentor : l'écran du coach n'a pas à connaître toute la session pour ça,
/// et ses tests remplacent ce seul provider.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/utilities/formatting.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../mentor/domain/entities/mentor_style.dart';
import '../../data/coach_greeting_store.dart';
import '../../domain/entities/coach_thread_state.dart';
import '../../domain/services/coach_greeting.dart';
import '../../domain/services/coach_suggestions.dart';
import 'coach_suggestion_providers.dart';

typedef CoachVoice = ({String? displayName, MentorStyle? style});

final coachVoiceProvider = Provider<CoachVoice>((ref) {
  final user = ref.watch(authControllerProvider).user;
  return (displayName: user?.displayName, style: user?.mentorStyle);
});

final coachGreetingStoreProvider = Provider<CoachGreetingStore>(
  (ref) => const CoachGreetingStore(),
);

/// Le jour du dernier bonjour, RELU à chaque ouverture de l'écran (d'où
/// `autoDispose`) : un bonjour dit le matin ne se redit pas le soir.
final coachLastGreetingDayProvider = FutureProvider.autoDispose<String?>(
  (ref) => ref.watch(coachGreetingStoreProvider).lastDay(),
);

const _logger = AppLogger('CoachOpening');

/// Les amorces lancent la conversation du JOUR : dès la première question
/// partie (ou déjà posée aujourd'hui), elles s'effacent jusqu'au lendemain.
List<String> coachVisibleSuggestions(WidgetRef ref, CoachThreadState state) {
  final suggestions = ref.watch(coachSuggestionsProvider);
  final started =
      state.live != null ||
      coachWroteToday(state.conversation.messages, DateTime.now());
  return started ? const [] : suggestions;
}

/// Un bonjour par jour AU PLUS (`shouldGreet`) : pas une seconde fois en
/// rouvrant l'écran, pas du tout si l'on a déjà écrit aujourd'hui. Ni à
/// qui ne peut pas écrire (lecture seule, hors ligne) : il inviterait à
/// une question que le coach ne recevra pas.
///
/// `decided` : la question est tranchée pour CETTE ouverture, et ne se
/// repose plus (sans quoi un écran resté ouvert passé minuit dirait bonjour
/// au milieu de la conversation). Hors ligne ou le souvenir pas encore
/// relu, elle reste ouverte.
({bool decided, CoachGreeting? greeting}) coachOpeningGreeting(
  WidgetRef ref,
  CoachThreadState state,
) {
  const wait = (decided: false, greeting: null);
  const none = (decided: true, greeting: null);
  if (state.isReadOnly) return none;
  if (state.isOffline) return wait;
  final last = ref.watch(coachLastGreetingDayProvider);
  // Le souvenir pas encore relu : on attend, plutôt que de redire bonjour.
  if (!last.hasValue) return wait;
  final messages = state.conversation.messages;
  final now = DateTime.now();
  final greet = shouldGreet(
    lastGreetedDay: last.value,
    wroteToday: coachWroteToday(messages, now),
    now: now,
  );
  if (!greet) return none;
  unawaited(
    ref
        .read(coachGreetingStoreProvider)
        .greeted(formatDayKey(now))
        .catchError(
          (Object error) => _logger.warning(
            'Bonjour du coach non retenu : il pourra se redire',
            error: error,
          ),
        ),
  );
  final voice = ref.read(coachVoiceProvider);
  return (
    decided: true,
    greeting: CoachGreeting(
      text: coachGreeting(
        displayName: voice.displayName,
        style: voice.style,
        returning: messages.isNotEmpty,
        now: now,
      ),
      after: messages.length,
      at: now,
    ),
  );
}
