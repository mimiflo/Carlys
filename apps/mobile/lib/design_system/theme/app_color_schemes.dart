import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

/// ColorScheme Material 3 construit depuis la palette AppColors.
abstract final class AppColorSchemes {
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.primaryLight,
    onPrimary: AppColors.neutral950,
    primaryContainer: AppColors.primaryDark,
    onPrimaryContainer: AppColors.neutral50,
    secondary: AppColors.accent,
    onSecondary: AppColors.neutral950,
    secondaryContainer: AppColors.accentDark,
    onSecondaryContainer: AppColors.neutral950,
    tertiary: AppColors.info,
    onTertiary: AppColors.neutral950,
    error: AppColors.danger,
    onError: AppColors.neutral0,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkTextPrimary,
    surfaceContainerHighest: AppColors.darkSurfaceAlt,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkBorderStrong,
    outlineVariant: AppColors.darkBorder,
    shadow: AppColors.oledBackground,
    scrim: AppColors.oledBackground,
    inverseSurface: AppColors.neutral100,
    onInverseSurface: AppColors.neutral900,
    inversePrimary: AppColors.primary,
  );
}
