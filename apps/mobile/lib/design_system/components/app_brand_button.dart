import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Bouton pleine largeur au **dégradé de marque**.
///
/// Réservé aux surfaces de marque, où le lime de l'application n'a pas encore
/// de sens : sur la page de bienvenue, c'est l'identité qu'on montre, pas
/// l'interface. Ailleurs, l'action principale reste [AppButton] en accent —
/// deux boutons « principaux » de couleurs différentes dans un même écran
/// annuleraient la hiérarchie.
class AppBrandButton extends StatefulWidget {
  const AppBrandButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  /// Géométrie : hauteur confortable au pouce, libellé en majuscules espacées.
  static const double _height = 58;
  static const double _fontSize = 15;
  static const double _tracking = 1.4;

  /// Réaction au toucher : un tassement à peine perceptible et un éclat.
  static const double _pressedScale = 0.985;
  static const double _pressedBrightness = 1.08;
  static const Duration _pressDuration = Duration(milliseconds: 160);

  @override
  State<AppBrandButton> createState() => _AppBrandButtonState();
}

class _AppBrandButtonState extends State<AppBrandButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            scale: _pressed ? AppBrandButton._pressedScale : 1,
            duration: AppBrandButton._pressDuration,
            child: _Surface(
              // L'éclat au toucher est rendu par un voile blanc très léger :
              // un filtre de luminosité coûterait une couche de composition
              // pour un résultat identique à l'œil.
              highlight: _pressed ? AppBrandButton._pressedBrightness - 1 : 0,
              label: widget.label,
            ),
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.highlight, required this.label});

  /// Part de blanc ajoutée par-dessus le dégradé, à l'appui.
  final double highlight;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppBrandButton._pressDuration,
      height: AppBrandButton._height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: AppColors.signature,
        borderRadius: AppRadius.fullAll,
      ),
      foregroundDecoration: BoxDecoration(
        color: AppColors.neutral0.withValues(alpha: highlight),
        borderRadius: AppRadius.fullAll,
      ),
      child: Text(
        label.toUpperCase(),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.subheading.copyWith(
          fontSize: AppBrandButton._fontSize,
          color: AppColors.neutral0,
          fontWeight: FontWeight.w700,
          letterSpacing: AppBrandButton._tracking,
        ),
      ),
    );
  }
}
