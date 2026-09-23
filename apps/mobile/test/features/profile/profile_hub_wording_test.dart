import 'package:carlys_mobile/core/errors/app_exception.dart';
import 'package:carlys_mobile/features/profile/presentation/widgets/profile_hub_wording.dart';
import 'package:carlys_mobile/features/workout_program/domain/program_advancement.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les phrases du profil, sans écran.
void main() {
  group('accordCount', () {
    test('zéro et un au singulier, comme en français', () {
      expect(accordCount(0, 'badge', 'badges'), '0 badge');
      expect(accordCount(1, 'badge', 'badges'), '1 badge');
      expect(accordCount(2, 'badge', 'badges'), '2 badges');
    });

    test('les milliers se séparent', () {
      expect(accordCount(1240, 'séance', 'séances'), '1\u202F240 séances');
    });
  });

  group('countLine', () {
    String? line(AsyncValue<int> count) =>
        countLine(count, none: 'Aucun encore', singular: 'ami', plural: 'amis');

    test('servi : le compte accordé, zéro dit autrement', () {
      expect(line(const AsyncData(12)), '12 amis');
      expect(line(const AsyncData(0)), 'Aucun encore');
    });

    test('en route : rien, plutôt qu’un zéro provisoire', () {
      expect(line(const AsyncLoading()), isNull);
    });

    test('échec : la cause, hors ligne ou non', () {
      expect(
        line(const AsyncError(NetworkException('socket'), StackTrace.empty)),
        'Hors connexion',
      );
      expect(
        line(const AsyncError(ServerException('500'), StackTrace.empty)),
        'Indisponible pour l’instant',
      );
    });
  });

  group('rhythmLine', () {
    test('semaines égales : par semaine', () {
      expect(
        rhythmLine(const ProgramRhythm(sessionsPerWeek: 4, total: 32), 8),
        '4 séances par semaine · 8 semaines',
      );
    });

    test('semaines inégales : le total, jamais une moyenne', () {
      expect(
        rhythmLine(const ProgramRhythm(sessionsPerWeek: null, total: 7), 2),
        '7 séances · 2 semaines',
      );
    });

    test('au singulier quand il le faut', () {
      expect(
        rhythmLine(const ProgramRhythm(sessionsPerWeek: 1, total: 1), 1),
        '1 séance par semaine · 1 semaine',
      );
    });
  });

  group('positionLine', () {
    ProgramAdvancement at(ProgramPhase phase, {int daysUntilStart = 0}) =>
        ProgramAdvancement(
          phase: phase,
          weekNumber: 3,
          weeksCount: 8,
          elapsedDays: 16,
          totalDays: 56,
          daysUntilStart: daysUntilStart,
        );

    test('en cours : la semaine, dans l’unité du plan', () {
      expect(positionLine(at(ProgramPhase.running)), 'Semaine 3 sur 8');
    });

    test('à venir : le compte à rebours', () {
      expect(
        positionLine(at(ProgramPhase.upcoming, daysUntilStart: 1)),
        'Commence demain',
      );
      expect(
        positionLine(at(ProgramPhase.upcoming, daysUntilStart: 4)),
        'Commence dans 4 jours',
      );
    });

    test('fini : dit comme tel', () {
      expect(positionLine(at(ProgramPhase.finished)), 'Programme terminé');
    });

    test('le pourcentage garde son espace insécable', () {
      expect(percentText(at(ProgramPhase.running)), '28\u00A0%');
    });
  });
}
