/// À qui le coach dit bonjour — un provider DÉRIVÉ, sans Notifier.
///
/// Le bonjour (`coachGreeting`) ne lit que le nom affiché et la voix du
/// Mentor : l'écran du coach n'a pas à connaître toute la session pour ça,
/// et ses tests remplacent ce seul provider.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../mentor/domain/entities/mentor_style.dart';

typedef CoachVoice = ({String? displayName, MentorStyle? style});

final coachVoiceProvider = Provider<CoachVoice>((ref) {
  final user = switch (ref.watch(authControllerProvider)) {
    AuthAuthenticated(:final user) => user,
    _ => null,
  };
  return (displayName: user?.displayName, style: user?.mentorStyle);
});
