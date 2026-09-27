import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_whole_words_text.dart';

/// Ton du texte d'accompagnement d'un en-tête de section.
enum AppSectionTrailingTone { tertiary, primary, accent }

/// En-tête de section de la refonte : titre Inter 15/600 à gauche, valeur ou
/// action en mono 11 à droite (« Records personnels » / « TOUT VOIR »).
///
/// Alignement sur la ligne de base : le titre et la valeur partagent leur
/// assise, comme dans la maquette.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.trailing,
    this.trailingIcon,
    this.trailingTone = AppSectionTrailingTone.tertiary,
    this.onTrailingTap,
    super.key,
  });

  final String title;

  /// Texte de droite, rendu en mono MAJUSCULES.
  final String? trailing;

  /// Icône optionnelle devant le texte de droite (ex. « + AJOUTER »).
  final IconData? trailingIcon;
  final AppSectionTrailingTone trailingTone;
  final VoidCallback? onTrailingTap;

  /// Côte à côte, la part de la largeur que l'action peut prendre ; plus
  /// longue (texte agrandi, écran étroit), elle passe SOUS le titre.
  static const double _trailingShare = 0.5;

  /// Retrait horizontal de l'action, de part et d'autre.
  static const double _trailingInset = 2;

  static final TextStyle _titleStyle = AppTypography.resized(
    AppTypography.subheading,
    15,
  ).copyWith(color: AppColors.darkTextPrimary);

  static TextStyle _trailingStyle(Color color) =>
      AppTypography.resized(AppTypography.labelMono, 11).copyWith(color: color);

  @override
  Widget build(BuildContext context) {
    final trailingColor = switch (trailingTone) {
      AppSectionTrailingTone.tertiary => AppColors.darkTextTertiary,
      AppSectionTrailingTone.primary => AppColors.primaryLight,
      AppSectionTrailingTone.accent => AppColors.accent,
    };
    // Annoncé comme un TITRE : le lecteur d'écran y saute de section en
    // section.
    final heading = Semantics(
      container: true,
      header: true,
      child: AppWholeWordsText(title, style: _titleStyle),
    );
    final label = trailing?.toUpperCase();
    if (label == null) {
      return Row(children: [Expanded(child: heading)]);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            _trailingWidth(context, label) >
            constraints.maxWidth * _trailingShare;
        final action = _trailing(label, trailingColor);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, action],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: heading),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * _trailingShare,
              ),
              child: action,
            ),
          ],
        );
      },
    );
  }

  /// La largeur de l'action sur une ligne, icône et retraits compris.
  double _trailingWidth(BuildContext context, String label) {
    final width = AppTypography.lineWidth(
      label,
      _trailingStyle(AppColors.neutral0),
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
    );
    final icon = trailingIcon == null ? 0 : _iconSize + _iconGap;
    return width + icon + 2 * _trailingInset;
  }

  static const double _iconSize = 15;
  static const double _iconGap = 4;

  Widget _trailing(String label, Color color) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailingIcon != null) ...[
          Icon(trailingIcon, size: _iconSize, color: color),
          const SizedBox(width: _iconGap),
        ],
        Flexible(child: Text(label, style: _trailingStyle(color))),
      ],
    );
    final onTap = onTrailingTap;
    if (onTap == null) {
      return content;
    }
    // Une FRONTIÈRE et une cible de 48 points. Sans frontière, l'action
    // remontait jusqu'à l'élément de liste, qui absorbait la section
    // entière : activer « Récompenses » relisait douze lignes et déclenchait
    // « Voir les 4 ». Et elle faisait 23 points de haut.
    return Semantics(
      container: true,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _trailingInset),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              heightFactor: 1,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
