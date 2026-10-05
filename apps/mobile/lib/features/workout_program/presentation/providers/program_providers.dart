import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/program_repository_impl.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/program_calendar.dart';
import '../controllers/program_detail_controller.dart';

// Les écritures vivent à part ; on les rejoint par ce fichier, comme avant.
export 'program_actions.dart';

final programsProvider = FutureProvider.autoDispose<List<ProgramSummary>>((
  ref,
) {
  return ref.watch(programRepositoryProvider).list();
});

final programDetailProvider = AsyncNotifierProvider.autoDispose
    .family<ProgramDetailController, ProgramDetail, String>(
      ProgramDetailController.new,
    );

/// Une semaine DATÉE du programme.
///
/// La semaine est facultative : sans elle, le serveur ouvre sur celle
/// d'aujourd'hui — il connaît le fuseau de la personne, l'écran non.
final programCalendarProvider = FutureProvider.autoDispose
    .family<ProgramCalendarWeek, ({String programId, int? week})>((ref, key) {
      return ref
          .watch(programRepositoryProvider)
          .calendarWeek(key.programId, week: key.week);
    });
