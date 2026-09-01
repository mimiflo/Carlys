import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/restore/app_restore.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/synchronization/sync_lifecycle.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/scene_scroll_activity.dart';
import '../../../academy/presentation/controllers/academy_controllers.dart';
import '../../../academy/presentation/widgets/quiz_card.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../carlys_profile/presentation/controllers/carlys_profile_controllers.dart';
import '../../../community/presentation/controllers/community_controllers.dart';
import '../../../notifications/presentation/controllers/push_registration.dart';
import '../../../nutrition/presentation/controllers/water_controllers.dart';
import '../../../nutrition/presentation/widgets/water_sheet.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';
import '../controllers/dashboard_controllers.dart';
import '../controllers/today_metrics.dart';
import '../widgets/consistency_streak.dart';
import '../widgets/daily_form_block.dart';
import '../widgets/for_you_card.dart';
import '../widgets/home_hero.dart';
import '../widgets/section_title_bar.dart';
import '../widgets/title_summary.dart';
import '../widgets/today_grid.dart';
import '../widgets/today_primer.dart';
import '../widgets/today_workout_card.dart';

/// ACCUEIL — ce que je fais aujourd'hui, et où j'en suis.
///
/// L'écran ne garde que TROIS surfaces : l'état du jour, la séance à lancer,
/// et ce que Carlys a retenu pour toi. Tout le reste vit à même le fond,
/// ouvert par une barre de titre dont le filet court jusqu'au bord. Neuf
/// cartes de densité égale ne hiérarchisaient rien ; trois surfaces posées
/// dans un rythme régulier se lisent d'un regard.
///
/// Un seul aplat orange : le disque de lecture de la séance. Les autres
/// signes d'accent (la flamme de la série, le cran de forme) restent des
/// points, jamais des surfaces.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Démarre les déclencheurs de synchronisation (connectivité, périodique)
    // puis rapatrie ce que le serveur détient — indispensable sur un appareil
    // neuf, où la base locale est vide.
    ref.watch(syncLifecycleProvider).ensureStarted();
    ref.watch(appRestoreProvider).ensureRestored();
    // Notifications push : no-op sans configuration Firebase (démo, tests).
    ref.watch(pushRegistrationProvider).ensureStarted();

    final authState = ref.watch(authControllerProvider);
    final user = switch (authState) {
      AuthAuthenticated(:final user) => user,
      _ => null,
    };
    final activeWorkout = ref.watch(activeWorkoutProvider).valueOrNull;
    final dailyLesson = ref.watch(dailyLessonProvider);
    final bottomInset =
        AppBottomBar.height + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      // Pendant le défilement, le cœur se fige et rend son budget au fil
      // d'interface — c'est lui qui faisait accrocher le haut de l'écran
      // sur les téléphones modestes.
      body: SceneScrollActivity(
        child: ListView(
          // La zone haute est à fond perdu : les sections posent leur
          // gouttière.
          padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.gapSection),
          children: [
            HomeHero(
              displayName: user?.displayName,
              subtitle: ref.watch(homeSubtitleProvider),
              quote: ref.watch(dailyQuoteProvider),
            ),
            _Section(
              child:
                  ConsistencyStreak(week: ref.watch(consistencyWeekProvider)),
            ),
            // Sans cible connue, la grille n'aurait que des tirets à montrer :
            // l'amorçage prend sa place, et lui seul porte alors son titre.
            if (ref.watch(metabolismTargetWaterMlProvider).valueOrNull == null)
              _Section(
                child: TodayPrimer(
                  onStart: () => context.push(AppRoutes.nutrition),
                ),
              )
            else
              _Section(
                child: _Titled(
                  icon: AppIcons.today,
                  label: 'Aujourd’hui',
                  child: TodayGrid(
                    metrics: ref.watch(todayMetricsProvider),
                    onOpenHydration: () => showWaterSheet(context),
                  ),
                ),
              ),
            _Section(
              child: TodayWorkoutCard(
                activeWorkout: activeWorkout,
                templateCount:
                    ref.watch(workoutTemplatesProvider).valueOrNull?.length,
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
            const _Section(child: TitleSummary()),
            _ForYouSection(),
            if (dailyLesson != null)
              _Section(
                child: _Titled(
                  icon: AppIcons.question,
                  label: 'Question du jour',
                  gap: AppSpacing.md,
                  // La MÊME question vit dans l'Academy : la réponse est
                  // partagée, dans les deux sens.
                  child: QuizCard(
                    question: dailyLesson.question,
                    answeredChoice: ref
                        .watch(answeredLessonsProvider)
                        .valueOrNull?[dailyLesson.id],
                    onAnswered: (choice, correct) =>
                        ref.read(academyActionsProvider).answer(
                              lessonId: dailyLesson.id,
                              choiceIndex: choice,
                              correct: correct,
                            ),
                  ),
                ),
              ),
            _Section(
              last: true,
              child: DailyFormBlock(
                reading: ref.watch(formReadingProvider),
                sessions:
                    ref.watch(weekOverviewProvider).valueOrNull?.sessionsCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Pour toi » : le cap de l'identité et le mot reçu. La section disparaît
/// quand il n'y a ni l'un ni l'autre — jamais une surface vide.
class _ForYouSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentCarlysProfileProvider);
    final nudge = ref.watch(latestEncouragementProvider);
    final entries = [
      if (profile != null) ForYouEntry.focus(context, profile),
      if (nudge != null) ForYouEntry.encouragement(context, nudge),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return _Section(
      child: _Titled(
        icon: AppIcons.forYou,
        label: 'Pour toi',
        child: ForYouCard(entries: entries),
      ),
    );
  }
}

/// Une section ouverte par sa barre de titre.
class _Titled extends StatelessWidget {
  const _Titled({
    required this.icon,
    required this.label,
    required this.child,
    this.gap = AppSpacing.gapRow,
  });

  final IconData icon;
  final String label;
  final Widget child;

  /// 14 avant une surface, 16 avant du contenu nu : une surface porte déjà
  /// son propre padding, un texte n'a que cet écart pour respirer.
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitleBar(icon: icon, label: label),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

/// Gouttière et rythme communs à toutes les sections de l'accueil.
class _Section extends StatelessWidget {
  const _Section({required this.child, this.last = false});

  final Widget child;

  /// La dernière section ne pose pas d'écart : le padding de la liste s'en
  /// charge, et l'ajouter creuserait le bas de l'écran.
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        last ? 0 : AppSpacing.gapSection,
      ),
      child: child,
    );
  }
}
