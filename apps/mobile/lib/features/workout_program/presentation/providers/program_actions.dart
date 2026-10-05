import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utilities/creation_identity.dart';
import '../../data/repositories/program_repository_impl.dart';
import '../../domain/entities/generation_report.dart';
import '../../domain/entities/program.dart';
import '../../domain/entities/program_calendar.dart';
import '../../domain/program_day_move.dart';
import 'program_providers.dart';
import 'program_write_queue.dart';

/// Actions des programmes : une seule écriture (PUT de l'état complet) ;
/// la fiche reprend le programme que l'écriture rend, le reste est relu.
///
/// Deux règles vivent ICI, parce que le PUT est un état complet :
///  - les écritures se SUIVENT, jamais deux PUT entrelacés ;
///  - chaque écriture RELIT l'état serveur quand vient son tour, et n'y
///    change que SON geste. Bâtie sur l'instantané du tap, une deuxième
///    édition rapide repartait d'un état sans la première et l'effaçait du
///    serveur, sans erreur (même course pour l'interrupteur « suivi »).
///
/// PAS d'autoDispose : l'objet est rappelé dans des callbacks tardifs — la
/// durée de vie du `Ref` doit être garantie, pas fortuite.
final programActionsProvider = Provider<ProgramActions>(ProgramActions.new);

/// L'identifiant du programme vide en cours de création : le même brouillon
/// renvoyé après un échec le rejoue. Appartient au COMPTE (purge locale).
final programCreationProvider =
    Provider<CreationIdentity<({String name, int weeksCount})>>(
      (ref) => CreationIdentity(),
    );

class ProgramActions {
  ProgramActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  late final _queue = ProgramWriteQueue(_ref);

  /// Crée un programme vide et rend son identifiant, NÉ SUR L'APPAREIL et
  /// stable d'un essai à l'autre du même geste (`CreationIdentity`).
  Future<String> create({required String name, required int weeksCount}) async {
    final creation = _ref.read(programCreationProvider);
    final id = creation.idFor((name: name, weeksCount: weeksCount));
    await _queue.write(
      id,
      () => _ref
          .read(programRepositoryProvider)
          .save(
            ProgramDetail(
              id: id,
              name: name,
              weeksCount: weeksCount,
              isActive: false,
              days: const [],
            ),
          ),
    );
    creation.settle();
    return id;
  }

  /// Pose ou retire un jour du calendrier. [build] reçoit la case telle que
  /// le SERVEUR la connaît à l'instant de l'écriture — pas telle que l'écran
  /// l'affichait au tap — et rend son remplacement (`null` : elle s'efface).
  Future<void> setDay(
    String programId, {
    required int weekNumber,
    required int dayOfWeek,
    required ProgramDayEntry? Function(ProgramDayEntry? existing) build,
  }) {
    ProgramDetail withDay(ProgramDetail program) {
      final others = program.days
          .where(
            (entry) =>
                entry.weekNumber != weekNumber || entry.dayOfWeek != dayOfWeek,
          )
          .toList();
      final day = build(program.dayAt(weekNumber, dayOfWeek));
      return program.copyWith(days: [...others, if (day != null) day]);
    }

    _queue.showAhead(programId, withDay);
    return _queue.write(programId, () async {
      final repository = _ref.read(programRepositoryProvider);
      final fresh = await repository.byId(programId);
      return repository.save(withDay(fresh));
    });
  }

  /// Déplace une case vers un autre jour de la MÊME semaine — en échangeant
  /// avec celle qui s'y trouve, s'il y en a une.
  ///
  /// UNE seule lecture et UNE seule écriture, quoi qu'il arrive : un échange
  /// fait en deux `setDay` laisserait, entre les deux, un programme où la
  /// même séance occupe deux jours — ou aucun. La règle du déplacement vit
  /// dans `program_day_move.dart`, éprouvée sans réseau.
  ///
  /// L'écriture est ÉVITÉE quand rien ne bouge (même jour, départ vide, jour
  /// hors semaine) : `moveProgramDay` rend alors le programme inchangé, et
  /// on le reconnaît à son identité.
  ///
  /// REFUSÉE si l'un des deux jours est déjà fait ([daysHeldBySession], lu
  /// sur le calendrier FRAIS) : la feuille ne le propose plus, ce refus
  /// couvre la course entre son ouverture et le tap.
  Future<void> moveDay(
    String programId, {
    required int weekNumber,
    required int fromDayOfWeek,
    required int toDayOfWeek,
  }) {
    return _queue.write(programId, () async {
      final repository = _ref.read(programRepositoryProvider);
      final fresh = await repository.byId(programId);
      final semaine = await repository.calendarWeek(
        programId,
        week: weekNumber,
      );
      final tenus = daysHeldBySession(semaine);
      if (tenus.contains(fromDayOfWeek) || tenus.contains(toDayOfWeek)) {
        throw const ValidationException(heldDayMoveRefusal);
      }
      final moved = moveProgramDay(
        fresh,
        weekNumber: weekNumber,
        fromDayOfWeek: fromDayOfWeek,
        toDayOfWeek: toDayOfWeek,
      );
      if (identical(moved, fresh)) {
        return fresh;
      }
      return repository.save(moved);
    });
  }

  /// Suit (ou cesse de suivre) ce programme, sur son état serveur frais.
  Future<void> setActive(String programId, {required bool active}) {
    _queue.showAhead(programId, (shown) => shown.copyWith(isActive: active));
    return _queue.write(programId, () async {
      final repository = _ref.read(programRepositoryProvider);
      final fresh = await repository.byId(programId);
      if (fresh.isActive == active) {
        return fresh;
      }
      return repository.save(fresh.copyWith(isActive: active));
    });
  }

  /// Engendre un programme depuis le profil, et rend son plan avec son
  /// EXPLICATION.
  ///
  /// L'identifiant naît ici, sur l'appareil : chaque appel en produit un
  /// NOUVEAU, donc « régénérer » rend un autre programme au lieu de renvoyer
  /// le même. Le serveur s'en sert comme graine, et rejouer un identifiant
  /// déjà connu rendrait le plan tel quel — ce qui protège les retouches de
  /// la personne, mais n'est pas ce qu'on veut quand elle redemande.
  Future<GeneratedProgramResult> generate() async {
    final id = _uuid.v4();
    late GeneratedProgramResult result;
    await _queue.write(id, () async {
      result = await _ref.read(programRepositoryProvider).generate(id);
      return null;
    });
    return result;
  }

  /// Pose ou retire la DATE DE DÉBUT, sur l'état serveur frais.
  ///
  /// Le calendrier tout entier en découle : sans elle, le programme reste la
  /// grille qu'il a toujours été.
  Future<void> setStartsOn(String programId, DayKey? day) {
    _queue.showAhead(programId, (shown) => shown.withStartsOn(day));
    return _queue.write(programId, () async {
      final repository = _ref.read(programRepositoryProvider);
      final fresh = await repository.byId(programId);
      if (fresh.startsOn == day) {
        return fresh;
      }
      return repository.save(fresh.withStartsOn(day));
    });
  }

  /// Fait reconnaître une séance par une case — ou l'en détache.
  ///
  /// HORS de la file d'écritures : celle-ci sérialise les PUT de l'état
  /// COMPLET du programme, qui s'écrasent l'un l'autre. Ce geste-ci n'écrit
  /// pas le programme, il écrit le lien d'UNE séance, et rien ne le met en
  /// concurrence avec la grille.
  ///
  /// Rend la semaine que le serveur a recalculée : l'écran la réaffiche
  /// telle quelle, sans second aller-retour ni état déduit localement.
  Future<ProgramCalendarWeek> linkCalendarSession({
    required String programId,
    required String dayId,
    required String? sessionId,
  }) async {
    final semaine = await _ref
        .read(programRepositoryProvider)
        .linkCalendarSession(
          programId: programId,
          dayId: dayId,
          sessionId: sessionId,
        );
    _ref.invalidate(programCalendarProvider);
    return semaine;
  }

  /// Un identifiant de jour, exposé pour que l'interface n'importe pas uuid.
  String newDayId() => _uuid.v4();

  Future<void> delete(String programId) async {
    await _ref.read(programRepositoryProvider).delete(programId);
    _ref.invalidate(programsProvider);
  }
}
