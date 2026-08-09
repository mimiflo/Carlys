import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/authentication/presentation/screens/sessions_screen.dart';
import '../../features/coaching/presentation/screens/coach_page.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/exercises/presentation/screens/exercise_detail_screen.dart';
import '../../features/exercises/presentation/screens/exercise_library_screen.dart';
import '../../features/nutrition/presentation/screens/nutrition_screen.dart';
import '../../features/onboarding/domain/first_run_step.dart';
import '../../features/onboarding/presentation/controllers/first_run_controller.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/welcome_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/workout_history/presentation/screens/workout_detail_screen.dart';
import '../../features/workout_history/presentation/screens/workout_history_screen.dart';
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
///  - parcours terminé, authentifié → coquille 6 onglets et plein écran.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier(0);
  ref.onDispose(refreshListenable.dispose);
  ref.listen(authControllerProvider, (_, __) => refreshListenable.value++);
  ref.listen(firstRunStepProvider, (_, __) => refreshListenable.value++);

  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final firstRunStep = ref.read(firstRunStepProvider);

      // Étape du parcours ou session encore inconnue : on patiente.
      if (firstRunStep == null) {
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

      // ── Coquille : 6 onglets avec bottom bar ──────────────────────
      // L'ordre des branches EST celui de `appBottomBarItems` : la barre
      // rend un index, la coquille ouvre la branche du même rang.
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
                path: AppRoutes.exercises,
                name: 'exercises',
                builder: (context, state) => const ExerciseLibraryScreen(),
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
            ],
          ),
          StatefulShellBranch(
            routes: [
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
                path: AppRoutes.nutrition,
                name: 'nutrition',
                builder: (context, state) => const NutritionScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                name: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
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
