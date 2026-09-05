import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import '../controllers/coach_controllers.dart';
import '../widgets/coach_header.dart';
import 'coach_screen.dart';

/// Onglet Coach : branche l'écran sur ses données.
///
/// L'écran, lui, reste présentationnel — il reçoit des messages et rend des
/// bulles. Toute la mécanique (chargement, refus du serveur, envoi, lancement
/// de la séance proposée) vit ici, et seulement ici.
class CoachPage extends ConsumerStatefulWidget {
  const CoachPage({super.key});

  @override
  ConsumerState<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends ConsumerState<CoachPage> {
  final TextEditingController _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send(String content) async {
    // Le champ ne se vide qu'une fois le message parti : sur un refus, la
    // question reste là, prête à repartir.
    final sent = await ref.read(coachThreadProvider.notifier).send(content);
    if (sent) _composer.clear();
  }

  Future<void> _openProposal(CoachSessionProposal proposal) async {
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(coachProposalActionsProvider).start(proposal);
      router.go(AppRoutes.activeWorkout);
    } on StateError {
      // Règle du domaine séance : au plus une séance en cours. On ne
      // l'interprète pas comme une erreur, on dit ce qui bloque.
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Une séance est déjà en cours. Termine-la d’abord.'),
        ),
      );
    } on AppException {
      messenger.showSnackBar(
        const SnackBar(content: Text('La séance n’a pas pu être lancée.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(coachThreadProvider);

    return thread.when(
      loading: () => const _CoachShell(
        child: AppLoadingIndicator(label: 'Ouverture du coach'),
      ),
      error: (error, _) => _CoachShell(child: _errorState(error)),
      data: (state) => CoachScreen(
        messages: state.conversation.messages,
        suggestions: ref.watch(coachSuggestionsProvider),
        composerController: _composer,
        onSend: _send,
        onOpenProposal: _openProposal,
        isOffline: state.isOffline,
        isSending: state.isSending,
        notice: state.notice,
      ),
    );
  }

  Widget _errorState(Object error) {
    // Le droit est décidé par le SERVEUR : un 403 est la seule source de
    // vérité sur l'accès au coach, jamais un calcul fait ici.
    if (error is ForbiddenException) return const _CoachPremiumState();

    if (error is NetworkException) {
      return AppErrorState(
        icon: AppIcons.offline,
        title: 'Le coach a besoin d’une connexion',
        message:
            'Reviens quand le réseau est là : la conversation reprendra '
            'où tu l’as laissée.',
        onRetry: () => ref.invalidate(coachThreadProvider),
      );
    }

    if (error is ServerException && error.statusCode == 503) {
      return AppErrorState(
        icon: AppIcons.coach,
        title: 'Le coach est en pause',
        message: 'Il est momentanément indisponible. Réessaie plus tard.',
        onRetry: () => ref.invalidate(coachThreadProvider),
      );
    }

    return AppErrorState(
      title: 'Coach indisponible',
      message: 'Réessaie dans un instant.',
      onRetry: () => ref.invalidate(coachThreadProvider),
    );
  }
}

/// Le coach fait partie de l'abonnement : sans le droit, on explique et on
/// mène à l'écran d'abonnement — on ne laisse pas une porte fermée sans clé.
class _CoachPremiumState extends ConsumerWidget {
  const _CoachPremiumState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppEmptyState(
      icon: AppIcons.premium,
      title: 'Le coach est réservé à Premium',
      message:
          'Il lit tes séances, tes records et tes mesures pour adapter '
          'ton entraînement, et te propose une séance prête à lancer.',
      actionLabel: 'Voir Premium',
      onAction: () => GoRouter.of(context).go(AppRoutes.subscription),
    );
  }
}

/// Cadre commun des états non conversationnels : même fond, même en-tête et
/// même réserve sous la barre d'onglets que l'écran plein.
///
/// L'en-tête en fait partie, et ce n'est pas décoratif : un coach qui n'a pas
/// pu s'ouvrir est le moment où l'on veut repartir. Sans sa flèche, il
/// faudrait ressortir par la barre d'onglets, donc quitter Training pour y
/// revenir.
class _CoachShell extends StatelessWidget {
  const _CoachShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            const CoachHeader(),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
