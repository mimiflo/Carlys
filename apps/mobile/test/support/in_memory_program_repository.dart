/// Programmes D'EXEMPLE (doublure de test) : un plan de deux semaines, en mémoire.
///
/// Même règle que les autres dépôts d'exemple : l'état vit le temps
/// du processus, chaque écriture se voit immédiatement, rien ne touche le
/// réseau.
library;

import 'package:carlys_mobile/features/workout_program/domain/entities/generation_report.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/domain/repositories/program_repository.dart';

ProgramDayEntry _day(
  int week,
  int dayOfWeek,
  String label, {
  String? templateId,
  bool isRest = false,
}) {
  return ProgramDayEntry(
    id: 'exemple-programme-day-$week-$dayOfWeek',
    weekNumber: week,
    dayOfWeek: dayOfWeek,
    templateId: templateId,
    label: label,
    isRest: isRest,
  );
}

class InMemoryProgramRepository implements ProgramRepository {
  final Map<String, ProgramDetail> _programs = {
    'exemple-programme-force': ProgramDetail(
      id: 'exemple-programme-force',
      name: 'Force en 2 semaines',
      description: 'Push, pull, jambes, et du vrai repos.',
      weeksCount: 2,
      isActive: true,
      days: [
        for (final week in const [1, 2]) ...[
          _day(week, 1, 'Push force', templateId: 'exemple-modele-push'),
          _day(week, 2, 'Repos', isRest: true),
          _day(week, 3, 'Pull hypertrophie', templateId: 'exemple-modele-pull'),
          _day(week, 4, 'Course'),
          _day(week, 5, 'Push force', templateId: 'exemple-modele-push'),
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

  /// Engendre un programme d'exemple : quatre séances, deux semaines.
  ///
  /// La doublure ne rejoue PAS les règles du serveur — elles y vivent, et
  /// deux implémentations finiraient par diverger. Elle rend une forme
  /// plausible pour que l'écran ait quelque chose d'honnête à montrer.
  @override
  Future<GeneratedProgramResult> generate(
    String programId, {
    String? name,
  }) async {
    final program = ProgramDetail(
      id: programId,
      name: name ?? 'Programme 8 semaines',
      description: 'Engendré depuis ton profil.',
      weeksCount: 8,
      isActive: false,
      days: [
        for (var week = 1; week <= 8; week += 1)
          for (var day = 1; day <= 7; day += 1)
            ProgramDayEntry(
              id: '$programId-$week-$day',
              weekNumber: week,
              dayOfWeek: day,
              templateId: day <= 4 ? '$programId-modele-$day' : null,
              label: day <= 4 ? 'Séance $day' : 'Repos',
              isRest: day > 4,
            ),
      ],
    );
    _programs[programId] = program;
    return GeneratedProgramResult(
      programId: programId,
      name: program.name,
      weeksCount: program.weeksCount,
      report: const GenerationReport(
        status: 'relaxed',
        sessionsPerWeek: 4,
        split: [
          'Haut du corps A',
          'Bas du corps A',
          'Haut du corps B',
          'Bas du corps B',
        ],
        templatedDays: 32,
        freeLabelDays: 0,
        restDays: 24,
        templatesCreated: 32,
        weeklyVolume: [
          GenerationVolume(
            muscleGroup: 'pectoraux',
            weeklySets: 12,
            targetMin: 9,
            targetMax: 12,
          ),
          GenerationVolume(
            muscleGroup: 'dos',
            weeklySets: 6,
            targetMin: 9,
            targetMax: 12,
          ),
        ],
        uncoveredGroups: ['avant-bras'],
        relaxations: [
          GenerationRelaxation(
            code: 'R6_GROUPE_SOUS_LE_MINIMUM',
            subject: 'dos',
            expected: 9,
            actual: 6,
            message:
                '« dos » reçoit 6 séries par semaine au lieu de 9 : le '
                'catalogue jouable n’en offre pas davantage.',
          ),
        ],
        notes: [
          'Pour aller plus loin : « Haltères » ouvrirait 14 exercices de plus (biceps, dos).',
        ],
      ),
    );
  }

  @override
  Future<void> delete(String programId) async {
    _programs.remove(programId);
  }
}
