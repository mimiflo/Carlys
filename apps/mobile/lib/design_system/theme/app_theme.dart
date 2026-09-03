import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../motion/app_motion.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_color_schemes.dart';
import 'app_page_transitions.dart';

/// Thèmes Carlys : clair, sombre et sombre OLED.
/// Toute valeur visuelle provient des tokens du design system.
abstract final class AppTheme {
  static ThemeData light() => _build(
        colorScheme: AppColorSchemes.light,
        background: AppColors.lightBackground,
      );

  static ThemeData dark() => _build(
        colorScheme: AppColorSchemes.dark,
        background: AppColors.darkBackground,
      );

  /// Variante sombre pour écrans OLED : fond noir pur, économie d'énergie.
  static ThemeData oledDark() => _build(
        colorScheme: AppColorSchemes.dark,
        background: AppColors.oledBackground,
      );

  static ThemeData _build({
    required ColorScheme colorScheme,
    required Color background,
  }) {
    // Première passe : ThemeData fusionne notre échelle typographique avec
    // la typographie de la plateforme (famille de police résolue incluse).
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: AppTypography.textTheme(
        colorScheme.onSurface,
        colorScheme.onSurfaceVariant,
      ),
    );
    // Les styles explicites (AppBar, boutons) dérivent du thème RÉSOLU :
    // même famille de police que le reste de l'app sur chaque plateforme.
    final textTheme = base.textTheme;
    final buttonTextStyle =
        textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      // Les transitions de page gardent le GESTE de chaque plateforme
      // (retour prédictif Android, glissement iOS) mais prennent la durée
      // du token `route` : c'est ici, et non dans le routeur, que le design
      // system fixe le rythme d'une navigation.
      pageTransitionsTheme: AppPageTransitions.theme(AppMotion.route),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape:
              const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          textStyle: buttonTextStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, AppSpacing.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape:
              const RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
          textStyle: buttonTextStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.buttonAll,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonAll,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.buttonAll,
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: AppSpacing.lg,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: AppTypography.body.copyWith(
          color: colorScheme.onInverseSurface,
        ),
      ),
    );
  }
}
