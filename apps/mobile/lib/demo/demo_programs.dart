/// Programmes du MODE DÉMO : un plan de deux semaines, en mémoire.
///
/// Même règle que les autres dépôts de démonstration : l'état vit le temps
/// du processus, chaque écriture se voit immédiatement, rien ne touche le
/// réseau.
library;

import '../features/workout_program/domain/entities/program.dart';
import '../features/workout_program/domain/repositories/program_repository.dart';

ProgramDayEntry _day(
  int week,
  int dayOfWeek,
  String label, {
  String? templateId,
  bool isRest = false,
}) {
  return ProgramDayEntry(
    id: 'demo-program-day-$week-$dayOfWeek',
    weekNumber: week,
    dayOfWeek: dayOfWeek,
    templateId: templateId,
    label: label,
    isRest: isRest,
  );
}

class DemoProgramRepository implements ProgramRepository {
  final Map<String, ProgramDetail> _programs = {
    'demo-program-force': ProgramDetail(
      id: 'demo-program-force',
      name: 'Force — 2 semaines',
      description: 'Push, pull, jambes — et du vrai repos.',
      weeksCount: 2,
      isActive: true,
      days: [
        for (final week in const [1, 2]) ...[
          _day(week, 1, 'Push — Force', templateId: 'demo-template-push'),
          _day(week, 2, 'Repos', isRest: true),
          _day(
            week,
            3,
            'Pull — Hypertrophie',
            templateId: 'demo-template-pull',
          ),
          _day(week, 4, 'Course'),
          _day(week, 5, 'Push — Force', templateId: 'demo-template-push'),
          _day(week, 6, 'Repos', isRest: true),
        ],
      ],
    ),
  };

  @override
  Future<List<ProgramSummary>> list() async {
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
    final program = _programs[programId];
    if (program == null) {
      throw StateError('programme inconnu : $programId');
    }
    return program;
  }

  @override
  Future<ProgramDetail> save(ProgramDetail program) async {
    // UN SEUL programme suivi, comme le serveur le garantit.
    if (program.isActive) {
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
    _programs.remove(programId);
  }
}
