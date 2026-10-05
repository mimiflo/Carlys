import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/program.dart';
import 'program_providers.dart';

/// La file des écritures d'un programme, et ce qu'elle fait voir.
///
/// Le PUT décrit l'état COMPLET : deux écritures entrelacées s'écraseraient,
/// d'où la file. Et chaque geste se voit SOUS LE DOIGT ([showAhead]), puis
/// la réponse du serveur prend sa place — ou, sur un refus, une relecture.
/// Avant, poser un repos attendait trois allers-retours (relire, écrire,
/// relire encore) avant de paraître.
class ProgramWriteQueue {
  ProgramWriteQueue(this._ref);

  final Ref _ref;

  /// La file des écritures. La chaîne AVALE l'échec — sinon un geste raté
  /// condamnerait tous les suivants — mais chaque appelant voit le sien.
  Future<void> _chain = Future<void>.value();

  /// Écritures lancées et pas encore revenues, PAR PROGRAMME : tant qu'il
  /// en reste une, la réponse d'une plus ancienne ne remplace pas l'écran —
  /// elle effacerait la case que le geste suivant vient d'y poser. C'est la
  /// DERNIÈRE réponse, rebâtie sur l'état serveur frais, qui fait foi.
  final Map<String, int> _pending = {};

  /// Sérialise une écriture, puis rafraîchit la liste et le calendrier.
  ///
  /// Le DÉTAIL, lui, prend le programme que l'écriture rend (la réponse du
  /// PUT) au lieu d'être relu : un aller-retour de moins. Sur un échec, il
  /// est relu — l'écran redit ce que le serveur tient, et la case montrée
  /// d'avance s'efface — sauf si une écriture suit : sa réponse le fera.
  Future<void> write(
    String programId,
    Future<ProgramDetail?> Function() action,
  ) {
    _pending.update(programId, (n) => n + 1, ifAbsent: () => 1);
    final tour = _chain.then((_) => action());
    _chain = tour.then((_) {}, onError: (Object _) {});
    return tour.then(
      (saved) {
        if (_settle(programId) && saved != null) {
          _showAnswer(programId, saved);
        }
        _refreshLists();
      },
      onError: (Object error, StackTrace stack) {
        if (_settle(programId)) {
          _ref.invalidate(programDetailProvider(programId));
        }
        _refreshLists();
        Error.throwWithStackTrace(error, stack);
      },
    );
  }

  /// Retire une écriture du compte ; vrai quand c'était la dernière.
  bool _settle(String programId) {
    final left = (_pending[programId] ?? 1) - 1;
    if (left <= 0) {
      _pending.remove(programId);
      return true;
    }
    _pending[programId] = left;
    return false;
  }

  /// La réponse du serveur prend l'écran — sauf si une relecture est en
  /// vol : elle reviendrait APRÈS et remettrait un état plus ancien. On la
  /// relance alors, pour que la dernière lecture soit la plus fraîche.
  void _showAnswer(String programId, ProgramDetail saved) {
    final provider = programDetailProvider(programId);
    if (!_ref.exists(provider)) {
      return;
    }
    if (_ref.read(provider).isLoading) {
      _ref.invalidate(provider);
    } else {
      _ref.read(provider.notifier).show(saved);
    }
  }

  void _refreshLists() {
    _ref
      ..invalidate(programsProvider)
      // La famille ENTIÈRE : changer la date de début déplace toutes les
      // semaines à la fois, et l'écran n'a pas à savoir lesquelles.
      ..invalidate(programCalendarProvider);
  }

  /// D'avance, sur ce que la fiche MONTRE : le geste se voit sous le doigt.
  /// L'écriture, elle, repart toujours de l'état serveur frais, et sa
  /// réponse (ou, sur un échec, une relecture) remplace cet affichage.
  void showAhead(
    String programId,
    ProgramDetail Function(ProgramDetail shown) change,
  ) {
    final provider = programDetailProvider(programId);
    final shown = _ref.exists(provider)
        ? _ref.read(provider).valueOrNull
        : null;
    if (shown != null) {
      _show(programId, change(shown));
    }
  }

  /// Remplace ce que la fiche affiche, si elle est ouverte.
  void _show(String programId, ProgramDetail program) {
    final provider = programDetailProvider(programId);
    if (_ref.exists(provider)) {
      _ref.read(provider.notifier).show(program);
    }
  }
}
