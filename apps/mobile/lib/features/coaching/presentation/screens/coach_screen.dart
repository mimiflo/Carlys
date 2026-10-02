import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/coach_thread_state.dart';
import '../../domain/services/coach_greeting.dart';
import '../widgets/coach_composer.dart';
import '../widgets/coach_greeting_bubble.dart';
import '../widgets/coach_header.dart';
import '../widgets/coach_notices.dart';
import '../widgets/coach_read_only_panel.dart';
import '../widgets/coach_suggestions.dart';
import '../widgets/coach_thread_view.dart';

/// Écran du coach : une conversation qui se termine par une **action**.
///
/// Volontairement PRÉSENTATIONNEL — il reçoit ses données, il ne les va pas
/// chercher. Le contrôleur qui l'alimentera arrive avec la couche data ; d'ici
/// là, rien dans cet écran ne prétend être connecté à quoi que ce soit.
class CoachScreen extends StatelessWidget {
  const CoachScreen({
    required this.messages,
    required this.suggestions,
    required this.composerController,
    required this.onSend,
    required this.onOpenProposal,
    required this.onOpenProgram,
    required this.onRetry,
    this.onStop,
    this.onOpenCreated,
    this.busyProgramId,
    this.busyCreatedId,
    this.isOffline = false,
    this.live,
    this.notice,
    this.onUnlock,
    this.greeting,
    super.key,
  });

  final List<CoachMessage> messages;
  final List<String> suggestions;
  final TextEditingController composerController;
  final ValueChanged<String> onSend;
  final ValueChanged<CoachSessionProposal> onOpenProposal;

  /// Créer (ou revoir) le programme qu'a proposé le coach.
  final ValueChanged<CoachProgramProposal> onOpenProgram;

  /// Programme proposé en cours de création, s'il y en a un.
  final String? busyProgramId;

  /// Ouvrir une séance que le coach a enregistrée, et celle qui s'ouvre.
  final ValueChanged<CoachCreatedWorkout>? onOpenCreated;
  final String? busyCreatedId;

  /// Sortie de l'état hors ligne : l'encart qui remplace le composeur
  /// l'offre, faute de quoi l'écran resterait muet le réseau revenu.
  final VoidCallback onRetry;

  /// Arrête la réponse en cours (bouton « Arrêter » du composeur).
  final VoidCallback? onStop;
  final bool isOffline;

  /// Le tour en cours d'écriture, s'il y en a un.
  final CoachLiveTurn? live;

  /// Refus explicite du serveur (plafond du jour, coach coupé). Jamais un
  /// message d'ambiance : s'il est là, c'est qu'un envoi a été refusé.
  final String? notice;

  /// Présent quand le fil se RELIT sans plus s'écrire (coach réservé aux
  /// abonnés) : le composeur cède la place à l'invitation qui y mène.
  final VoidCallback? onUnlock;

  /// Le bonjour du coach à l'ouverture : il remplace l'encart d'un fil vide.
  final CoachGreeting? greeting;

  /// Part de la colonne qu'une bulle peut occuper. Au-delà, on ne lit plus une
  /// conversation mais un document : il faut voir que le bord est libre en
  /// face pour comprendre qui parle.
  static const double _bubbleWidthFactor = 0.78;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La barre de saisie reste EN BAS, et passe au-dessus du clavier quand
      // il s'ouvre. Rien à calculer ici pour cela, et surtout aucune réserve
      // à ajouter sous le composeur :
      //
      //  - la coquille relève déjà le corps au-dessus du clavier, et RETIRE
      //    l'encart de son `MediaQuery` (`removeBottomInset`), si bien que ce
      //    `Scaffold`-ci ne le soustrait pas une seconde fois ; hors coquille,
      //    c'est lui qui s'en charge, et l'écran reste juste ;
      //  - le `SafeArea` ci-dessous porte la réserve de la barre d'onglets :
      //    elle vaut sa hauteur clavier fermé, et zéro clavier ouvert,
      //    puisque le clavier la recouvre. Ajouter cette hauteur à la main
      //    la compterait deux fois, et la barre de saisie flotterait à
      //    quatre-vingts pixels au-dessus du bas.
      body: SafeArea(
        child: Column(
          children: [
            const CoachHeader(),
            Expanded(
              child: messages.isEmpty && live == null
                  ? _CoachIntro(
                      greeting: greeting,
                      bubbleWidthFactor: _bubbleWidthFactor,
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) => CoachThreadView(
                        messages: messages,
                        live: live,
                        maxBubbleWidth:
                            constraints.maxWidth * _bubbleWidthFactor,
                        onOpenProposal: onOpenProposal,
                        onOpenProgram: onOpenProgram,
                        onOpenCreated: onOpenCreated,
                        busyProgramId: busyProgramId,
                        busyCreatedId: busyCreatedId,
                        greeting: greeting,
                      ),
                    ),
            ),
            if (notice case final text?) CoachNotice(text: text),
            if (onUnlock case final unlock?)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.md,
                ),
                child: CoachReadOnlyPanel(onUnlock: unlock),
              )
            else ...[
              if (suggestions.isNotEmpty && !isOffline) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.gutter,
                    0,
                    AppSpacing.gutter,
                    AppSpacing.sm,
                  ),
                  child: CoachSuggestions(
                    suggestions: suggestions,
                    onSelected: onSend,
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  0,
                  AppSpacing.gutter,
                  AppSpacing.md,
                ),
                child: CoachComposer(
                  controller: composerController,
                  onSend: onSend,
                  onRetry: onRetry,
                  onStop: onStop,
                  isOffline: isOffline,
                  isSending: live != null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un fil vide : qui est le coach, au centre ; puis, au premier rang du fil
/// à venir, son bonjour ([greeting]) quand la page en a écrit un.
class _CoachIntro extends StatelessWidget {
  const _CoachIntro({required this.greeting, required this.bubbleWidthFactor});

  final CoachGreeting? greeting;
  final double bubbleWidthFactor;

  @override
  Widget build(BuildContext context) {
    final greeting = this.greeting;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          // Taille naturelle, jamais rognée (clavier ouvert, texte
          // agrandi) : l'encart se centre quand il y a de la place, et le
          // tout défile quand il n'y en a plus.
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox.shrink(),
              AppEmptyState(
                icon: AppIcons.coach,
                title: 'Ton coach est là',
                message: greeting == null
                    ? 'Pose-lui une question sur ta progression, ou '
                          'demande-lui d’adapter ta séance à ton temps '
                          'du jour.'
                    : 'Il lit tes séances, tes records et tes mesures '
                          'avant de te répondre.',
              ),
              if (greeting != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: CoachGreetingBubble(
                    text: greeting.text,
                    since: greeting.at,
                    maxWidth: constraints.maxWidth * bubbleWidthFactor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
