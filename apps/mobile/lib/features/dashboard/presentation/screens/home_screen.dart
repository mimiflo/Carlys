import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/synchronization/sync_lifecycle.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/app_scene_container.dart';
import '../../../../design_system/scenes/heart_scene.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../nutrition/presentation/controllers/nutrition_controllers.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../controllers/dashboard_controllers.dart';
import '../widgets/forme_card.dart';
import '../widgets/home_header.dart';
import '../widgets/home_stat_tiles.dart';
import '../widgets/today_workout_card.dart';
import '../widgets/week_bars.dart';

/// Accueil (maquette 2a) : scène ambiante, indice de forme, séance du
/// jour (unique CTA accent), tuiles et semaine.
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
      body: Stack(
        children: [
          // Scène du cœur, ancrée haut-droite, débordant du cadre (2a).
          const Positioned(
            top: 22,
            right: -126,
            child: AppSceneContainer(
              size: 330,
              opacity: 0.9,
              verticalFadeStops: [0.0, 0.18, 0.56, 0.90],
              child: HeartScene(),
            ),
          ),
          const Positioned.fill(child: AppSceneScrim.vertical()),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.md,
                AppSpacing.gutter,
                bottomInset + AppSpacing.gutter,
              ),
              children: [
                HomeHeader(displayName: user?.displayName),
                const SizedBox(height: AppSpacing.gutter),
                FormeCard(week: week),
                const SizedBox(height: AppSpacing.md),
                TodayWorkoutCard(
                  activeWorkout: activeWorkout,
                  onStart: () async {
                    if (activeWorkout == null) {
                      await ref.read(workoutActionsProvider).start();
                    }
                    if (context.mounted) {
                      await context.push(AppRoutes.activeWorkout);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                HomeStatTiles(report: report, week: week),
                const SizedBox(height: AppSpacing.gapSection),
                WeekBars(week: week),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
