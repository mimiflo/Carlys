import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/feedback/server_gesture.dart';
import '../../../../design_system/design_system.dart';
import '../../../mentor/presentation/widgets/mentor_speak_button.dart';
import '../../../workout_template/presentation/providers/workout_template_providers.dart';
import '../../domain/entities/coach.dart';
import '../../domain/services/coach_greeting.dart';
import '../controllers/coach_controllers.dart';
import '../providers/coach_program_actions.dart';
import '../providers/coach_saved_workouts.dart';
import '../widgets/coach_page_states.dart';
import '../widgets/coach_training_frame.dart';
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

  /// Séance enregistrée en cours d'ouverture : ses modèles se rapatrient.
  String? _busyCreatedId;

  /// Le bonjour de CETTE ouverture : écrit une fois, à sa place dans le
  /// fil, et qui y reste pendant la visite.
  CoachGreeting? _greeting;
  bool _greetingDecided = false;

  CoachGreeting? _openingGreeting(CoachThreadState state) {
    if (!_greetingDecided) {
      final opening = coachOpeningGreeting(ref, state);
      _greetingDecided = opening.decided;
      _greeting = opening.greeting;
    }
    return _greeting;
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

  /// Une séance que le coach a enregistrée vit côté serveur : on rapatrie
  /// les modèles (le seul sens de lecture des modèles), puis on l'ouvre.
  Future<void> _openCreated(CoachCreatedWorkout workout) async {
    if (_busyCreatedId != null) return;
    final router = GoRouter.of(context);
    final notices = AppNotices.of(context);
    setState(() => _busyCreatedId = workout.templateId);
    try {
      await ref.read(workoutTemplateActionsProvider).refresh();
      // Le retour ramène au coach : l'éditeur s'empile, il ne remplace pas.
      unawaited(router.push(AppRoutes.templateEditor(workout.templateId)));
    } on AppException catch (exception) {
      notices.show(serverFailureMessage(exception), tone: AppNoticeTone.error);
    } finally {
      if (mounted) setState(() => _busyCreatedId = null);
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
    keepCoachWorkoutsOnDevice(ref);

    return thread.when(
      loading: () => const CoachShell(
        child: AppLoadingIndicator(label: 'Ouverture du coach'),
      ),
      error: (error, _) => CoachShell(child: _errorState(error)),
      data: (state) => CoachScreen(
        frame: const CoachTrainingFrame(),
        // Le coach parle de la voix du Mentor : chaque réponse s'écoute.
        replyFooter: (reply) => MentorSpeakButton(
          speechKey: 'coach.${reply.id}',
          text: reply.content,
          size: 18,
          compact: true,
        ),
        greeting: _openingGreeting(state),
        messages: state.conversation.messages,
        suggestions: coachVisibleSuggestions(ref, state),
        composerController: _composer,
        onSend: _send,
        onOpenProposal: _openProposal,
        onOpenProgram: _openProgram,
        onOpenCreated: _openCreated,
        busyProgramId: _busyProgramId,
        busyCreatedId: _busyCreatedId,
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
    if (error is ForbiddenException) return const CoachPremiumState();

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
