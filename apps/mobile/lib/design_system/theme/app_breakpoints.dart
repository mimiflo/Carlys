import 'package:flutter/widgets.dart';

/// Classes de taille de fenêtre (tokens : breakpoint.*), alignées sur les
/// window size classes Material 3. Base des layouts adaptatifs
/// (barre inférieure mobile, rail tablette, panneau latéral desktop).
enum WindowSize {
  compact,
  medium,
  expanded,
  large,
  xlarge;

  static WindowSize fromWidth(double width) {
    if (width >= AppBreakpoints.xlarge) return WindowSize.xlarge;
    if (width >= AppBreakpoints.large) return WindowSize.large;
    if (width >= AppBreakpoints.expanded) return WindowSize.expanded;
    if (width >= AppBreakpoints.medium) return WindowSize.medium;
    return WindowSize.compact;
  }

  bool get isCompact => this == WindowSize.compact;
  bool get isAtLeastMedium => index >= WindowSize.medium.index;
  bool get isAtLeastExpanded => index >= WindowSize.expanded.index;
}

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;
  static const double large = 1200;
  static const double xlarge = 1600;
}

extension WindowSizeContext on BuildContext {
  /// Classe de taille de la fenêtre courante.
  WindowSize get windowSize =>
      WindowSize.fromWidth(MediaQuery.sizeOf(this).width);
}
