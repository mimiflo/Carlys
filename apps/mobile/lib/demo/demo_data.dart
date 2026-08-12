/// Données du MODE DÉMO (flavor `demo` uniquement).
///
/// Exception documentée à la règle « pas de données codées en dur » : ce
/// jeu de données n'existe que pour la visite de l'application sans serveur
/// (APK de démonstration). Il n'est JAMAIS chargé en development, staging ou
/// production — voir `demo_overrides.dart` et `bootstrap.dart`.
///
/// Le CATALOGUE d'exercices ne figure PAS ici : il est engendré depuis le seed
/// de l'API et lu par `demo_catalog.dart`. Recopié à la main, il avait dérivé
/// jusqu'à ne plus montrer que onze exercices sur cinquante-cinq.
library;

import '../features/authentication/domain/entities/auth_user.dart';
import '../features/carlys_profile/domain/entities/carlys_profile.dart';
import '../features/progress/domain/entities/progress.dart';

const demoUser = AuthUser(
  id: 'demo-user',
  email: 'demo@carlys.app',
  displayName: 'Visiteur Carlys',
  emailVerified: true,
  locale: 'fr',
  timezone: 'Europe/Paris',
  // Le visiteur a déjà choisi : la visite montre l'état « profil choisi »,
  // et l'écran des profils permet d'en changer, comme en production.
  carlysProfile: CarlysProfile.challenger,
);

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
      achievedAt: DateTime.now().toUtc().subtract(Duration(days: daysAgo)),
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
          measuredAt:
              DateTime.now().toUtc().subtract(Duration(days: (7 - index) * 8)),
        ),
    ];
