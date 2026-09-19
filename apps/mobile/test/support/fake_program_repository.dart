import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/generation_report.dart';
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

  /// Refus de génération à la demande. Le message imite ce que le serveur
  /// rend vraiment : il NOMME le champ manquant. Une doublure qui lèverait
  /// un `StateError` testerait un chemin que le vrai dépôt n'emprunte jamais
  /// — il traduit toujours en `AppException`.
  ValidationException? generationFailure;

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
    final refus = generationFailure;
    if (refus != null) {
      throw refus;
    }
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
    _guard();
    _programs.remove(programId);
  }
}
