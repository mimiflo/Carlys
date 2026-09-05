import 'package:flutter/widgets.dart';

import '../colors/app_colors.dart';

/// Ombres Carlys (tokens : shadow.*). En thème sombre, préférer les
/// variations de surface aux ombres.
abstract final class AppShadows {
  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x1416162A), offset: Offset(0, 1), blurRadius: 3),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x1A16162A), offset: Offset(0, 4), blurRadius: 12),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x2416162A), offset: Offset(0, 12), blurRadius: 32),
  ];

  /// Halo discret pour mettre en avant un élément de marque (records…).
  static List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.35),
      offset: const Offset(0, 4),
      blurRadius: 16,
    ),
  ];
}
