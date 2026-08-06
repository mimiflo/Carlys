import 'package:flutter/material.dart';

import '../colors/app_colors.dart';

/// ColorSchemes Material 3 construits depuis la palette AppColors.
abstract final class AppColorSchemes {
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.neutral0,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.neutral950,
    secondary: AppColors.accent,
    onSecondary: AppColors.neutral950,
    secondaryContainer: AppColors.accent,
    onSecondaryContainer: AppColors.neutral950,
    tertiary: AppColors.info,
    onTertiary: AppColors.neutral0,
    error: AppColors.danger,
    onError: AppColors.neutral0,
    surface: AppColors.lightSurface,
    onSurface: AppColors.neutral900,
    surfaceContainerHighest: AppColors.lightSurfaceAlt,
    onSurfaceVariant: AppColors.neutral600,
    outline: AppColors.neutral300,
    outlineVariant: AppColors.neutral200,
    shadow: AppColors.neutral950,
    scrim: AppColors.neutral950,
    inverseSurface: AppColors.neutral900,
    onInverseSurface: AppColors.neutral50,
    inversePrimary: AppColors.primaryLight,
  );

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
    onSurface: AppColors.neutral100,
    surfaceContainerHighest: AppColors.darkSurfaceAlt,
    onSurfaceVariant: AppColors.neutral400,
    outline: AppColors.neutral600,
    outlineVariant: AppColors.neutral700,
    shadow: AppColors.oledBackground,
    scrim: AppColors.oledBackground,
    inverseSurface: AppColors.neutral100,
    onInverseSurface: AppColors.neutral900,
    inversePrimary: AppColors.primary,
  );
}
