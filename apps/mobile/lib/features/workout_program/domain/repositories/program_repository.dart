import '../entities/generation_report.dart';
import '../entities/program.dart';
import '../entities/program_calendar.dart';

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

  /// Une semaine DATÉE du programme.
  ///
  /// Sans [week], celle qui contient aujourd'hui — le serveur connaît le
  /// fuseau de la personne, l'application non. Lève si le programme n'a pas
  /// encore de date de début : c'est un refus qui se corrige en deux gestes,
  /// et il vaut mieux le dire qu'afficher une semaine vide.
  Future<ProgramCalendarWeek> calendarWeek(String programId, {int? week});

  /// Fait reconnaître une séance par une case — ou l'en détache
  /// ([sessionId] à `null`).
  ///
  /// Le geste de celui qui s'est entraîné SANS passer par le calendrier :
  /// sa séance ne portait l'identifiant d'aucune case, et la case restait
  /// rouge. Le serveur n'accepte que ce qui est vrai — une séance terminée
  /// CE JOUR-LÀ — et rend la semaine entière, réaffichable telle quelle.
  Future<ProgramCalendarWeek> linkCalendarSession({
    required String programId,
    required String dayId,
    required String? sessionId,
  });
}
