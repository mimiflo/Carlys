import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/synchronization/sync_lifecycle.dart';
import '../../../../design_system/design_system.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../controllers/dashboard_controllers.dart';
import '../widgets/home_hero.dart';
import '../widgets/home_stat_tiles.dart';
import '../widgets/today_workout_card.dart';
import '../widgets/week_bars.dart';

/// Accueil (maquette 2b) : zone haute avec la scène cœur et l'indice de
/// forme, séance du jour (unique CTA accent), tuiles et semaine.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Démarre les déclencheurs de synchronisation (connectivité, périodique).
    ref.watch(syncLifecycleProvider).ensureStarted();

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
        // La zone haute est à fond perdu : chaque section pose sa gouttière.
        padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.gapSection),
        children: [
          HomeHero(
            displayName: user?.displayName,
            fitnessIndex: ref.watch(fitnessIndexProvider),
            week: week,
            restSinceLastWorkout: ref.watch(restSinceLastWorkoutProvider),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
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
          const SizedBox(height: AppSpacing.gapRow),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: HomeStatTiles(report: report, week: week),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: WeekBars(week: week),
          ),
        ],
      ),
    );
  }
}
