import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/feedback/server_gesture.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import '../../domain/services/coach_greeting.dart';
import '../../domain/services/coach_suggestions.dart';
import '../controllers/coach_controllers.dart';
import '../providers/coach_program_actions.dart';
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

  /// Programme proposé en cours de création : un second appui n'en engendre
  /// pas un second, et sa carte patiente.
  String? _busyProgramId;

  /// Le bonjour de CETTE ouverture : écrit une fois, à sa place dans le
  /// fil, et qui y reste pendant la visite.
  CoachGreeting? _greeting;

  /// Les amorces lancent la conversation du JOUR : dès la première question
  /// partie (ou déjà posée aujourd'hui), elles s'effacent jusqu'au lendemain.
  List<String> _suggestionsFor(CoachThreadState state) {
    final suggestions = ref.watch(coachSuggestionsProvider);
    final started =
        state.live != null ||
        coachWroteToday(state.conversation.messages, DateTime.now());
    return started ? const [] : suggestions;
  }

  /// Pas de bonjour à qui ne peut pas écrire (fil en lecture seule, hors
  /// ligne) : le coach n'inviterait qu'à une question qu'il ne recevra pas.
  CoachGreeting? _greet(CoachThreadState state) {
    if (state.isReadOnly || state.isOffline) return null;
    final voice = ref.read(coachVoiceProvider);
    final messages = state.conversation.messages;
    final now = DateTime.now();
    return CoachGreeting(
      text: coachGreeting(
        displayName: voice.displayName,
        style: voice.style,
        returning: messages.isNotEmpty,
        now: now,
      ),
      after: messages.length,
      at: now,
    );
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _send(String content) async {
    // La question quitte le champ tout de suite : elle s'affiche dans le fil,
    // au-dessus de la réponse qui s'écrit. Sur un refus, elle y revient,
    // prête à repartir — rien n'est perdu.
    _composer.clear();
    final sent = await ref.read(coachThreadProvider.notifier).send(content);
    if (!sent && _composer.text.isEmpty) _composer.text = content;
  }

  Future<void> _openProposal(CoachSessionProposal proposal) async {
    final router = GoRouter.of(context);
    final notices = AppNotices.of(context);

    try {
      await ref.read(coachProposalActionsProvider).start(proposal);
      router.go(AppRoutes.activeWorkout);
    } on StateError {
      // Règle du domaine séance : au plus une séance en cours. On ne
      // l'interprète pas comme une erreur, on dit ce qui bloque.
      notices.show('Une séance est déjà en cours. Termine-la d’abord.');
    } on AppException {
      notices.show(
        'La séance n’a pas pu être lancée.',
        tone: AppNoticeTone.error,
      );
    }
  }

  Future<void> _openProgram(CoachProgramProposal proposal) async {
    if (_busyProgramId != null) return;
    final router = GoRouter.of(context);
    final notices = AppNotices.of(context);

    setState(() => _busyProgramId = proposal.id);
    try {
      final programId = await ref
          .read(coachProgramActionsProvider)
          .start(proposal);
      // Le fil se relit : la carte dira « Voir le programme » au retour.
      if (!proposal.isAccepted) ref.invalidate(coachThreadProvider);
      router.go(AppRoutes.programDetail(programId));
    } on ValidationException catch (exception) {
      // Niveau ou matériel manquants, ou objectif impossible avec ce
      // matériel (400, 409) : le serveur nomme la cause, et l'écran de
      // préparation est celui qui la corrige.
      notices.show(serverFailureMessage(exception), tone: AppNoticeTone.error);
      router.go(AppRoutes.programSetup);
    } on AppException catch (exception) {
      // Plafond du plan gratuit, hors ligne… : la phrase de celui qui
      // refuse, jamais un « ça n'a pas marché » qui inviterait à réessayer
      // un geste voué à échouer.
      notices.show(serverFailureMessage(exception), tone: AppNoticeTone.error);
    } finally {
      if (mounted) setState(() => _busyProgramId = null);
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
        greeting: _greeting ??= _greet(state),
        messages: state.conversation.messages,
        suggestions: _suggestionsFor(state),
        composerController: _composer,
        onSend: _send,
        onOpenProposal: _openProposal,
        onOpenProgram: _openProgram,
        busyProgramId: _busyProgramId,
        onRetry: () => ref.read(coachThreadProvider.notifier).clearOffline(),
        onStop: () => ref.read(coachThreadProvider.notifier).stop(),
        isOffline: state.isOffline,
        live: state.live,
        notice: state.notice,
        onUnlock: state.isReadOnly
            ? () => GoRouter.of(context).go(AppRoutes.subscription)
            : null,
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
