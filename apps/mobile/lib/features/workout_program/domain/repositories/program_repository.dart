import '../entities/program.dart';

/// Contrat des programmes multi-semaines.
///
/// Une seule écriture : `save` envoie l'ÉTAT COMPLET (PUT) — l'identifiant
/// vient de l'appareil, rejouer la même écriture redonne le même état.
abstract interface class ProgramRepository {
  /// Mes programmes, plus récemment modifiés d'abord.
  Future<List<ProgramSummary>> list();

  /// Contenu complet d'un programme.
  Future<ProgramDetail> byId(String programId);

  /// Écrit l'état complet et rend l'état stocké.
  Future<ProgramDetail> save(ProgramDetail program);

  /// Supprime (suppression douce côté serveur, idempotente).
  Future<void> delete(String programId);
}
