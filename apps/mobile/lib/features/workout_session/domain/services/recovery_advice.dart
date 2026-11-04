/// Repos conseillé après une séance : un REPÈRE GÉNÉRAL d'entraînement, pas
/// un avis médical.
///
/// Base : la recommandation de l'ACSM (48 h entre deux séances d'un même
/// groupe musculaire), modulée par l'effort perçu de la séance (Borg CR10) :
/// facile, on récupère plus vite ; à fond, plus lentement.
class RecoveryAdvice {
  const RecoveryAdvice({
    required this.rest,
    required this.muscleGroups,
    required this.until,
  });

  final Duration rest;

  /// Les groupes travaillés, sans doublon, dans l'ordre de la séance. Vide
  /// quand le catalogue n'a pas répondu (hors ligne, exercice libre).
  final List<String> muscleGroups;

  /// Fin de séance + [rest], dans le fuseau de la fin reçue.
  final DateTime until;
}

/// effort ≤ 4 → 24 h ; 5 ou 6 → 48 h ; ≥ 7 → 72 h.
Duration recoveryRest(int perceivedEffort) => switch (perceivedEffort) {
  <= 4 => const Duration(hours: 24),
  <= 6 => const Duration(hours: 48),
  _ => const Duration(hours: 72),
};

/// Le repos conseillé, ou `null` sans effort choisi ou sans fin de séance :
/// rien ne s'affiche alors.
RecoveryAdvice? recoveryAdvice({
  required int? perceivedEffort,
  required DateTime? endedAt,
  required Iterable<String> muscleGroups,
}) {
  if (perceivedEffort == null || endedAt == null) {
    return null;
  }
  final seen = <String>{};
  final rest = recoveryRest(perceivedEffort);
  return RecoveryAdvice(
    rest: rest,
    muscleGroups: [
      for (final group in muscleGroups)
        if (seen.add(group.toLowerCase())) group,
    ],
    until: endedAt.add(rest),
  );
}
