import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// LA BARRE DE TITRE DE SECTION : ce qui donne son rythme à l'accueil.
///
/// Une icône, un libellé, puis un filet qui court jusqu'au bord droit. C'est
/// le filet qui fait le travail : il sépare sans encadrer, et permet aux
/// sections de vivre à même le fond plutôt que dans une carte. L'accueil ne
/// garde ainsi que TROIS surfaces, au lieu d'une pile de cartes égales où
/// plus rien ne ressortait.
///
/// La valeur de droite est réservée à un chiffre ou un état court. Elle n'est
/// jamais une action : un geste dans une barre de titre se confondrait avec
/// le filet.
///
/// ## Pourquoi la barre se MESURE
///
/// Le libellé et le filet ne peuvent pas s'arbitrer avec les seuls facteurs
/// de flexibilité : rendus tous deux flexibles ils se partagent l'espace
/// libre à parts égales, et « SÉRIE DE CONSTANCE » se tronquait alors qu'il
/// restait de la place à côté. Le libellé pris à sa taille naturelle, lui,
/// déborde dès que la police de repli est plus large que la nôtre.
///
/// On mesure donc le libellé, on lui donne ce qu'il demande dans la limite de
/// ce qui reste, et le filet prend le solde. C'est la seule façon d'avoir un
/// titre jamais coupé ET une barre qui ne déborde jamais.
class SectionTitleBar extends StatelessWidget {
  const SectionTitleBar({
    required this.icon,
    required this.label,
    this.iconColor = AppColors.primaryLight,
    this.trailing,
    this.trailingColor = AppColors.accent,
    this.leading,
    super.key,
  });

  final IconData icon;

  /// Libellé de la section, mis en CAPITALES à l'affichage.
  final String label;

  final Color iconColor;

  /// Chiffre ou état affiché à droite du filet. `null` : le filet va au bout.
  final String? trailing;

  final Color trailingColor;

  /// Ornement posé juste avant la valeur de droite — la flamme vivante de la
  /// série de constance, et rien d'autre à ce jour.
  final Widget? leading;

  static const double iconSize = 15;

  /// Écart de part et d'autre du filet.
  static const double _gap = AppSpacing.gapTile;

  /// Longueur minimale du filet : en deçà, il ne se lit plus comme une barre
  /// mais comme une poussière entre deux mots.
  static const double _minRule = 12;

  /// Largeur de l'ornement de gauche et de son écart.
  static const double _leadingWidth = 14 + AppSpacing.xxs + 1;

  TextStyle get _labelStyle => AppTypography.labelMono.copyWith(
    letterSpacing: 1.4,
    color: AppColors.darkTextTertiary,
  );

  TextStyle get _trailingStyle => AppTypography.labelMono.copyWith(
    fontWeight: FontWeight.w700,
    color: trailingColor,
  );

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final value = trailing;

    final labelWidth = _measure(label.toUpperCase(), _labelStyle, scaler);
    final trailingWidth = value == null
        ? 0.0
        : _gap +
              (leading == null ? 0.0 : _leadingWidth) +
              _measure(value.toUpperCase(), _trailingStyle, scaler);

    return LayoutBuilder(
      builder: (context, constraints) {
        final free =
            constraints.maxWidth -
            iconSize -
            _gap -
            _gap -
            _minRule -
            trailingWidth;

        return Row(
          children: [
            Icon(icon, size: iconSize, color: iconColor),
            const SizedBox(width: _gap),
            SizedBox(
              width: math.min(labelWidth, math.max(0, free)),
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: _labelStyle,
              ),
            ),
            const SizedBox(width: _gap),
            const Expanded(
              child: Divider(height: 1, color: AppColors.darkBorder),
            ),
            if (value != null) ...[
              const SizedBox(width: _gap),
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.xxs + 1),
              ],
              Text(
                value.toUpperCase(),
                maxLines: 1,
                softWrap: false,
                style: _trailingStyle,
              ),
            ],
          ],
        );
      },
    );
  }

  /// Largeur naturelle d'une ligne, à l'échelle de texte du système.
  static double _measure(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
