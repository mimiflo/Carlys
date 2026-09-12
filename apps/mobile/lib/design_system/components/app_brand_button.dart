import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Bouton pleine largeur au **dégradé de marque**.
///
/// Réservé aux surfaces de marque, où l'orange de l'application n'a pas encore
/// de sens : sur la page de bienvenue comme sur les écrans d'entrée (connexion,
/// inscription), c'est l'identité qu'on montre, pas l'interface. Ailleurs,
/// l'action principale reste [AppButton] en accent — deux boutons
/// « principaux » de couleurs différentes dans un même écran annuleraient la
/// hiérarchie.
class AppBrandButton extends StatefulWidget {
  const AppBrandButton({
    required this.label,
    required this.onPressed,
    this.uppercase = true,
    this.trailingIcon,
    this.isLoading = false,
    super.key,
  });

  final String label;

  /// `null` désactive le bouton. Le dégradé s'éteint alors À MOITIÉ, texte
  /// COMPRIS : un fond vif sous un libellé grisé se lit comme un bug
  /// d'affichage, pas comme un état — c'est l'ambiguïté constatée sur la
  /// première capture de l'écran d'inscription.
  final VoidCallback? onPressed;

  /// Capitales espacées (la page de marque) ou casse du libellé telle quelle
  /// (les écrans d'entrée, dont la maquette écrit « Se connecter »).
  final bool uppercase;

  /// Icône posée après le libellé — la flèche des écrans d'entrée.
  final IconData? trailingIcon;

  /// Remplace le libellé par un indicateur et neutralise le toucher : la
  /// soumission en cours ne se double pas.
  final bool isLoading;

  /// Géométrie : hauteur confortable au pouce, libellé en majuscules espacées.
  static const double _height = 58;
  static const double _fontSize = 15;
  static const double _tracking = 1.4;
  static const double _disabledOpacity = 0.45;

  /// Réaction au toucher : un tassement à peine perceptible et un éclat.
  static const double _pressedScale = 0.985;
  static const double _pressedBrightness = 1.08;
  static const Duration _pressDuration = Duration(milliseconds: 160);

  bool get _enabled => onPressed != null && !isLoading;

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
    final enabled = widget._enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      // L'action vit ICI. Sans elle, le nœud s'annonce comme un bouton mais
      // ne publie rien, et l'activer depuis un lecteur d'écran ne fait rien :
      // le geste ci-dessous ne répond qu'au toucher direct, la couche
      // d'accessibilité ne l'atteint pas.
      onTap: enabled ? widget.onPressed : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed ? AppBrandButton._pressedScale : 1,
            duration: AppBrandButton._pressDuration,
            child: AnimatedOpacity(
              opacity: enabled ? 1 : AppBrandButton._disabledOpacity,
              duration: AppBrandButton._pressDuration,
              child: _Surface(
                // L'éclat au toucher est rendu par un voile blanc très léger :
                // un filtre de luminosité coûterait une couche de composition
                // pour un résultat identique à l'œil.
                highlight: _pressed ? AppBrandButton._pressedBrightness - 1 : 0,
                label: widget.uppercase
                    ? widget.label.toUpperCase()
                    : widget.label,
                trailingIcon: widget.trailingIcon,
                isLoading: widget.isLoading,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.highlight,
    required this.label,
    required this.trailingIcon,
    required this.isLoading,
  });

  /// Part de blanc ajoutée par-dessus le dégradé, à l'appui.
  final double highlight;
  final String label;
  final IconData? trailingIcon;
  final bool isLoading;

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
      child: isLoading ? const _Spinner() : _Label(label, trailingIcon),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: AppColors.neutral0,
        semanticsLabel: 'Chargement',
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label, this.trailingIcon);

  final String label;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.subheading.copyWith(
        fontSize: AppBrandButton._fontSize,
        color: AppColors.neutral0,
        fontWeight: FontWeight.w700,
        letterSpacing: AppBrandButton._tracking,
      ),
    );
    if (trailingIcon == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        const SizedBox(width: AppSpacing.xs),
        Icon(trailingIcon, size: 20, color: AppColors.neutral0),
      ],
    );
  }
}
