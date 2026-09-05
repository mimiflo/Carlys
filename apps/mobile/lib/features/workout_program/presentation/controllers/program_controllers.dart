import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/program_repository_impl.dart';
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
/// PAS d'autoDispose : l'objet est rappelé dans des callbacks tardifs — la
/// durée de vie du `Ref` doit être garantie, pas fortuite.
final programActionsProvider = Provider<ProgramActions>((ref) {
  return ProgramActions(ref);
});

class ProgramActions {
  const ProgramActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Crée un programme vide et rend son identifiant, NÉ SUR L'APPAREIL.
  Future<String> create({required String name, required int weeksCount}) async {
    final id = _uuid.v4();
    await _ref
        .read(programRepositoryProvider)
        .save(
          ProgramDetail(
            id: id,
            name: name,
            weeksCount: weeksCount,
            isActive: false,
            days: const [],
          ),
        );
    _ref.invalidate(programsProvider);
    return id;
  }

  /// Écrit l'état complet passé, puis rafraîchit liste et détail.
  Future<void> save(ProgramDetail program) async {
    await _ref.read(programRepositoryProvider).save(program);
    _ref
      ..invalidate(programsProvider)
      ..invalidate(programDetailProvider(program.id));
  }

  /// Pose ou retire un jour du calendrier. `day` remplace l'existant à la
  /// même case ; `null` l'efface.
  Future<void> setDay(
    ProgramDetail program, {
    required int weekNumber,
    required int dayOfWeek,
    ProgramDayEntry? day,
  }) {
    final others = program.days
        .where(
          (entry) =>
              entry.weekNumber != weekNumber || entry.dayOfWeek != dayOfWeek,
        )
        .toList();
    return save(program.copyWith(days: [...others, if (day != null) day]));
  }

  /// Un identifiant de jour, exposé pour que l'interface n'importe pas uuid.
  String newDayId() => _uuid.v4();

  Future<void> delete(String programId) async {
    await _ref.read(programRepositoryProvider).delete(programId);
    _ref.invalidate(programsProvider);
  }
}
