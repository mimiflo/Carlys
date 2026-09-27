import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/program_day_move.dart';
import 'package:carlys_mobile/features/workout_program/presentation/controllers/program_controllers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_program_repository.dart';

/// UNE CASE DÉJÀ FAITE NE CHANGE PAS DE DATE.
///
/// Le serveur déduit « fait » de l'IDENTIFIANT de la case. Semaine passée :
/// mercredi « Pull » fait, jeudi « Course » manqué. Déplacer jeudi vers
/// mercredi ÉCHANGEAIT les deux cases, et la case liée partait au jeudi : le
/// calendrier affichait « jeudi fait, mercredi manqué », alors que la
/// séance avait eu lieu mercredi.
void main() {
  late InMemoryProgramRepository repository;
  late ProviderContainer container;
  const programme = 'exemple-programme-force';

  setUp(() {
    repository = InMemoryProgramRepository();
    container = ProviderContainer(
      overrides: [programRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  Future<Map<int, String?>> semaine1() async {
    final week = await repository.calendarWeek(programme, week: 1);
    return {for (final day in week.days) day.dayOfWeek: day.label};
  }

  test('vers un jour FAIT : refusé, rien ne bouge', () async {
    // L'exemple : la semaine 1 a son mercredi (3) fait.
    expect(repository.doneDayIds, contains('exemple-programme-day-1-3'));

    await expectLater(
      container
          .read(programActionsProvider)
          .moveDay(programme, weekNumber: 1, fromDayOfWeek: 4, toDayOfWeek: 3),
      throwsA(
        isA<ValidationException>().having(
          (e) => e.message,
          'message',
          heldDayMoveRefusal,
        ),
      ),
    );

    final jours = await semaine1();
    expect(jours[3], 'Pull hypertrophie');
    expect(jours[4], 'Course');
  });

  test('DEPUIS un jour fait non plus (course avec la feuille)', () async {
    await expectLater(
      container
          .read(programActionsProvider)
          .moveDay(programme, weekNumber: 1, fromDayOfWeek: 3, toDayOfWeek: 7),
      throwsA(isA<ValidationException>()),
    );
    expect((await semaine1())[3], 'Pull hypertrophie');
  });

  test('vers un jour libre ou à faire, le déplacement a lieu', () async {
    await container
        .read(programActionsProvider)
        .moveDay(programme, weekNumber: 1, fromDayOfWeek: 4, toDayOfWeek: 7);

    final jours = await semaine1();
    expect(jours[7], 'Course');
    expect(jours[4], isNull);
  });
}
