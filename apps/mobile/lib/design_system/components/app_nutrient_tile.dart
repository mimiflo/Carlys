import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsValidationResult;

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Une VALEUR NUTRITIONNELLE en tuile : l'icône de sa couleur en haut, le
/// grand nombre, l'unité, puis son nom écrit dans sa couleur (« 390 / kcal /
/// Calories »). Quatre côte à côte disent un repas d'un coup d'œil.
///
/// Deux façons de la poser :
///  - LUE : [value] est le nombre à montrer, `null` quand on ne le sait pas.
///    Une valeur inconnue s'écrit « — », jamais « 0 » : zéro protéine est
///    une information, l'absence de mesure en est une autre ;
///  - SAISIE ([AppNutrientTile.editable]) : un champ numérique prend la place
///    du nombre, dans un puits bordé de violet qui dit qu'on peut écrire.
///    Vide, il montre « — » en indice : la case vide veut dire « on ne sait
///    pas ».
///
/// La couleur ([tint]) est celle de la valeur (`AppColors.nutrition…`) : elle
/// tient AA comme texte sur le fond de la tuile, et le nom s'écrit dedans.
class AppNutrientTile extends StatelessWidget {
  const AppNutrientTile({
    required this.icon,
    required this.tint,
    required this.label,
    required this.unit,
    required this.value,
    super.key,
  }) : controller = null,
       onChanged = null,
       errorText = null;

  const AppNutrientTile.editable({
    required this.icon,
    required this.tint,
    required this.label,
    required this.unit,
    required TextEditingController this.controller,
    this.onChanged,
    this.errorText,
    super.key,
  }) : value = null;

  final IconData icon;
  final Color tint;

  /// Le nom de la valeur : « Protéines ».
  final String label;

  /// L'unité, sous le nombre : « g », « kcal ».
  final String unit;

  /// Le nombre déjà mis en forme (« 1 240 »), `null` s'il est inconnu.
  final String? value;

  /// Non nul : la tuile se SAISIT.
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  /// La faute de la saisie (« Calories : entre 1 et 10 000. »), `null` si
  /// elle convient. Le puits passe au rouge, et le lecteur d'écran l'annonce
  /// AVEC la case — invalide, et pourquoi : la couleur seule ne dit rien à
  /// qui ne la voit pas. La phrase VISIBLE, elle, se pose sous la grille, où
  /// elle a la place (à l'écran de l'exclure de la sémantique, pour ne pas
  /// la faire lire deux fois).
  final String? errorText;

  /// Ce qu'écrit une valeur inconnue.
  static const String unknown = '—';

  static const double _iconSize = 20;

  static final TextStyle _valueStyle = AppTypography.metricM.copyWith(
    color: AppColors.darkTextPrimary,
  );

  @override
  Widget build(BuildContext context) {
    final field = controller;
    final shown = value ?? unknown;
    final corps = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: _iconSize, color: tint),
        const SizedBox(height: AppSpacing.xs),
        if (field == null)
          Text(
            shown,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: _valueStyle,
          )
        else
          _Well(
            controller: field,
            onChanged: onChanged,
            errorText: errorText,
            label: '$label, en $unit',
          ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          unit,
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            color: tint,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final tile = DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.darkSurfaceAlt,
        borderRadius: AppRadius.lgAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Center(child: corps),
      ),
    );

    if (field != null) {
      return tile;
    }
    // Lue, la tuile se dit en une phrase : « Protéines : 40 g », ou
    // « inconnu » plutôt qu'un tiret que le lecteur d'écran épellerait.
    return Semantics(
      container: true,
      label: '$label : ${value == null ? 'inconnu' : '$value $unit'}',
      excludeSemantics: true,
      child: tile,
    );
  }
}

/// Le puits de saisie d'une tuile : un champ numérique centré, au corps des
/// chiffres de la tuile, haut d'une cible tactile.
class _Well extends StatelessWidget {
  const _Well({
    required this.controller,
    required this.onChanged,
    required this.errorText,
    required this.label,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final String label;

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final invalid = errorText != null;
    final edge = invalid ? AppColors.danger : AppColors.primaryLightBorder;
    return Semantics(
      label: label,
      hint: errorText,
      validationResult: invalid
          ? SemanticsValidationResult.invalid
          : SemanticsValidationResult.none,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: AppNutrientTile._valueStyle,
        decoration: InputDecoration(
          hintText: AppNutrientTile.unknown,
          hintStyle: AppNutrientTile._valueStyle.copyWith(
            color: AppColors.darkTextTertiary,
          ),
          filled: true,
          fillColor: AppColors.darkSurface,
          isDense: true,
          constraints: const BoxConstraints(minHeight: AppSpacing.touchTarget),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.sm,
          ),
          enabledBorder: _border(edge),
          focusedBorder: _border(
            invalid ? AppColors.danger : AppColors.primaryLight,
            width: 2,
          ),
        ),
      ),
    );
  }
}
