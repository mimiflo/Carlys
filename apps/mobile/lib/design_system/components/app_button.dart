import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';
import 'app_action_label.dart';
import 'app_gradient_action.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,

  /// Plein ACCENT (orange). Ne subsiste que pour un besoin très ciblé ;
  /// l'action principale ordinaire est [primary], le violet des écrans
  /// d'entrée. Ne pas l'employer pour un bouton d'action courant.
  accent,
  destructive,

  /// Le geste destructif SECONDAIRE d'un écran (« Supprimer ce repas »,
  /// sous l'action principale) : contour et libellé rouges.
  destructiveOutline,
}

enum AppButtonSize { small, medium, large }

/// Bouton standard Carlys.
///
/// Gère le style par variante, l'état de chargement (désactive le bouton et
/// empêche les doubles soumissions) et l'accessibilité.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isExpanded = false,
    this.semanticLabel,
    super.key,
  });

  final String label;

  /// `null` désactive le bouton.
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;

  /// Occupe toute la largeur disponible.
  final bool isExpanded;
  final String? semanticLabel;

  bool get _enabled => onPressed != null && !isLoading;

  /// Voile d'état SOMBRE des boutons pleins sous un libellé blanc (voir
  /// [AppGradientAction.stateVeil]).
  static const Color stateVeil = AppGradientAction.stateVeil;

  /// Ce voile état par état, pour l'`overlayColor` d'un `InkWell` posé sur
  /// un dégradé violet sous une encre blanche (voir
  /// [AppGradientAction.stateOverlay]).
  static final WidgetStateProperty<Color?> stateOverlay =
      AppGradientAction.stateOverlay;

  /// Voile d'état du contour rouge : le rouge à 5 %. Celui de Material (8 à
  /// 10 %) fait tomber le libellé à 4,02:1 sur une carte à l'appui ; à 5 %,
  /// 4,53 (`contrast_pairs_test.dart` mesure chaque état).
  static final WidgetStateProperty<Color?> _dangerOverlay =
      WidgetStateProperty.resolveWith(
        (states) =>
            states.isEmpty ? null : AppColors.danger.withValues(alpha: 0.05),
      );

  @override
  Widget build(BuildContext context) {
    final button = _buildVariant(context);
    final sized = isExpanded
        ? SizedBox(width: double.infinity, child: button)
        : button;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel ?? label,
      child: sized,
    );
  }

  Widget _buildVariant(BuildContext context) {
    final onPressedOrNull = _enabled ? onPressed : null;
    final child = _buildChild(context);

    return switch (variant) {
      // Action principale : le MÊME dégradé violet que les écrans d'entrée
      // (connexion, inscription). Auparavant un violet PLAT — proche, mais
      // pas identique au bouton du login. Le dégradé se peint derrière un
      // FilledButton rendu transparent, qui garde toute sa mécanique (tailles,
      // pression, accessibilité) sans qu'on la réécrive. Désactivée, l'action
      // s'éteint à moitié, texte compris.
      AppButtonVariant.primary => AppGradientAction(
        onPressed: onPressedOrNull,
        style: _sizeStyle(),
        child: child,
      ),
      // Sans fond à elles, le contour et le fantôme gardent l'encre et le
      // voile que Material dérive de `colorScheme.primary` (violet clair) :
      // `contrast_pairs_test.dart` mesure chaque état.
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: onPressedOrNull,
        style: _sizeStyle(),
        child: child,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: onPressedOrNull,
        style: _sizeStyle(),
        child: child,
      ),
      AppButtonVariant.accent => FilledButton(
        onPressed: onPressedOrNull,
        style: _sizeStyle().merge(
          FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
          ),
        ),
        child: child,
      ),
      // Un rouge PLUS PROFOND que `colorScheme.error` (`danger`) : blanc sur
      // `danger` ne tient que 3,76:1, sous l'AA d'un libellé de 15 points.
      // Le voile d'état est SOMBRE (voir [stateVeil]).
      AppButtonVariant.destructive => FilledButton(
        onPressed: onPressedOrNull,
        style: _sizeStyle().merge(
          FilledButton.styleFrom(
            backgroundColor: AppColors.dangerStrong,
            foregroundColor: AppColors.neutral0,
            overlayColor: stateVeil,
          ),
        ),
        child: child,
      ),
      AppButtonVariant.destructiveOutline => OutlinedButton(
        onPressed: onPressedOrNull,
        style: _sizeStyle().merge(
          OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ).copyWith(overlayColor: _dangerOverlay),
        ),
        child: child,
      ),
    };
  }

  ButtonStyle _sizeStyle() {
    return switch (size) {
      AppButtonSize.small => FilledButton.styleFrom(
        minimumSize: const Size(48, 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      AppButtonSize.medium => FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
      ),
      AppButtonSize.large => FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      ),
    };
  }

  Widget _buildChild(BuildContext context) {
    if (isLoading) {
      // Jamais `onPrimary`, qui suppose un fond `primary`. Le primaire garde
      // son dégradé (tamisé avec lui) : blanc. Les autres variantes, en
      // chargement donc désactivées, n'ont plus de fond à elles — rien pour
      // le contour et le texte, un voile gris pour les pleines : l'indicateur
      // se pose sur la carte, et prend l'encre violette du thème. `onPrimary`
      // y valait 1,05:1.
      final onFill = variant == AppButtonVariant.primary
          ? AppColors.neutral0
          : Theme.of(context).colorScheme.primary;
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: onFill,
          semanticsLabel: 'Chargement',
        ),
      );
    }

    if (icon == null) {
      return Text(label);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.xs),
        // Deux lignes en texte agrandi, jamais coupé net (voir le libellé).
        Flexible(child: AppActionLabel(label)),
      ],
    );
  }
}
