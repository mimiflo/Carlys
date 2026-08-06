import 'package:flutter/material.dart';

import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';

/// Carte de surface standard, cliquable ou non.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Material(
      color: colorScheme.surface,
      borderRadius: AppRadius.lgAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (semanticLabel == null) {
      return content;
    }
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: content,
    );
  }
}
