/// LA REMONTÉE DU JOURNAL des récompenses au serveur, sans redite.
///
/// Le journal remonte pour que la frise ait de quoi raconter. Il partait EN
/// ENTIER à chaque recalcul des récompenses, même quand rien n'avait été
/// gagné : clôture d'une séance, passage à « synchronisée », relecture des
/// records, réponse à la question du jour. Côté serveur, chaque envoi
/// réécrivait toutes les lignes.
///
/// Ne pousser que ce qui est NOUVEAU aurait cassé la reprise : cet envoi est
/// le seul nouvel essai d'un jalon dont la remontée a échoué hors ligne. La
/// règle est donc : pousser le journal tant qu'il diffère du dernier que le
/// serveur a ACCEPTÉ.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../progress/data/repositories/progress_repository_impl.dart';
import '../../progress/domain/repositories/progress_repository.dart';

class MilestonePush {
  MilestonePush(this._repository);

  static const _logger = AppLogger('MilestonePush');

  final ProgressRepository _repository;

  /// Le dernier journal accepté par le serveur, et celui qui est en route.
  Map<String, DateTime>? _accepted;
  Map<String, DateTime>? _sending;

  /// Remonte [journal] s'il diffère de ce que le serveur a déjà. N'échoue
  /// JAMAIS : hors ligne, l'envoi échoue, rien n'est retenu, et le prochain
  /// recalcul réessaiera.
  Future<void> push(Map<String, DateTime> journal) async {
    if (journal.isEmpty ||
        _same(journal, _accepted) ||
        _same(journal, _sending)) {
      return;
    }
    final envoi = Map.of(journal);
    _sending = envoi;
    try {
      await _repository.pushMilestones(envoi);
      _accepted = envoi;
    } on Object catch (error) {
      _logger.warning('Journal de récompenses non remonté', error: error);
    } finally {
      if (identical(_sending, envoi)) _sending = null;
    }
  }

  /// Mêmes récompenses, aux mêmes INSTANTS : relu du journal, un instant
  /// revient en UTC là où il était parti en heure locale, et `==` sur un
  /// `DateTime` compare aussi le fuseau.
  static bool _same(Map<String, DateTime> a, Map<String, DateTime>? b) {
    if (b == null || a.length != b.length) return false;
    for (final MapEntry(:key, :value) in a.entries) {
      final other = b[key];
      if (other == null || !other.isAtSameMomentAs(value)) return false;
    }
    return true;
  }
}

/// Appartient au COMPTE : la purge locale le renouvelle, sans quoi le compte
/// suivant ne remonterait pas un journal identique à celui du précédent.
final milestonePushProvider = Provider<MilestonePush>(
  (ref) => MilestonePush(ref.watch(progressRepositoryProvider)),
);
