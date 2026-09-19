/// LA FORME de l'accueil : l'objectif de la semaine, l'indice qui en découle
/// et la lecture en trois bandes qui l'explique.
///
/// Des providers DÉRIVÉS, pas des contrôleurs : aucun Notifier ici, donc
/// leur place est `presentation/providers/` (règle du CLAUDE.md, et c'est
/// l'écart que ce découpage solde pour l'accueil).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../progress/data/repositories/progress_repository_impl.dart';
import '../../../progress/domain/entities/progress.dart';

/// Objectif hebdomadaire de séances — référence commune de l'indice de forme
/// et du bloc « Ta semaine ».
const int weeklySessionsTarget = 5;

/// Vue « semaine » de l'accueil — indépendante de la période sélectionnée
/// sur l'onglet Progression.
final weekOverviewProvider = FutureProvider.autoDispose<ProgressOverviewEntity>(
  (ref) {
    return ref.watch(progressRepositoryProvider).overview(ProgressPeriod.week);
  },
);

/// Indice de forme : part de l'objectif hebdomadaire déjà réalisée, sur 100.
///
/// `null` tant que la semaine n'est pas chargée — l'écran affiche alors un
/// tiret plutôt qu'une valeur inventée.
final fitnessIndexProvider = Provider.autoDispose<int?>((ref) {
  final week = ref.watch(weekOverviewProvider).valueOrNull;
  if (week == null) {
    return null;
  }
  final done = week.sessionsCount.clamp(0, weeklySessionsTarget);
  return (done / weeklySessionsTarget * 100).round();
});

/// LA LECTURE DE LA FORME, en trois bandes.
///
/// L'échelle graduée du bas de l'accueil n'est pas un score de santé : c'est
/// la part de l'objectif hebdomadaire déjà faite, dite en français. Les trois
/// bandes valent chacune un tiers — repos, charge juste, surcharge — et c'est
/// celle où tombe le score qui s'allume.
enum FormBand {
  repos('Repos'),
  chargeJuste('Charge juste'),
  surcharge('Surcharge');

  const FormBand(this.label);

  final String label;

  /// La bande où tombe un score de 0 à 100.
  static FormBand forScore(int score) {
    if (score < 34) return FormBand.repos;
    if (score < 67) return FormBand.chargeJuste;
    return FormBand.surcharge;
  }
}

/// Ce que l'échelle de forme raconte : une lecture courte et son pourquoi.
class FormReading {
  const FormReading({
    required this.score,
    required this.headline,
    required this.explanation,
  });

  final int score;

  /// Trois mots, lus d'un coup d'œil.
  final String headline;

  /// La phrase qui dit d'où vient la lecture — jamais un conseil médical,
  /// toujours un fait de la semaine.
  final String explanation;

  FormBand get band => FormBand.forScore(score);
}

/// La forme du jour, adossée aux séances RÉELLEMENT terminées de la semaine.
///
/// `null` tant que la semaine n'est pas lue : l'écran patiente au lieu
/// d'inventer une lecture.
final formReadingProvider = Provider.autoDispose<FormReading?>((ref) {
  final score = ref.watch(fitnessIndexProvider);
  final week = ref.watch(weekOverviewProvider).valueOrNull;
  if (score == null || week == null) {
    return null;
  }

  final sessions = week.sessionsCount;
  final remaining = weeklySessionsTarget - sessions;
  return switch (FormBand.forScore(score)) {
    FormBand.repos => FormReading(
      score: score,
      headline: sessions == 0 ? 'La semaine commence' : 'De la marge',
      explanation: sessions == 0
          ? 'Rien encore cette semaine. La première séance ouvre tout le '
                'reste.'
          : 'Une séance derrière toi. Le corps est frais, la place est '
                'large.',
    ),
    FormBand.chargeJuste => FormReading(
      score: score,
      headline: 'Prêt pour du lourd',
      explanation:
          '$sessions séances derrière toi, la récupération suit. '
          'Tu peux charger sans réserve aujourd’hui.',
    ),
    FormBand.surcharge => FormReading(
      score: score,
      headline: remaining <= 0 ? 'Objectif atteint' : 'Semaine chargée',
      explanation: remaining <= 0
          ? 'Les $weeklySessionsTarget séances sont faites. Ce qui vient en '
                'plus est du bonus, pas une dette.'
          : 'Le rythme est haut. Garde une journée pour récupérer, elle '
                'fait partie du travail.',
    ),
  };
});
