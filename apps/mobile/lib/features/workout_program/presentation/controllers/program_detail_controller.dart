import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/program_repository_impl.dart';
import '../../domain/entities/program.dart';

/// Le programme tel que la fiche l'affiche.
///
/// Lu sur le serveur, mais l'écran peut le remplacer TOUT DE SUITE
/// ([show]) : la case posée par un geste paraît sous le doigt, puis la
/// réponse de l'écriture prend sa place. Sans cela, poser un repos
/// attendait trois allers-retours — relire, écrire, relire encore — avant
/// de se voir.
class ProgramDetailController
    extends AutoDisposeFamilyAsyncNotifier<ProgramDetail, String> {
  @override
  Future<ProgramDetail> build(String programId) =>
      ref.watch(programRepositoryProvider).byId(programId);

  void show(ProgramDetail program) => state = AsyncData(program);
}
