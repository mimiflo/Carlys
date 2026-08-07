import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/register_screen.dart';
import '../../features/authentication/presentation/screens/sessions_screen.dart';
import '../../features/dashboard/presentation/screens/home_screen.dart';
import '../../features/exercises/presentation/screens/exercise_detail_screen.dart';
import '../../features/exercises/presentation/screens/exercise_library_screen.dart';
import '../../features/nutrition/presentation/screens/nutrition_screen.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/workout_history/presentation/screens/workout_detail_screen.dart';
import '../../features/workout_history/presentation/screens/workout_history_screen.dart';
import '../../features/workout_session/presentation/screens/active_workout_screen.dart';
import 'app_routes.dart';

const _authRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
};

/// Routeur applicatif, gardé par l'état de session :
///  - session inconnue → splash (restauration en cours) ;
///  - non authentifié → écrans d'authentification uniquement ;
///  - authentifié → jamais sur splash/login.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshListenable = ValueNotifier(0);
  ref.onDispose(refreshListenable.dispose);
  ref.listen(authControllerProvider, (_, __) => refreshListenable.value++);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final onAuthScreen = _authRoutes.contains(location);
      final onSplash = location == AppRoutes.splash;

      return switch (authState) {
        AuthUnknown() => onSplash ? null : AppRoutes.splash,
        AuthUnauthenticated() => onAuthScreen ? null : AppRoutes.login,
        AuthAuthenticated() =>
          (onSplash || onAuthScreen) ? AppRoutes.home : null,
      };
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
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'sessions',
            name: 'sessions',
            builder: (context, state) => const SessionsScreen(),
          ),
          GoRoute(
            path: 'exercises',
            name: 'exercises',
            builder: (context, state) => const ExerciseLibraryScreen(),
            routes: [
              GoRoute(
                path: ':idOrSlug',
                name: 'exercise-detail',
                builder: (context, state) => ExerciseDetailScreen(
                  idOrSlug: state.pathParameters['idOrSlug'] ?? '',
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'workout',
            name: 'active-workout',
            builder: (context, state) => const ActiveWorkoutScreen(),
          ),
          GoRoute(
            path: 'progress',
            name: 'progress',
            builder: (context, state) => const ProgressScreen(),
          ),
          GoRoute(
            path: 'nutrition',
            name: 'nutrition',
            builder: (context, state) => const NutritionScreen(),
          ),
          GoRoute(
            path: 'subscription',
            name: 'subscription',
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: 'settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: 'history',
            name: 'history',
            builder: (context, state) => const WorkoutHistoryScreen(),
            routes: [
              GoRoute(
                path: ':sessionId',
                name: 'workout-detail',
                builder: (context, state) => WorkoutDetailScreen(
                  sessionId: state.pathParameters['sessionId'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
