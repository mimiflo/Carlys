import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/restore/app_restore.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/synchronization/sync_lifecycle.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../controllers/dashboard_controllers.dart';
import '../widgets/consistency_streak.dart';
import '../widgets/day_summary_grid.dart';
import '../widgets/fitness_index_block.dart';
import '../widgets/home_hero.dart';
import '../widgets/today_workout_card.dart';
import '../widgets/week_bars.dart';

/// Accueil — un tableau de bord en cartes, ouvert par le cœur.
///
/// Ordre de lecture : le **cœur** (signature de l'app) avec l'état du jour et
/// la citation à sa gauche, la série de constance, la séance du jour (unique
/// CTA accent), le résumé du jour, puis l'indice de forme adossé à
/// « Ta semaine ».
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Démarre les déclencheurs de synchronisation (connectivité, périodique)
    // puis rapatrie ce que le serveur détient — indispensable sur un appareil
    // neuf, où la base locale est vide.
    ref.watch(syncLifecycleProvider).ensureStarted();
    ref.watch(appRestoreProvider).ensureRestored();

    final authState = ref.watch(authControllerProvider);
    final user = switch (authState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final activeWorkout = ref.watch(activeWorkoutProvider).valueOrNull;
    final week = ref.watch(weekOverviewProvider).valueOrNull;
    final report = ref.watch(metabolismReportProvider).valueOrNull;
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: ListView(
        // La zone haute est à fond perdu : les cartes posent leur gouttière.
        padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.gapSection),
        children: [
          HomeHero(
            displayName: user?.displayName,
            subtitle: ref.watch(homeSubtitleProvider),
            quote: ref.watch(dailyQuoteProvider),
          ),
          _Section(
            child: ConsistencyStreak(week: ref.watch(consistencyWeekProvider)),
          ),
          _Section(
            child: TodayWorkoutCard(
              activeWorkout: activeWorkout,
              onOpenTemplates: () => context.push(AppRoutes.templates),
              onStart: () async {
                if (activeWorkout == null) {
                  await ref.read(workoutActionsProvider).start();
                }
                if (context.mounted) {
                  await context.push(AppRoutes.activeWorkout);
                }
              },
            ),
          ),
          _Section(
            child: DaySummaryGrid(
              training: ref.watch(todayTrainingProvider),
              report: report,
              week: week,
            ),
          ),
          _Section(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // L'indice de forme EST le taux d'accomplissement de
                // l'objectif hebdomadaire : sa place est contre les barres
                // qui le détaillent, pas seul en haut d'écran.
                FitnessIndexBlock(score: ref.watch(fitnessIndexProvider)),
                const SizedBox(height: AppSpacing.gapRow),
                WeekBars(week: week),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gouttière et espacement communs à toutes les sections de l'accueil.
class _Section extends StatelessWidget {
  const _Section({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.gapRow,
      ),
      child: child,
    );
  }
}
