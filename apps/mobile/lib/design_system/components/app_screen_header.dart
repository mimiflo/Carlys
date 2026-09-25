import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_back_button.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showBack) ...[
          const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTypography.pageTitle.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(tagline.toUpperCase(), style: _taglineStyle),
                ],
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: AppSpacing.sm),
              action,
            ],
          ],
        ),
      ],
    );
  }

  /// La largeur, en points de TEXTE, sous laquelle le titre centré ne tient
  /// plus entre ses deux boutons : il passe alors SOUS eux, sur toute la
  /// largeur (320 points, texte agrandi), au lieu de se couper au milieu
  /// d'un mot.
  static const double _centeredTitleMinWidth = 160;

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
    final heading = Column(
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title.copyWith(
              color: AppColors.darkTextPrimary,
            ),
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
        final room = constraints.maxWidth - 2 * (side + AppSpacing.xs);
        final fits =
            room >=
            MediaQuery.textScalerOf(context).scale(_centeredTitleMinWidth);
        if (!fits) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [back, const Spacer(), trailing]),
              const SizedBox(height: AppSpacing.xxs),
              heading,
            ],
          );
        }
        return Row(
          children: [
            back,
            const SizedBox(width: AppSpacing.xs),
            Expanded(child: heading),
            const SizedBox(width: AppSpacing.xs),
            trailing,
          ],
        );
      },
    );
  }
}
