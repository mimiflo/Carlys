import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/workout_program/data/repositories/program_repository_impl.dart';
import 'package:carlys_mobile/features/workout_program/domain/entities/program.dart';
import 'package:carlys_mobile/features/workout_program/presentation/providers/program_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_program_repository.dart';

/// Créer un programme, perdre la réponse, recommencer : UN programme.
///
/// L'identifiant naissait à chaque appel. Le serveur avait écrit le premier
/// programme avant que sa réponse se perde ; le nouvel essai en posait un
/// second, vide, qui comptait dans la limite gratuite.
void main() {
  test('le même programme relancé rejoue le même identifiant', () async {
    final repository = _ReponsePerdue();
    final container = ProviderContainer(
      overrides: [programRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final actions = container.read(programActionsProvider);

    repository.perdreLaReponse = true;
    await expectLater(
      actions.create(name: 'Force', weeksCount: 4),
      throwsA(isA<NetworkException>()),
    );
    repository.perdreLaReponse = false;
    final id = await actions.create(name: 'Force', weeksCount: 4);

    expect(repository.ids, [id, id]);
    final forces = (await repository.list()).where((p) => p.name == 'Force');
    expect(forces, hasLength(1));

    // Abouti : un programme au même nom est désormais un AUTRE programme.
    expect(await actions.create(name: 'Force', weeksCount: 4), isNot(id));
  });
}

class _ReponsePerdue extends InMemoryProgramRepository {
  bool perdreLaReponse = false;
  final List<String> ids = [];

  @override
  Future<ProgramDetail> save(ProgramDetail program) async {
    ids.add(program.id);
    final saved = await super.save(program);
    if (perdreLaReponse) {
      throw const NetworkException('réponse perdue (voulu par le test)');
    }
    return saved;
  }
}
