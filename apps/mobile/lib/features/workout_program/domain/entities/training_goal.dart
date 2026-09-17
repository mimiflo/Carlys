/// Objectif d'ENTRAÎNEMENT — un axe distinct de l'objectif nutritionnel :
/// viser un marathon en recomposition corporelle est parfaitement cohérent,
/// les deux questions se posent donc séparément et s'écrivent séparément.
///
/// C'est l'entrée première de la génération de programme (Plan 4) : chaque
/// objectif portera ses règles (fréquence, répartition, cardio,
/// progression). Nul tant que la personne n'a pas choisi — jamais un
/// objectif deviné.
enum TrainingGoal {
  fatLoss('FAT_LOSS', 'Perte de gras', 'Sécher en gardant le muscle.'),
  muscleGain(
    'MUSCLE_GAIN',
    'Prise de muscle',
    'Construire du volume, séance après séance.',
  ),
  recomposition(
    'RECOMPOSITION',
    'Recomposition',
    'Moins de gras, plus de muscle, même poids.',
  ),
  hyrox('HYROX', 'Hyrox', 'Force et cardio mêlés, format course.'),
  marathon('MARATHON', 'Marathon', 'Endurance longue, jambes solides.'),
  maintenance(
    'MAINTENANCE',
    'Maintien',
    'Garder la forme acquise, sans pression.',
  ),
  strength('STRENGTH', 'Force', 'Des charges lourdes, des bases simples.'),
  calisthenics(
    'CALISTHENICS',
    'Callisthénie',
    'Le poids du corps comme seule barre.',
  );

  const TrainingGoal(this.wire, this.label, this.description);

  /// Valeur échangée avec l'API.
  final String wire;

  final String label;

  /// Ce que l'objectif vise, dit à la personne qui choisit.
  final String description;

  /// Null pour une valeur absente OU inconnue : un serveur plus récent qui
  /// ajouterait un objectif ne doit pas faire planter les anciens clients.
  static TrainingGoal? fromWire(String? wire) {
    for (final goal in values) {
      if (goal.wire == wire) {
        return goal;
      }
    }
    return null;
  }
}
