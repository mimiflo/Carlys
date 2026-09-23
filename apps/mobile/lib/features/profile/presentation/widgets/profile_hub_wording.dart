/// LES PHRASES DU PROFIL, écrites une fois.
///
/// Des fonctions pures : chaque ligne du profil se vérifie en test sans
/// monter d'écran, et deux lignes qui disent la même chose ne peuvent plus
/// l'écrire différemment.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../workout_program/domain/program_advancement.dart';

/// Le nom accordé : en français, zéro et un sont au singulier.
String accordCount(int count, String singular, String plural) =>
    '${formatThousands(count)} ${count <= 1 ? singular : plural}';

/// La ligne d'un compte servi par le serveur, dans ses trois états.
///
/// L'attente ne dit rien (`null`) : un compte qui n'est pas encore là
/// n'affirme rien, et un « … » se rallumerait à chaque ouverture. L'échec,
/// lui, se DIT — hors ligne ou non — pour qu'un vide ne passe pas pour un
/// zéro.
String? countLine(
  AsyncValue<int> count, {
  required String none,
  required String singular,
  required String plural,
}) {
  return switch (count) {
    AsyncData(:final value) =>
      value == 0 ? none : accordCount(value, singular, plural),
    AsyncError(:final error) => unavailableLine(error),
    _ => null,
  };
}

/// Ce qu'une ligne dit quand sa source n'a pas répondu.
String unavailableLine(Object error) => error is NetworkException
    ? 'Hors connexion'
    : 'Indisponible pour l’instant';

/// « 4 séances par semaine · 8 semaines », ou le total quand les semaines
/// ne se ressemblent pas.
String rhythmLine(ProgramRhythm rhythm, int weeksCount) {
  final weeks = accordCount(weeksCount, 'semaine', 'semaines');
  final perWeek = rhythm.sessionsPerWeek;
  final sessions = perWeek == null
      ? accordCount(rhythm.total, 'séance', 'séances')
      : '${accordCount(perWeek, 'séance', 'séances')} par semaine';
  return '$sessions · $weeks';
}

/// Où en est le plan, dans l'unité du plan — la semaine — avant tout
/// pourcentage.
String positionLine(ProgramAdvancement advancement) {
  return switch (advancement.phase) {
    ProgramPhase.upcoming =>
      advancement.daysUntilStart == 1
          ? 'Commence demain'
          : 'Commence dans ${advancement.daysUntilStart} jours',
    ProgramPhase.running =>
      'Semaine ${advancement.weekNumber} sur ${advancement.weeksCount}',
    ProgramPhase.finished => 'Programme terminé',
  };
}

/// Le pourcentage, avec son espace insécable : « 24 % » ne se coupe jamais
/// en fin de ligne.
String percentText(ProgramAdvancement advancement) =>
    '${advancement.percent}\u00A0%';
