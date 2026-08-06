import 'package:flutter/material.dart';

import '../spacing/app_spacing.dart';

/// Indicateur de chargement standard, avec libellé accessible.
class AppLoadingIndicator extends StatelessWidget {
  const AppLoadingIndicator({
    this.label,
    this.size = 32,
    super.key,
  });

  /// Texte affiché sous l'indicateur (et lu par les lecteurs d'écran).
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: size,
            width: size,
            child: CircularProgressIndicator(
              semanticsLabel: label ?? 'Chargement',
            ),
          ),
          if (label != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
