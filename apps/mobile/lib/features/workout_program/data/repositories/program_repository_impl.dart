import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_error_mapper.dart';
import '../../../../core/api/dio_client.dart';
import '../../domain/entities/generation_report.dart';
import '../../domain/entities/program.dart';
import '../../domain/repositories/program_repository.dart';

/// Programmes servis par l'API (/api/v1/programs).
class ProgramRepositoryImpl implements ProgramRepository {
  ProgramRepositoryImpl(this._dio);

  final Dio _dio;

  /// Garde-fou : un serveur qui rendrait toujours `hasMore` avec le même
  /// curseur ne doit pas faire tourner l'application indéfiniment. Vingt
  /// pages de vingt, c'est quatre cents programmes — très au-delà de ce
  /// qu'une personne écrit.
  static const int _maxPages = 20;

  /// Tous les programmes, en suivant la PAGINATION du serveur.
  ///
  /// `GET /programs` est paginé par curseur au contrat comme au contrôleur,
  /// avec une page de vingt par défaut, et l'enveloppe porte
  /// `meta.nextCursor` / `meta.hasMore`. Ce client ne lisait ni l'un ni
  /// l'autre : au vingt et unième programme, la liste s'arrêtait — sans
  /// erreur, sans message, sans rien qui le laisse deviner. Les deux autres
  /// listes paginées du mobile suivent déjà le curseur ; c'est le même motif.
  @override
  Future<List<ProgramSummary>> list() {
    return _guard(() async {
      final programmes = <ProgramSummary>[];
      String? cursor;
      var pages = 0;
      do {
        final response = await _dio.get<Map<String, dynamic>>(
          '/programs',
          queryParameters: {if (cursor != null) 'cursor': cursor},
        );
        final body = response.data ?? const <String, dynamic>{};
        final rows = body['data'] as List<dynamic>? ?? const [];
        programmes.addAll(rows.cast<Map<String, dynamic>>().map(_summary));

        final meta = body['meta'] as Map<String, dynamic>? ?? const {};
        final suivant = meta['nextCursor'] as String?;
        cursor = (meta['hasMore'] as bool? ?? false) ? suivant : null;
        pages += 1;
      } while (cursor != null && pages < _maxPages);
      return List<ProgramSummary>.unmodifiable(programmes);
    });
  }

  @override
  Future<ProgramDetail> byId(String programId) {
    return _guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/programs/$programId',
      );
      return _detail(_data(response));
    });
  }

  @override
  Future<ProgramDetail> save(ProgramDetail program) {
    return _guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/programs/${program.id}',
        data: {
          'name': program.name,
          'description': program.description,
          'weeksCount': program.weeksCount,
          'isActive': program.isActive,
          'days': [
            for (final day in program.days)
              {
                'id': day.id,
                'weekNumber': day.weekNumber,
                'dayOfWeek': day.dayOfWeek,
                'templateId': day.templateId,
                'label': day.label,
                'isRest': day.isRest,
              },
          ],
        },
      );
      return _detail(_data(response));
    });
  }

  @override
  Future<GeneratedProgramResult> generate(String programId, {String? name}) {
    return _guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '/programs/$programId/generate',
        data: {if (name != null) 'name': name},
      );
      final body = _data(response);
      final program = body['program'] as Map<String, dynamic>? ?? const {};
      return GeneratedProgramResult(
        programId: program['id'] as String? ?? programId,
        name: program['name'] as String? ?? 'Programme',
        weeksCount: (program['weeksCount'] as num?)?.toInt() ?? 0,
        report: _report(body['report'] as Map<String, dynamic>? ?? const {}),
      );
    });
  }

  @override
  Future<void> delete(String programId) {
    return _guard(() async {
      await _dio.delete<Map<String, dynamic>>('/programs/$programId');
    });
  }

  ProgramSummary _summary(Map<String, dynamic> row) {
    return ProgramSummary(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      weeksCount: (row['weeksCount'] as num).toInt(),
      isActive: row['isActive'] as bool,
      daysCount: (row['daysCount'] as num).toInt(),
      updatedAt: DateTime.parse(row['updatedAt'] as String),
    );
  }

  ProgramDetail _detail(Map<String, dynamic> row) {
    final days = row['days'] as List<dynamic>? ?? const [];
    return ProgramDetail(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      weeksCount: (row['weeksCount'] as num).toInt(),
      isActive: row['isActive'] as bool,
      days: days
          .cast<Map<String, dynamic>>()
          .map(
            (day) => ProgramDayEntry(
              id: day['id'] as String,
              weekNumber: (day['weekNumber'] as num).toInt(),
              dayOfWeek: (day['dayOfWeek'] as num).toInt(),
              templateId: day['templateId'] as String?,
              label: day['label'] as String,
              isRest: day['isRest'] as bool,
            ),
          )
          .toList(growable: false),
    );
  }

  /// Le rapport, lu DÉFENSIVEMENT.
  ///
  /// Un client plus vieux que le serveur doit continuer d'afficher le
  /// programme : un champ inconnu ou absent ne fait pas échouer la lecture,
  /// il rend une valeur neutre. C'est le rapport qui se dégrade, pas le plan.
  GenerationReport _report(Map<String, dynamic> row) {
    List<String> textes(String key) => (row[key] as List<dynamic>? ?? const [])
        .cast<String>()
        .toList(growable: false);
    return GenerationReport(
      status: row['status'] as String? ?? 'relaxed',
      sessionsPerWeek: (row['sessionsPerWeek'] as num?)?.toInt() ?? 0,
      split: textes('split'),
      templatedDays: (row['templatedDays'] as num?)?.toInt() ?? 0,
      freeLabelDays: (row['freeLabelDays'] as num?)?.toInt() ?? 0,
      restDays: (row['restDays'] as num?)?.toInt() ?? 0,
      templatesCreated: (row['templatesCreated'] as num?)?.toInt() ?? 0,
      weeklyVolume: (row['weeklyVolume'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (volume) => GenerationVolume(
              muscleGroup: volume['muscleGroup'] as String? ?? '',
              weeklySets: (volume['weeklySets'] as num?)?.toInt() ?? 0,
              targetMin: (volume['targetMin'] as num?)?.toInt() ?? 0,
              targetMax: (volume['targetMax'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false),
      uncoveredGroups: textes('uncoveredGroups'),
      relaxations: (row['relaxations'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (relaxation) => GenerationRelaxation(
              code: relaxation['code'] as String? ?? '',
              message: relaxation['message'] as String? ?? '',
              subject: relaxation['subject'] as String?,
              expected: (relaxation['expected'] as num?)?.toInt(),
              actual: (relaxation['actual'] as num?)?.toInt(),
            ),
          )
          .toList(growable: false),
      notes: textes('notes'),
    );
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    return response.data?['data'] as Map<String, dynamic>? ?? const {};
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DioException catch (exception) {
      throw mapDioException(exception);
    }
  }
}

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return ProgramRepositoryImpl(ref.watch(dioProvider));
});
