import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garde-fou de la typographie.
///
/// Nos trois polices sont embarquées et n'embarquent AUCUN emoji. Imposer
/// `fontFamily` sans famille de secours ne laisse au moteur nulle part où se
/// rabattre : l'emoji d'un message d'ami s'affiche alors en carré vide, sans
/// qu'aucune erreur ne soit levée. Ce fichier empêche le retour du tofu.
void main() {
  /// Tous les styles publics de l'échelle, y compris les alias.
  const styles = <String, TextStyle>{
    'display': AppTypography.display,
    'title': AppTypography.title,
    'heading': AppTypography.heading,
    'subheading': AppTypography.subheading,
    'body': AppTypography.body,
    'bodyLarge': AppTypography.bodyLarge,
    'label': AppTypography.label,
    'labelMono': AppTypography.labelMono,
    'tab': AppTypography.tab,
    'tabActive': AppTypography.tabActive,
    'metricXL': AppTypography.metricXL,
    'metricL': AppTypography.metricL,
    'metricM': AppTypography.metricM,
    'metricS': AppTypography.metricS,
    'quote': AppTypography.quote,
  };

  group('secours emoji', () {
    test('chaque style de l’échelle déclare les polices de secours', () {
      for (final entry in styles.entries) {
        expect(
          entry.value.fontFamilyFallback,
          AppTypography.emojiFallback,
          reason: '${entry.key} laisserait les emoji en carré vide',
        );
      }
    });

    test('les trois systèmes sont couverts', () {
      // Une seule répondra sur un appareil donné ; les autres sont ignorées.
      expect(
        AppTypography.emojiFallback,
        containsAll(<String>[
          'Apple Color Emoji', // iOS, macOS
          'Noto Color Emoji', // Android, Linux
          'Segoe UI Emoji', // Windows
        ]),
      );
    });

    test('le thème transmet le secours aux widgets Material', () {
      // La plupart des textes passent par le TextTheme : s'il perdait le
      // secours en chemin, la correction ne servirait à rien.
      final theme = AppTypography.textTheme(
        AppColors.darkTextPrimary,
        AppColors.darkTextSecondary,
      );

      for (final style in <TextStyle?>[
        theme.displayLarge,
        theme.headlineLarge,
        theme.headlineMedium,
        theme.titleLarge,
        theme.titleMedium,
        theme.bodyLarge,
        theme.bodyMedium,
        theme.bodySmall,
        theme.labelLarge,
        theme.labelMedium,
        theme.labelSmall,
      ]) {
        expect(style?.fontFamilyFallback, AppTypography.emojiFallback);
      }
    });
  });

  group('rôles des familles', () {
    test('les chiffres restent en chiffres tabulaires', () {
      // Sans eux, les compteurs sautent pendant les animations : le secours
      // emoji ne doit pas avoir emporté cette propriété.
      for (final style in <TextStyle>[
        AppTypography.metricXL,
        AppTypography.metricL,
        AppTypography.metricM,
        AppTypography.metricS,
        AppTypography.labelMono,
      ]) {
        expect(style.fontFamily, AppTypography.monoFamily);
        expect(style.fontFeatures, isNotEmpty);
      }
    });

    test('la police d’affiche reste réservée à la maxime', () {
      final poster = styles.entries
          .where((entry) => entry.value.fontFamily == AppTypography.quoteFamily)
          .map((entry) => entry.key);

      expect(poster, ['quote']);
    });
  });
}
