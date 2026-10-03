/// L'ouverture du fil : le plus récent, ou un fil neuf qui n'existe encore
/// que sur l'appareil — et le droit d'y écrire, tel que le SERVEUR le tient.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../subscription/data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coach_thread_state.dart';
import '../../domain/repositories/coach_repository.dart';

const _uuid = Uuid();
const _logger = AppLogger('CoachThread');
const _reserved = 'Le coach est réservé aux abonnés.';

/// `created` : le fil existe côté serveur (sinon, il naîtra au premier
/// message). La LECTURE de ses conversations reste ouverte à qui les a
/// écrites, abonné ou non : les CGU promettent que ce qui a été créé avec le
/// Premium reste consultable.
Future<({CoachThreadState state, bool created})> loadCoachThread(
  Ref ref,
  CoachRepository repository,
) async {
  // Le droit se lit PENDANT la liste et le fil (deux allers-retours au
  // lieu de trois) ; `_mayWrite` ne lève jamais, rien ne fuit.
  final mayWrite = _mayWrite(ref);
  final threads = await repository.conversations();

  if (threads.isEmpty) {
    // Rien à relire ni à écrire : l'invitation, pas un fil qui refuserait.
    if (!await mayWrite) {
      throw const ForbiddenException(_reserved, statusCode: 403);
    }
    final fresh = CoachConversation(id: _uuid.v4(), messages: const []);
    return (state: CoachThreadState(conversation: fresh), created: false);
  }

  final conversation = await repository.conversation(threads.first.id);
  return (
    state: CoachThreadState(
      conversation: conversation,
      isReadOnly: !await mayWrite,
    ),
    created: true,
  );
}

/// Le droit au coach, tel que le SERVEUR l'a décidé (`GET /entitlements`).
/// Inconnu (hors ligne, panne) : on laisse écrire, et l'envoi rapportera
/// le vrai refus, s'il y en a un.
Future<bool> _mayWrite(Ref ref) async {
  try {
    final droits = await ref
        .read(subscriptionRepositoryProvider)
        .entitlements();
    return droits.any((d) => d.key == 'ai_coaching' && d.isActive);
  } on Object catch (error) {
    _logger.warning('Droit au coach inconnu : écriture permise', error: error);
    return true;
  }
}
