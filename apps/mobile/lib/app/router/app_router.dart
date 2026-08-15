import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/academy/presentation/screens/academy_screen.dart';
import '../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/authentication/presentation/screens/sessions_screen.dart';
import '../../features/carlys_profile/presentation/screens/carlys_profiles_screen.dart';
import '../../features/coaching/presentation/screens/coach_page.dart';
import '../../features/community/presentation/screens/community_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/exercises/presentation/screens/exercise_detail_screen.dart';
import '../../features/exercises/presentation/screens/exercise_library_screen.dart';
import '../../features/nutrition/presentation/screens/nutrition_screen.dart';
import '../../features/onboarding/domain/first_run_step.dart';
import '../../features/onboarding/presentation/controllers/first_run_controller.dart';
import '../../features/onboarding/presentation/controllers/splash_gate.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/progression/presentation/screens/manifesto_screen.dart';
import '../../features/progression/presentation/screens/progression_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/training/presentation/screens/training_hub_screen.dart';
import '../../features/workout_history/presentation/screens/workout_detail_screen.dart';
import '../../features/workout_history/presentation/screens/workout_history_screen.dart';
import '../../features/workout_program/presentation/screens/program_detail_screen.dart';
import '../../features/workout_program/presentation/screens/programs_screen.dart';
import '../../features/workout_session/presentation/screens/active_workout_screen.dart';
import '../../features/workout_template/presentation/screens/template_editor_screen.dart';
import '../../features/workout_template/presentation/screens/templates_screen.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';

const _authRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Destination imposée par le PARCOURS DE PREMIÈRE OUVERTURE, ou `null` si
/// l'emplacement demandé est légitime à cette étape.
///
/// Le tunnel se traverse par redirection : page de marque → onboarding →
/// création de compte →
/// proposition Premium → accueil. La connexion reste accessible depuis
/// l'onboarding (« j'ai déjà un compte ») et depuis l'étape compte ; une
/// fois la session ouverte, le parcours reprend là où il en était.
String? _firstRunRedirect(
  FirstRunStep step,
  String location, {
  required bool authenticated,
}) {
  final onAuthScreen = _authRoutes.contains(location) && !authenticated;

  return switch (step) {
    // Rien n'est demandé ici : aucune échappatoire vers l'authentification.
    FirstRunStep.welcome =>
      location == AppRoutes.welcome ? null : AppRoutes.welcome,
    FirstRunStep.onboarding =>
      (location == AppRoutes.onboarding || onAuthScreen)
          ? null
          : AppRoutes.onboarding,
    FirstRunStep.account => onAuthScreen ? null : AppRoutes.register,
    FirstRunStep.subscription =>
      location == AppRoutes.subscription ? null : AppRoutes.subscription,
    FirstRunStep.done => null,
  };
}

/// Routeur applicatif, gardé par le parcours de première ouverture puis par
/// l'état de session :
///  - parcours ou session inconnus → splash (restauration en cours) ;
///  - parcours en cours → tunnel de première ouverture ;
///  - parcours terminé, non authentifié → écrans d'authentification ;
///  - parcours terminé, authentifié → coquille 5 onglets et plein écran.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier(0);
  ref.onDispose(refreshListenable.dispose);
  ref.listen(authControllerProvider, (_, __) => refreshListenable.value++);
  ref.listen(firstRunStepProvider, (_, __) => refreshListenable.value++);
  ref.listen(splashGateProvider, (_, __) => refreshListenable.value++);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final firstRunStep = ref.read(firstRunStepProvider);

      // Étape du parcours ou session encore inconnue : on patiente. Le
      // plancher de l'écran de démarrage retient de la même façon — c'est
      // un MINIMUM d'affichage, pas une addition : la restauration court
      // pendant ce temps et la plus longue des deux commande.
      if (firstRunStep == null || !ref.read(splashGateProvider)) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }

      final authenticated =
          ref.read(authControllerProvider) is AuthAuthenticated;

      if (firstRunStep.isTunnel) {
        return _firstRunRedirect(
          firstRunStep,
          location,
          authenticated: authenticated,
        );
      }

      final onAuthScreen = _authRoutes.contains(location);
      final onSplash = location == AppRoutes.splash;

      return authenticated
          ? ((onSplash || onAuthScreen) ? AppRoutes.home : null)
          : (onAuthScreen ? null : AppRoutes.login);
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // ── Coquille : 5 onglets avec bottom bar ──────────────────────
      // L'ordre des branches EST celui de `appBottomBarItems` : la barre
      // rend un index, la coquille ouvre la branche du même rang.
      //
      // Une branche peut porter PLUSIEURS routes racines : les écrans
      // regroupés sous un onglet (exercices et coach sous Training, la
      // nutrition sous Academy) se poussent dans la pile de leur branche —
      // la bottom bar reste visible, et « retour » ramène au hub.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                name: 'home',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.training,
                name: 'training',
                builder: (context, state) => const TrainingHubScreen(),
              ),
              GoRoute(
                path: AppRoutes.exercises,
                name: 'exercises',
                // `?groupe=<slug>` ouvre la bibliothèque déjà filtrée sur un
                // muscle (fiches d'anatomie de l'Academy).
                builder: (context, state) => ExerciseLibraryScreen(
                  initialMuscleGroupSlug: state.uri.queryParameters['groupe'],
                ),
                routes: [
                  GoRoute(
                    path: ':idOrSlug',
                    name: 'exercise-detail',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => ExerciseDetailScreen(
                      idOrSlug: state.pathParameters['idOrSlug'] ?? '',
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: AppRoutes.coach,
                name: 'coach',
                builder: (context, state) => const CoachPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                name: 'progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.academy,
                name: 'academy',
                builder: (context, state) => const AcademyScreen(),
              ),
              GoRoute(
                path: AppRoutes.nutrition,
                name: 'nutrition',
                builder: (context, state) => const NutritionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.community,
                name: 'community',
                builder: (context, state) => const CommunityScreen(),
              ),
            ],
          ),
        ],
      ),

      // Le profil n'est plus un onglet : il s'ouvre depuis l'avatar de
      // l'accueil, en plein écran — les réglages sont un aparté, pas une
      // destination quotidienne.
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProfileScreen(),
      ),

      // ── Plein écran, hors coquille (pas de bottom bar) ────────────
      GoRoute(
        path: AppRoutes.activeWorkout,
        name: 'active-workout',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      // Les modèles de séance : liste puis éditeur. Pas de `/templates/new` —
      // l'identifiant d'un nouveau modèle est un UUID généré sur l'appareil.
      GoRoute(
        path: AppRoutes.templates,
        name: 'templates',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TemplatesScreen(),
        routes: [
          GoRoute(
            path: ':templateId',
            name: 'template-editor',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => TemplateEditorScreen(
              templateId: state.pathParameters['templateId'] ?? '',
            ),
          ),
        ],
      ),
      // Les programmes : liste puis calendrier. Pas de `/programs/new` — un
      // nouveau programme naît d'un UUID généré sur l'appareil.
      GoRoute(
        path: AppRoutes.programs,
        name: 'programs',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProgramsScreen(),
        routes: [
          GoRoute(
            path: ':programId',
            name: 'program-detail',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => ProgramDetailScreen(
              programId: state.pathParameters['programId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.history,
        name: 'history',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WorkoutHistoryScreen(),
        routes: [
          GoRoute(
            path: ':sessionId',
            name: 'workout-detail',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => WorkoutDetailScreen(
              sessionId: state.pathParameters['sessionId'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.sessions,
        name: 'sessions',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SessionsScreen(),
      ),
      GoRoute(
        path: AppRoutes.subscription,
        name: 'subscription',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.progression,
        name: 'progression',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProgressionScreen(),
      ),
      GoRoute(
        path: AppRoutes.manifesto,
        name: 'manifesto',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ManifestoScreen(),
      ),
      GoRoute(
        path: AppRoutes.carlysProfiles,
        name: 'carlys-profiles',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CarlysProfilesScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OnboardingScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
