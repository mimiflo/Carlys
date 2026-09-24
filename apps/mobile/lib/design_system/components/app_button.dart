import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,

  /// Plein ACCENT (orange). Ne subsiste que pour un besoin très ciblé ;
  /// l'action principale ordinaire est [primary], le violet des écrans
  /// d'entrée. Ne pas l'employer pour un bouton d'action courant.
  accent,
  destructive,
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
      // pression, accessibilité) sans qu'on la réécrive.
      AppButtonVariant.primary => _GradientAction(
        enabled: _enabled,
        onPressed: onPressedOrNull,
        sizeStyle: _sizeStyle(),
        child: child,
      ),
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
      AppButtonVariant.destructive => FilledButton(
        onPressed: onPressedOrNull,
        style: _sizeStyle().merge(
          FilledButton.styleFrom(
            backgroundColor: AppColors.dangerStrong,
            foregroundColor: AppColors.neutral0,
          ),
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
      // Blanc, jamais `onPrimary` : le fond primaire est désormais un dégradé
      // violet peint hors du colorScheme, où `onPrimary` n'a plus de rapport
      // avec le fond réel.
      final onFill = variant == AppButtonVariant.primary
          ? AppColors.neutral0
          : Theme.of(context).colorScheme.onPrimary;
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
        // Un libellé long dans un bouton étroit se tronque plutôt que de
        // déborder : un débordement est une erreur de rendu, pas un style.
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.clip)),
      ],
    );
  }
}

/// L'action principale, rendue avec le dégradé violet des écrans d'entrée.
///
/// Le dégradé ([AppColors.cta]) se peint dans un [DecoratedBox] ; le
/// [FilledButton] posé dessus est rendu transparent, donc il n'apporte plus
/// que sa mécanique — dimensions du thème, effet de pression, sémantique,
/// zone tactile. Le rayon du fond suit celui du thème des boutons pour que
/// les coins du dégradé épousent ceux du bouton.
///
/// Désactivé, l'ensemble s'éteint à moitié (texte compris), comme le bouton
/// de marque : un fond vif sous un libellé grisé se lit comme un bug
/// d'affichage, pas comme un état.
class _GradientAction extends StatelessWidget {
  const _GradientAction({
    required this.enabled,
    required this.onPressed,
    required this.sizeStyle,
    required this.child,
  });

  final bool enabled;
  final VoidCallback? onPressed;
  final ButtonStyle sizeStyle;
  final Widget child;

  static const double _disabledOpacity = 0.45;

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.cta,
        borderRadius: AppRadius.buttonAll,
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: sizeStyle.merge(
          FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.neutral0,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: AppColors.neutral0,
            shadowColor: Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
    // L'opacité seule tamise ; les couleurs « disabled » restent pleines pour
    // que ce soit le dégradé ET le texte qui pâlissent d'un même mouvement.
    return Opacity(opacity: enabled ? 1 : _disabledOpacity, child: surface);
  }
}
