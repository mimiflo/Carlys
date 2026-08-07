/// Données du MODE DÉMO (flavor `demo` uniquement).
///
/// Exception documentée à la règle « pas de données codées en dur » : ce
/// jeu de données n'existe que pour la visite de l'application sans serveur
/// (APK de démonstration). Il n'est JAMAIS chargé en development, staging ou
/// production — voir `demo_overrides.dart` et `bootstrap.dart`.
library;

import '../features/authentication/domain/entities/auth_user.dart';
import '../features/exercises/domain/entities/exercise.dart';
import '../features/progress/domain/entities/progress.dart';

const demoUser = AuthUser(
  id: 'demo-user',
  email: 'demo@carlys.app',
  displayName: 'Visiteur Carlys',
  emailVerified: true,
  locale: 'fr',
  timezone: 'Europe/Paris',
);

const _mg = {
  'pectoraux':
      MuscleGroupRef(id: 'mg-pec', slug: 'pectoraux', name: 'Pectoraux'),
  'dos': MuscleGroupRef(id: 'mg-dos', slug: 'dos', name: 'Dos'),
  'quadriceps':
      MuscleGroupRef(id: 'mg-quad', slug: 'quadriceps', name: 'Quadriceps'),
  'epaules': MuscleGroupRef(id: 'mg-epa', slug: 'epaules', name: 'Épaules'),
  'biceps': MuscleGroupRef(id: 'mg-bic', slug: 'biceps', name: 'Biceps'),
  'triceps': MuscleGroupRef(id: 'mg-tri', slug: 'triceps', name: 'Triceps'),
  'abdominaux':
      MuscleGroupRef(id: 'mg-abd', slug: 'abdominaux', name: 'Abdominaux'),
  'fessiers': MuscleGroupRef(id: 'mg-fes', slug: 'fessiers', name: 'Fessiers'),
  'lombaires':
      MuscleGroupRef(id: 'mg-lom', slug: 'lombaires', name: 'Lombaires'),
};

List<MuscleGroupRef> get demoMuscleGroups => _mg.values.toList();

const _barbell = EquipmentRef(id: 'eq-bar', slug: 'barre', name: 'Barre');
const _dumbbell =
    EquipmentRef(id: 'eq-hal', slug: 'halteres', name: 'Haltères');
const _bodyweight =
    EquipmentRef(id: 'eq-pdc', slug: 'poids-du-corps', name: 'Poids du corps');

ExerciseDetail _exercise(
  String id,
  String name, {
  required String group,
  required ExerciseDifficulty difficulty,
  required String description,
  required List<String> instructions,
  ExerciseKind kind = ExerciseKind.strength,
  List<EquipmentRef> equipment = const [_barbell],
  List<String> secondary = const [],
  bool isPremium = false,
}) {
  final primary = _mg[group]!;
  return ExerciseDetail(
    id: id,
    slug: id,
    name: name,
    difficulty: difficulty,
    kind: kind,
    isPremium: isPremium,
    primaryMuscleGroup: primary,
    equipment: equipment,
    description: description,
    instructions: instructions,
    tags: const ['démo'],
    muscles: [
      ExerciseMuscleLink(muscleGroup: primary, isPrimary: true),
      for (final slug in secondary)
        ExerciseMuscleLink(muscleGroup: _mg[slug]!, isPrimary: false),
    ],
  );
}

final List<ExerciseDetail> demoExercises = [
  _exercise(
    'developpe-couche',
    'Développé couché',
    group: 'pectoraux',
    difficulty: ExerciseDifficulty.intermediate,
    description: 'Le grand classique de la force du haut du corps : poussée '
        'horizontale à la barre, allongé sur un banc.',
    instructions: [
      'Allongez-vous, pieds au sol, omoplates serrées.',
      'Saisissez la barre un peu plus large que les épaules.',
      'Descendez la barre au niveau des pectoraux, coudes à 45°.',
      'Poussez jusqu’à l’extension complète sans verrouiller brutalement.',
    ],
    secondary: ['triceps', 'epaules'],
  ),
  _exercise(
    'squat',
    'Squat',
    group: 'quadriceps',
    difficulty: ExerciseDifficulty.intermediate,
    description:
        'Flexion de jambes complète, barre sur les trapèzes : le mouvement '
        'roi pour le bas du corps.',
    instructions: [
      'Barre haute sur les trapèzes, pieds largeur d’épaules.',
      'Descendez en poussant les hanches en arrière, dos neutre.',
      'Cassez la parallèle si votre mobilité le permet.',
      'Remontez en poussant le sol, genoux dans l’axe des orteils.',
    ],
    secondary: ['fessiers', 'lombaires'],
  ),
  _exercise(
    'souleve-de-terre',
    'Soulevé de terre',
    group: 'lombaires',
    difficulty: ExerciseDifficulty.advanced,
    description:
        'Tirage du sol jusqu’à la station debout : la chaîne postérieure '
        'entière au travail.',
    instructions: [
      'Barre au-dessus du milieu du pied, prise juste hors des jambes.',
      'Dos plat, poitrine ouverte, tension dans la barre avant de tirer.',
      'Poussez le sol et tenez la barre proche du corps.',
      'Verrouillez debout, hanches et genoux tendus, sans hyper-extension.',
    ],
    secondary: ['fessiers', 'dos'],
  ),
  _exercise(
    'tractions',
    'Tractions',
    group: 'dos',
    difficulty: ExerciseDifficulty.intermediate,
    description:
        'Tirage vertical au poids du corps, la référence pour l’épaisseur '
        'et la largeur du dos.',
    instructions: [
      'Suspendez-vous, prise pronation un peu plus large que les épaules.',
      'Tirez les coudes vers le bas jusqu’au menton au-dessus de la barre.',
      'Contrôlez la descente jusqu’à l’extension complète.',
    ],
    equipment: const [_bodyweight],
    secondary: ['biceps'],
  ),
  _exercise(
    'rowing-halteres',
    'Rowing haltère',
    group: 'dos',
    difficulty: ExerciseDifficulty.beginner,
    description:
        'Tirage horizontal unilatéral, un genou sur le banc : idéal pour '
        'apprendre à sentir le dos.',
    instructions: [
      'Genou et main sur le banc, dos parallèle au sol.',
      'Tirez l’haltère vers la hanche, coude près du corps.',
      'Redescendez lentement sans tourner le buste.',
    ],
    equipment: const [_dumbbell],
    secondary: ['biceps'],
  ),
  _exercise(
    'developpe-militaire',
    'Développé militaire',
    group: 'epaules',
    difficulty: ExerciseDifficulty.intermediate,
    description: 'Poussée verticale debout à la barre : force des épaules et '
        'gainage complet.',
    instructions: [
      'Barre au niveau des clavicules, coudes légèrement en avant.',
      'Poussez à la verticale en gainant fessiers et abdominaux.',
      'Passez la tête « à travers » une fois la barre au-dessus du front.',
    ],
    secondary: ['triceps'],
  ),
  _exercise(
    'curl-halteres',
    'Curl haltères',
    group: 'biceps',
    difficulty: ExerciseDifficulty.beginner,
    description: 'Flexion de coude stricte, la base pour des biceps solides.',
    instructions: [
      'Debout, coudes collés au buste.',
      'Montez les haltères en supination sans élan.',
      'Redescendez sur 2 à 3 secondes.',
    ],
    equipment: const [_dumbbell],
  ),
  _exercise(
    'dips',
    'Dips',
    group: 'triceps',
    difficulty: ExerciseDifficulty.intermediate,
    description:
        'Poussée verticale entre deux barres parallèles, redoutable pour '
        'triceps et pectoraux.',
    instructions: [
      'Bras tendus sur les barres, buste légèrement penché.',
      'Descendez jusqu’à ce que les épaules passent sous les coudes.',
      'Remontez en poussant fort, sans balancer les jambes.',
    ],
    equipment: const [_bodyweight],
    secondary: ['pectoraux'],
  ),
  _exercise(
    'fentes-marchees',
    'Fentes marchées',
    group: 'fessiers',
    difficulty: ExerciseDifficulty.beginner,
    description:
        'Pas alternés en fente : unilatéral, complet et transférable au '
        'quotidien.',
    instructions: [
      'Grand pas en avant, buste droit.',
      'Descendez le genou arrière près du sol.',
      'Poussez sur la jambe avant pour enchaîner le pas suivant.',
    ],
    equipment: const [_dumbbell],
    secondary: ['quadriceps'],
  ),
  _exercise(
    'gainage-planche',
    'Gainage planche',
    group: 'abdominaux',
    difficulty: ExerciseDifficulty.beginner,
    kind: ExerciseKind.mobility,
    description: 'Maintien statique sur les avant-bras : le socle de tous les '
        'mouvements chargés.',
    instructions: [
      'Avant-bras au sol, corps aligné des talons à la tête.',
      'Serrez fessiers et abdominaux, respirez calmement.',
      'Tenez la durée cible sans creuser les lombaires.',
    ],
    equipment: const [_bodyweight],
  ),
  _exercise(
    'balancier-kettlebell',
    'Balancier kettlebell',
    group: 'fessiers',
    difficulty: ExerciseDifficulty.advanced,
    isPremium: true,
    description:
        'Swing russe : extension de hanche explosive, cardio et chaîne '
        'postérieure — contenu Premium, débloqué dans cette démo.',
    instructions: [
      'Kettlebell entre les jambes, dos plat, hanches armées.',
      'Projetez les hanches vers l’avant, bras relâchés.',
      'Laissez la cloche redescendre et enchaînez sans arrondir le dos.',
    ],
    equipment: const [_dumbbell],
    secondary: ['lombaires'],
  ),
];

List<PersonalRecordEntry> get demoRecords => [
      _record('Développé couché', PersonalRecordType.maxWeight, 82.5, 2),
      _record('Développé couché', PersonalRecordType.maxReps, 12, 9),
      _record('Développé couché', PersonalRecordType.maxSetVolume, 720, 2),
      _record('Squat', PersonalRecordType.maxWeight, 110, 4),
      _record('Squat', PersonalRecordType.maxSetVolume, 880, 4),
      _record('Soulevé de terre', PersonalRecordType.maxWeight, 140, 11),
      _record('Tractions', PersonalRecordType.maxReps, 14, 6),
    ];

PersonalRecordEntry _record(
  String exercise,
  PersonalRecordType type,
  double value,
  int daysAgo,
) =>
    PersonalRecordEntry(
      id: 'pr-$exercise-${type.apiValue}',
      exerciseName: exercise,
      type: type,
      value: value,
      achievedAt: DateTime.utc(2026, 8, 7).subtract(Duration(days: daysAgo)),
    );

/// Courbe de poids sur huit semaines — termine à 79,8 kg (IMC normal).
List<BodyMetricEntry> get demoWeights => [
      for (final (index, value) in const [
        84.2,
        83.6,
        83.9,
        82.8,
        82.1,
        81.4,
        80.5,
        79.8,
      ].indexed)
        BodyMetricEntry(
          id: 'demo-w-$index',
          kind: BodyMetricKind.weightKg,
          value: value,
          measuredAt: DateTime.utc(2026, 6, 12).add(Duration(days: index * 8)),
        ),
    ];
