import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';
import 'quiz_choice.dart';

/// Une question à choix : on répond d'un geste, la carte révèle la bonne
/// réponse et son explication. L'explication s'affiche TOUJOURS — juste ou
/// faux, c'est elle qui enseigne.
///
/// La même question vit à DEUX endroits : la « question du jour » de
/// l'accueil, et sa leçon dans l'Academy. [answeredChoice] est ce qui les
/// relie : y répondre d'un côté remplit la carte de l'autre, au lieu de
/// reposer la question comme si de rien n'était.
class QuizCard extends StatefulWidget {
  const QuizCard({
    required this.question,
    this.title,
    this.answeredChoice,
    this.onAnswered,
    this.hint,
    this.embedded = false,
    super.key,
  });

  final QuizQuestion question;

  /// Sur-titre optionnel (« Question du jour », catégorie…).
  final String? title;

  /// Choix DÉJÀ retenu pour cette question, s'il y en a un.
  ///
  /// C'est le choix réellement fait, pas seulement « répondu » : afficher la
  /// bonne réponse sans montrer celle qui a été donnée laisserait croire à
  /// une réussite même après une erreur.
  final int? answeredChoice;

  /// Appelé UNE fois, à la première réponse : l'index choisi et s'il est
  /// juste. C'est par lui que la réponse est notée sur l'appareil puis
  /// rejoint les défis culturels de la communauté.
  final void Function(int choiceIndex, bool correct)? onAnswered;

  /// Invite affichée AVANT la réponse. Par défaut, celle de la question du
  /// jour (« une seule tentative par jour ») ; le quiz de domaine, qui se
  /// rejoue à volonté, passe la sienne.
  final String? hint;

  /// Posée DANS une leçon (maquette d'octobre 2026) : pas de carte autour,
  /// la leçon en est déjà une, et des réponses encadrées. Seule, la carte
  /// sépare ses réponses d'un filet.
  final bool embedded;

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  int? _picked;

  /// Le choix coché, pas encore validé. Une seule tentative : un appui
  /// malheureux ne doit pas la consommer, d'où « Valider ma réponse ».
  int? _pending;

  void _validate() {
    final choice = _pending;
    // Deux appuis dans la même image : la tentative ne se compte qu'une fois.
    if (choice == null || _picked != null) return;
    setState(() => _picked = choice);
    widget.onAnswered?.call(choice, choice == widget.question.answerIndex);
  }

  @override
  void initState() {
    super.initState();
    _picked = widget.answeredChoice;
  }

  @override
  void didUpdateWidget(QuizCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.question, widget.question)) {
      // Question changée : on repart de ce qu'on sait d'ELLE.
      _picked = widget.answeredChoice;
      _pending = null;
      return;
    }
    // Réponse arrivée d'ailleurs (l'autre écran, ou la lecture du stockage
    // local qui vient de finir). Le choix LOCAL reste prioritaire : il est
    // déjà affiché, et le remplacer ferait clignoter la carte.
    if (_picked == null && widget.answeredChoice != null) {
      _picked = widget.answeredChoice;
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.question;
    final picked = _picked;
    final answered = picked != null;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title case final title?) ...[
          Row(
            children: [
              const Icon(AppIcons.dailyQuestion, color: AppColors.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: AppSectionLabel(title)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          question.prompt,
          style: AppTypography.subheading.copyWith(
            height: 1.35,
            color: AppColors.darkTextPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var index = 0; index < question.choices.length; index++) ...[
          if (index > 0)
            widget.embedded
                ? const SizedBox(height: AppSpacing.xs)
                : const Divider(height: 1, color: AppColors.rowDivider),
          QuizChoice(
            letter: _letters[index],
            label: question.choices[index],
            picked: picked == index,
            pending: !answered && _pending == index,
            correct: index == question.answerIndex,
            answered: answered,
            boxed: widget.embedded,
            // Une seule tentative : la réponse part au stockage local et
            // nourrit les défis de la communauté. La reprendre voudrait dire
            // la retirer de partout, ce qui n'aurait plus rien d'un quiz.
            onTap: answered ? null : () => setState(() => _pending = index),
          ),
        ],
        if (!answered) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Valider ma réponse',
            isExpanded: true,
            onPressed: _pending == null ? null : _validate,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        _Hint(
          answered: answered,
          correct: answered && picked == question.answerIndex,
          invite: widget.hint,
        ),
        if (answered) ...[
          const SizedBox(height: AppSpacing.sm),
          // L'explication s'affiche TOUJOURS, juste ou faux : c'est elle qui
          // enseigne, pas le verdict.
          Text(
            question.explanation,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ],
    );

    return widget.embedded ? content : AppCard(child: content);
  }

  /// Trois choix au plus dans le pack : la table suffit.
  static const List<String> _letters = ['A', 'B', 'C', 'D'];
}

/// La ligne d'invite, sous les réponses : elle dit quoi faire, puis ce qui
/// vient d'être fait. Jamais un reproche.
class _Hint extends StatelessWidget {
  const _Hint({required this.answered, required this.correct, this.invite});

  final bool answered;
  final bool correct;

  /// Invite de remplacement avant la réponse, quand le contexte n'est pas
  /// la question du jour.
  final String? invite;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch ((answered, correct)) {
      (false, _) => (
        invite ?? 'Choisis, puis valide : une seule tentative par jour.',
        AppColors.darkTextTertiary,
      ),
      (true, true) => ('Bonne réponse.', AppColors.success),
      (true, false) => (
        'Raté, mais l’explication vaut le détour.',
        AppColors.darkTextTertiary,
      ),
    };

    return Row(
      children: [
        Icon(
          answered ? AppIcons.checkCircle : AppIcons.touch,
          size: 14,
          color: answered ? color : AppColors.textMuted,
        ),
        const SizedBox(width: AppSpacing.xs - 1),
        Expanded(
          child: Text(text, style: AppTypography.label.copyWith(color: color)),
        ),
      ],
    );
  }
}
