import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/entities/academy.dart';

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

  @override
  State<QuizCard> createState() => _QuizCardState();
}

class _QuizCardState extends State<QuizCard> {
  int? _picked;

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
    final answered = _picked != null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title != null) ...[
            AppSectionLabel(widget.title!),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            question.prompt,
            style: AppTypography.subheading
                .copyWith(color: AppColors.darkTextPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < question.choices.length; index++)
            _Choice(
              label: question.choices[index],
              state: !answered
                  ? _ChoiceState.idle
                  : index == question.answerIndex
                      ? _ChoiceState.correct
                      : index == _picked
                          ? _ChoiceState.wrong
                          : _ChoiceState.dimmed,
              onTap: answered
                  ? null
                  : () {
                      setState(() => _picked = index);
                      widget.onAnswered
                          ?.call(index, index == question.answerIndex);
                    },
            ),
          if (answered) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              question.explanation,
              style: AppTypography.body
                  .copyWith(color: AppColors.darkTextSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

enum _ChoiceState { idle, correct, wrong, dimmed }

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.state, this.onTap});

  final String label;
  final _ChoiceState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color border, Color text) = switch (state) {
      _ChoiceState.idle => (AppColors.darkBorder, AppColors.darkTextPrimary),
      _ChoiceState.correct => (AppColors.success, AppColors.success),
      _ChoiceState.wrong => (AppColors.danger, AppColors.danger),
      _ChoiceState.dimmed => (AppColors.darkBorder, AppColors.darkTextTertiary),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.fromBorderSide(BorderSide(color: border)),
          ),
          child: Text(label, style: AppTypography.body.copyWith(color: text)),
        ),
      ),
    );
  }
}
