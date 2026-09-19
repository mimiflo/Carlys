import '../entities/generation_report.dart';
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

  /// Engendre un programme depuis le PROFIL d'entraînement du compte.
  ///
  /// Rien à envoyer : l'objectif, le niveau, le rythme, la durée et le
  /// matériel vivent déjà au profil. L'identifiant vient de l'appareil, comme
  /// pour `save` — et rejouer le même rend le programme tel quel, sans
  /// régénérer. Pour en obtenir un autre, il faut un NOUVEL identifiant.
  Future<GeneratedProgramResult> generate(String programId, {String? name});

  /// Supprime (suppression douce côté serveur, idempotente).
  Future<void> delete(String programId);
}
