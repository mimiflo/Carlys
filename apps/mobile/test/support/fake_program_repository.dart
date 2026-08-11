import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/repositories/program_repository.dart';

/// Dépôt de programmes pilotable : état en mémoire, pannes à la demande.
class FakeProgramRepository implements ProgramRepository {
  FakeProgramRepository({List<ProgramDetail>? programs, this.failReads = false})
      : _programs = {
          for (final program in programs ?? const <ProgramDetail>[])
            program.id: program,
        };

  final Map<String, ProgramDetail> _programs;
  bool failReads;

  /// Nombre d'écritures reçues (création comprise) — pour les assertions.
  int saveCount = 0;

  void _guard() {
    if (failReads) {
      throw StateError('programmes injoignables (voulu par le test)');
    }
  }

  @override
  Future<List<ProgramSummary>> list() async {
    _guard();
    return _programs.values
        .map(
          (program) => ProgramSummary(
            id: program.id,
            name: program.name,
            description: program.description,
            weeksCount: program.weeksCount,
            isActive: program.isActive,
            daysCount: program.days.length,
            updatedAt: DateTime.now(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<ProgramDetail> byId(String programId) async {
    _guard();
    final program = _programs[programId];
    if (program == null) {
      throw StateError('programme inconnu : $programId');
    }
    return program;
  }

  @override
  Future<ProgramDetail> save(ProgramDetail program) async {
    _guard();
    saveCount++;
    if (program.isActive) {
      // UN SEUL programme suivi, comme le vrai serveur.
      for (final entry in _programs.entries) {
        if (entry.key != program.id && entry.value.isActive) {
          _programs[entry.key] = entry.value.copyWith(isActive: false);
        }
      }
    }
    _programs[program.id] = program;
    return program;
  }

  @override
  Future<void> delete(String programId) async {
    _guard();
    _programs.remove(programId);
  }
}
