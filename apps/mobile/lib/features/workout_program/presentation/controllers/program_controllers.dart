import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/program_repository_impl.dart';
import '../../domain/entities/generation_report.dart';
import '../../domain/entities/program.dart';

final programsProvider = FutureProvider.autoDispose<List<ProgramSummary>>((
  ref,
) {
  return ref.watch(programRepositoryProvider).list();
});

final programDetailProvider = FutureProvider.autoDispose
    .family<ProgramDetail, String>((ref, programId) {
      return ref.watch(programRepositoryProvider).byId(programId);
    });

/// Actions des programmes : une seule écriture (PUT de l'état complet),
/// chaque écriture invalide les lectures.
///
/// Deux règles vivent ICI, parce que le PUT est un état complet :
///  - les écritures se SUIVENT, jamais deux PUT entrelacés ;
///  - chaque écriture RELIT l'état serveur quand vient son tour, et n'y
///    change que SON geste. Bâtie sur l'instantané du tap, une deuxième
///    édition rapide repartait d'un état sans la première et l'effaçait du
///    serveur, sans erreur (même course pour l'interrupteur « suivi »).
///
/// PAS d'autoDispose : l'objet est rappelé dans des callbacks tardifs — la
/// durée de vie du `Ref` doit être garantie, pas fortuite.
final programActionsProvider = Provider<ProgramActions>(ProgramActions.new);

class ProgramActions {
  ProgramActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// La file des écritures. La chaîne AVALE l'échec — sinon un geste raté
  /// condamnerait tous les suivants — mais chaque appelant voit le sien.
  Future<void> _chain = Future<void>.value();

  /// Sérialise une écriture, puis rafraîchit liste et détail — succès ou
  /// échec : sur un refus serveur, relire remet l'écran d'accord avec lui.
  Future<void> _write(String programId, Future<void> Function() action) {
    final tour = _chain.then((_) => action());
    _chain = tour.then((_) {}, onError: (Object _) {});
    return tour.whenComplete(() {
      _ref
        ..invalidate(programsProvider)
        ..invalidate(programDetailProvider(programId));
    });
  }

  /// Crée un programme vide et rend son identifiant, NÉ SUR L'APPAREIL.
  Future<String> create({required String name, required int weeksCount}) async {
    final id = _uuid.v4();
    await _write(
      id,
      () => _ref
          .read(programRepositoryProvider)
          .save(
            ProgramDetail(
              id: id,
              name: name,
              weeksCount: weeksCount,
              isActive: false,
              days: const [],
            ),
          ),
    );
    return id;
  }

  /// Pose ou retire un jour du calendrier. [build] reçoit la case telle que
  /// le SERVEUR la connaît à l'instant de l'écriture — pas telle que l'écran
  /// l'affichait au tap — et rend son remplacement (`null` : elle s'efface).
  Future<void> setDay(
    String programId, {
    required int weekNumber,
    required int dayOfWeek,
    required ProgramDayEntry? Function(ProgramDayEntry? existing) build,
  }) {
    return _write(programId, () async {
      final repository = _ref.read(programRepositoryProvider);
      final fresh = await repository.byId(programId);
      final others = fresh.days
          .where(
            (entry) =>
                entry.weekNumber != weekNumber || entry.dayOfWeek != dayOfWeek,
          )
          .toList();
      final day = build(fresh.dayAt(weekNumber, dayOfWeek));
      await repository.save(
        fresh.copyWith(days: [...others, if (day != null) day]),
      );
    });
  }

  /// Suit (ou cesse de suivre) ce programme, sur son état serveur frais.
  Future<void> setActive(String programId, {required bool active}) {
    return _write(programId, () async {
      final repository = _ref.read(programRepositoryProvider);
      final fresh = await repository.byId(programId);
      if (fresh.isActive == active) {
        return;
      }
      await repository.save(fresh.copyWith(isActive: active));
    });
  }

  /// Engendre un programme depuis le profil, et rend son plan avec son
  /// EXPLICATION.
  ///
  /// L'identifiant naît ici, sur l'appareil : chaque appel en produit un
  /// NOUVEAU, donc « régénérer » rend un autre programme au lieu de renvoyer
  /// le même. Le serveur s'en sert comme graine, et rejouer un identifiant
  /// déjà connu rendrait le plan tel quel — ce qui protège les retouches de
  /// la personne, mais n'est pas ce qu'on veut quand elle redemande.
  Future<GeneratedProgramResult> generate() async {
    final id = _uuid.v4();
    late GeneratedProgramResult result;
    await _write(id, () async {
      result = await _ref.read(programRepositoryProvider).generate(id);
    });
    return result;
  }

  /// Un identifiant de jour, exposé pour que l'interface n'importe pas uuid.
  String newDayId() => _uuid.v4();

  Future<void> delete(String programId) async {
    await _ref.read(programRepositoryProvider).delete(programId);
    _ref.invalidate(programsProvider);
  }
}
