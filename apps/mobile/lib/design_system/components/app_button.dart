import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';

enum AppButtonVariant {
  primary,
  secondary,
  ghost,

  /// Plein ACCENT. Réservé à l'amorce d'un écran qui n'a encore rien à
  /// montrer : une seule occurrence d'orange par écran, jamais deux.
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
    final sized =
        isExpanded ? SizedBox(width: double.infinity, child: button) : button;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: semanticLabel ?? label,
      child: sized,
    );
  }

  Widget _buildVariant(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onPressedOrNull = _enabled ? onPressed : null;
    final child = _buildChild(context);

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
          onPressed: onPressedOrNull,
          style: _sizeStyle(),
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
      AppButtonVariant.destructive => FilledButton(
          onPressed: onPressedOrNull,
          style: _sizeStyle().merge(
            FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
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
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: Theme.of(context).colorScheme.onPrimary,
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
