import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/restore/app_restore.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/feedback/server_gesture.dart';
import '../../../../core/synchronization/sync_lifecycle.dart';
import '../../../../design_system/design_system.dart';
import '../../../../design_system/scenes/scene_scroll_activity.dart';
import '../../../academy/presentation/controllers/academy_controllers.dart';
import '../../../academy/presentation/widgets/quiz_card.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../carlys_profile/presentation/controllers/carlys_profile_controllers.dart';
import '../../../community/presentation/controllers/community_controllers.dart';
import '../../../mentor/presentation/controllers/mentor_controllers.dart';
import '../../../mentor/presentation/widgets/mentor_sheet.dart';
import '../../../notifications/presentation/controllers/push_registration.dart';
import '../../../nutrition/presentation/meal_entry_flow.dart';
import '../../../nutrition/presentation/widgets/water_sheet.dart';
import '../../../workout_session/presentation/controllers/workout_controllers.dart';
import '../../../workout_template/presentation/controllers/workout_template_controllers.dart';
import '../providers/form_reading_providers.dart';
import '../providers/home_day_providers.dart';
import '../widgets/consistency_streak.dart';
import '../widgets/daily_form_block.dart';
import '../widgets/for_you_card.dart';
import '../widgets/home_hero.dart';
import '../widgets/section_title_bar.dart';
import '../widgets/title_summary.dart';
import '../widgets/today_section.dart';
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

    return AppDarkScaffold(
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
              child: ConsistencyStreak(
                week: ref.watch(consistencyWeekProvider),
              ),
            ),
            // Attente, échec, ou cible connue : les trois se distinguent dans
            // TodaySection, jamais dans un `null` commun.
            _Section(
              child: TodaySection(
                onStartPrimer: () => context.push(AppRoutes.nutrition),
                onOpenHydration: () => showWaterSheet(context),
                // La MÊME porte que celle du journal, pas une copie : le
                // geste d'écriture vit dans `meal_entry_flow.dart`.
                onAddMeal: () =>
                    noteUnRepas(context, ref, scope: 'HomeTodayGrid'),
              ),
            ),
            _Section(
              child: TodayWorkoutCard(
                activeWorkout: activeWorkout,
                templateCount: ref
                    .watch(workoutTemplatesProvider)
                    .valueOrNull
                    ?.length,
                onOpenTemplates: () => context.push(AppRoutes.templates),
                onStart: () async {
                  // Même règle, même endroit que la fiche d'exercice : la
                  // décision se prend sur la BASE, et l'échec se dit. Ce
                  // bouton lisait `activeWorkout`, c'est-à-dire le cache du
                  // provider, et appelait `start()` sans filet — sur un cache
                  // en échec il partait ouvrir une séance alors qu'une séance
                  // existait, et le `StateError` du domaine le laissait sur
                  // place, sans message.
                  final abouti = await runLocalGesture(
                    context,
                    ref.read(workoutActionsProvider).currentOrStart,
                    scope: 'HomeScreen',
                    echec: 'La séance n’a pas pu être ouverte. Réessaie.',
                  );
                  if (abouti && context.mounted) {
                    await context.push(AppRoutes.activeWorkout);
                  }
                },
              ),
            ),
            const _Section(child: TitleSummary()),
            _ForYouSection(),
            if (dailyLesson != null)
              _Section(
                child: TitledSection(
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
                    onAnswered: (choice, correct) => ref
                        .read(academyActionsProvider)
                        .answer(
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
                sessions: ref
                    .watch(weekOverviewProvider)
                    .valueOrNull
                    ?.sessionsCount,
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
    final mot = ref.watch(mentorWordProvider);
    final entries = [
      // Le Mentor parle en premier : c'est lui qui fête un cap franchi, et
      // une célébration ne s'ouvre pas en troisième ligne.
      if (mot != null)
        ForYouEntry(
          icon: AppIcons.mentor,
          iconColor: AppColors.primaryLight,
          iconSize: 20,
          label: 'Le Mentor',
          message: mot.message,
          onOpen: () {
            // Une célébration touchée est DITE — mais à la FERMETURE de la
            // feuille : marquée avant, le provider recalculait en quelques
            // millisecondes et remplaçait le mot fêté par le mot ordinaire
            // sous les yeux de l'utilisateur. Le journal des récompenses
            // garde la trace durable.
            final feteeId = mot.celebratedRewardId;
            unawaited(
              showMentorSheet(context).then((_) {
                if (feteeId != null) {
                  ref
                      .read(mentorActionsProvider)
                      .marquerCelebrationDite(feteeId);
                }
              }),
            );
          },
        ),
      if (profile != null) ForYouEntry.focus(context, profile),
      if (nudge != null) ForYouEntry.encouragement(context, nudge),
    ];
    if (entries.isEmpty) return const SizedBox.shrink();

    return _Section(
      child: TitledSection(
        icon: AppIcons.forYou,
        label: 'Pour toi',
        child: ForYouCard(entries: entries),
      ),
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
