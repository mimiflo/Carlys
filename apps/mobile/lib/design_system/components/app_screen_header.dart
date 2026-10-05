import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_back_button.dart';
import 'app_whole_words_text.dart';

/// L'en-tête des écrans de la refonte : un titre, une ligne mono en
/// capitales, et des actions rondes à droite.
///
/// Né dans le profil (« Mon profil / TON PARCOURS, TA PROGRESSION. »), repris
/// par la Communauté (« Communauté / ENSEMBLE, PLUS LOIN ») : deux copies
/// d'un en-tête finissent toujours par différer d'un point, et c'est le
/// premier écart qu'un œil remarque en passant d'un écran à l'autre.
///
/// Le retour vit AU-DESSUS du titre plutôt qu'à sa gauche : la ligne mono est
/// longue et ne tiendrait pas entre deux boutons. Un écran d'onglet n'en a
/// pas ([showBack] faux) ; sur un écran poussé, il disparaît de lui-même
/// quand il n'y a rien à dépiler.
///
/// [AppScreenHeader.centered] est la variante d'un écran de SAISIE (« Modifier
/// ce repas / AJUSTE LES DÉTAILS ») : le retour à GAUCHE, le titre centré,
/// l'action à droite, sur une seule rangée. Elle tient parce que sa ligne mono
/// est courte ; le titre y prend [AppTypography.title], le corps d'affiche ne
/// logeant pas « Modifier ce repas » entre deux boutons sur 393 points. Les
/// deux côtés gardent la même largeur, bouton ou pas : sans quoi le titre ne
/// serait centré que sur l'écran qui a les deux.
class AppScreenHeader extends StatelessWidget {
  const AppScreenHeader({
    required this.title,
    required this.tagline,
    this.actions = const [],
    this.showBack = true,
    super.key,
  }) : centered = false;

  /// Retour à gauche, titre centré, actions à droite (voir la classe).
  const AppScreenHeader.centered({
    required this.title,
    required this.tagline,
    this.actions = const [],
    this.showBack = true,
    super.key,
  }) : centered = true;

  final String title;

  /// Écrite en capitales à l'affichage.
  final String tagline;

  /// Des `AppRoundIconButton`, en général.
  final List<Widget> actions;
  final bool showBack;

  /// Vrai pour [AppScreenHeader.centered].
  final bool centered;

  TextStyle get _taglineStyle => AppTypography.resized(
    AppTypography.labelMono,
    11,
  ).copyWith(color: AppColors.darkTextSecondary);

  @override
  Widget build(BuildContext context) {
    if (centered) {
      return _buildCentered();
    }
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: AppWholeWordsText(
            title,
            style: AppTypography.pageTitle.copyWith(
              color: AppColors.darkTextPrimary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(tagline.toUpperCase(), style: _taglineStyle),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack) ...[
          const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (actions.isEmpty)
          heading
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // La même parade que la variante centrée : quand les boutons
              // ne laissent plus au titre sa largeur minimale, ils passent
              // AU-DESSUS de lui, qui prend alors toute la largeur. Sans
              // elle, « Communauté » se coupait en son milieu dès ×1,3.
              final room =
                  constraints.maxWidth -
                  actions.length * (AppSpacing.touchTarget + AppSpacing.sm);
              final fits =
                  room >=
                  MediaQuery.textScalerOf(context).scale(_titleMinWidth);
              final buttons = [
                for (final (index, action) in actions.indexed) ...[
                  if (index > 0 || fits) const SizedBox(width: AppSpacing.sm),
                  action,
                ],
              ];
              if (!fits) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: buttons,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    heading,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  ...buttons,
                ],
              );
            },
          ),
      ],
    );
  }

  /// La largeur, en points de TEXTE, sous laquelle le titre ne tient plus à
  /// côté de ses boutons : il passe alors SOUS eux, sur toute la largeur
  /// (320 points, texte agrandi), au lieu de se couper au milieu d'un mot.
  /// Les deux variantes, centrée et alignée, obéissent à la même règle.
  static const double _titleMinWidth = 160;

  /// Le corps du titre centré : [AppTypography.title], ou
  /// [AppTypography.heading] quand le titre ne tiendrait pas sur UNE ligne
  /// à côté de ses boutons (« Calendrier du programme » sur 393 points). Un
  /// titre d'en-tête se lit d'un bloc ; il ne passe à la ligne que si même
  /// le corps réduit ne tient pas — texte agrandi compris, la mesure se
  /// faisant à l'échelle du texte système.
  TextStyle _centeredTitleStyle(
    double width,
    TextScaler scaler,
    TextDirection direction,
  ) {
    final large = AppTypography.title.copyWith(
      color: AppColors.darkTextPrimary,
    );
    final painter = TextPainter(
      text: TextSpan(text: title, style: large),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout(maxWidth: width);
    final fitsOnOneLine = !painter.didExceedMaxLines;
    painter.dispose();
    return fitsOnOneLine
        ? large
        : AppTypography.heading.copyWith(color: AppColors.darkTextPrimary);
  }

  Widget _buildCentered() {
    // Chaque côté a la largeur de ses boutons, et l'autre côté la même : un
    // seul bouton à droite (ou le retour seul) décentrerait le titre.
    final sides = actions.length > 1 ? actions.length : 1;
    final side = sides * AppSpacing.touchTarget;
    final back = SizedBox(
      width: side,
      child: showBack
          ? const Align(alignment: Alignment.centerLeft, child: AppBackButton())
          : null,
    );
    final trailing = SizedBox(
      width: side,
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
    );
    Widget heading(double width, TextScaler scaler, TextDirection direction) =>
        Column(
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: _centeredTitleStyle(width, scaler, direction),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              tagline.toUpperCase(),
              textAlign: TextAlign.center,
              style: _taglineStyle,
            ),
          ],
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final direction = Directionality.of(context);
        final room = constraints.maxWidth - 2 * (side + AppSpacing.xs);
        final fits = room >= scaler.scale(_titleMinWidth);
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [back, const Spacer(), trailing]),
              const SizedBox(height: AppSpacing.xxs),
              heading(constraints.maxWidth, scaler, direction),
            ],
          );
        }
        return Row(
          children: [
            back,
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: heading(room, scaler, direction)),
            const SizedBox(width: AppSpacing.xs),
            trailing,
          ],
        );
      },
    );
  }
}
