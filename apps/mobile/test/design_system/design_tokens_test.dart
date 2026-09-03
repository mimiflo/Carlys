import 'dart:convert';
import 'dart:io';

import 'package:carlys_mobile/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le pont entre `packages/design-tokens/src/tokens.json` et le design
/// system Flutter est MANUEL : ce fichier est ce qui l'empêche de lâcher.
///
/// Cinq durées de `motion.duration` n'avaient jamais été portées, et leurs
/// valeurs se réécrivaient à la main jusque dans le design system. Chaque
/// token comparé ici doit avoir son reflet, à la valeur près — et chaque
/// reflet son token : une constante Flutter sans token ment tout autant.
void main() {
  late Map<String, Object?> tokens;

  setUpAll(() {
    tokens =
        jsonDecode(_tokensFile().readAsStringSync()) as Map<String, Object?>;
  });

  /// Une section du fichier (« motion.duration »), sans ses commentaires
  /// (`$comment-…`), qui documentent et ne se reflètent pas.
  Map<String, Object?> section(String path) {
    Object? node = tokens;
    for (final segment in path.split('.')) {
      node = (node! as Map<String, Object?>)[segment];
    }
    return {
      for (final entry in (node! as Map<String, Object?>).entries)
        if (!entry.key.startsWith(r'$')) entry.key: entry.value,
    };
  }

  group('motion.duration ↔ AppMotion', () {
    const durations = <String, Duration>{
      'instant': AppMotion.instant,
      'fast': AppMotion.fast,
      'normal': AppMotion.normal,
      'slow': AppMotion.slow,
      'deliberate': AppMotion.deliberate,
      'ambient': AppMotion.ambient,
      'tap': AppMotion.tap,
      'tab': AppMotion.tab,
      'route': AppMotion.route,
      'ring': AppMotion.ring,
      'dashLoop': AppMotion.dashLoop,
    };

    test('chaque token a son reflet, à la milliseconde', () {
      final declared = section('motion.duration');
      expect(
        declared.keys.toSet(),
        durations.keys.toSet(),
        reason: 'un token sans reflet, ou un reflet sans token',
      );
      for (final entry in declared.entries) {
        expect(
          durations[entry.key]!.inMilliseconds,
          entry.value,
          reason: 'motion.duration.${entry.key}',
        );
      }
    });

    test('le thème donne aux pages la durée du token route', () {
      // Le routeur ne déclare rien : c'est le thème qui porte le tempo, sur
      // chaque plateforme, dans les deux sens.
      final builders = AppTheme.dark().pageTransitionsTheme.builders;
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        final builder = builders[platform];
        expect(builder, isNotNull, reason: '$platform');
        expect(builder!.transitionDuration, AppMotion.route);
        expect(builder.reverseTransitionDuration, AppMotion.route);
      }
    });
  });

  group('spacing ↔ AppSpacing', () {
    const spacing = <String, double>{
      'xxs': AppSpacing.xxs,
      'xs': AppSpacing.xs,
      'sm': AppSpacing.sm,
      'md': AppSpacing.md,
      'lg': AppSpacing.lg,
      'xl': AppSpacing.xl,
      'xxl': AppSpacing.xxl,
      'xxxl': AppSpacing.xxxl,
      'gutter': AppSpacing.gutter,
      'gapTile': AppSpacing.gapTile,
      'gapRow': AppSpacing.gapRow,
      'gapSection': AppSpacing.gapSection,
      'padCard': AppSpacing.padCard,
      'touchTarget': AppSpacing.touchTarget,
    };

    test('chaque token a son reflet, au point près', () {
      final declared = section('spacing');
      expect(
        declared.keys.toSet(),
        spacing.keys.toSet(),
        reason: 'un token sans reflet, ou un reflet sans token',
      );
      for (final entry in declared.entries) {
        expect(
          spacing[entry.key],
          (entry.value! as num).toDouble(),
          reason: 'spacing.${entry.key}',
        );
      }
    });
  });

  group('color.darkRoles ↔ AppColors', () {
    // Les rôles opaques : ceux dont un test de contraste peut répondre.
    const roles = <String, Color>{
      'textPrimary': AppColors.darkTextPrimary,
      'textSecondary': AppColors.darkTextSecondary,
      'textTertiary': AppColors.darkTextTertiary,
      'iconInactive': AppColors.darkIconInactive,
      'textMuted': AppColors.textMuted,
    };

    test('chaque rôle de texte reflète son hexadécimal', () {
      final declared = section('color.darkRoles');
      for (final entry in roles.entries) {
        final hex = declared[entry.key];
        expect(hex, isA<String>(), reason: 'color.darkRoles.${entry.key}');
        expect(
          entry.value.toARGB32().toRadixString(16).toUpperCase(),
          'FF${(hex! as String).substring(1).toUpperCase()}',
          reason: 'color.darkRoles.${entry.key}',
        );
      }
    });
  });
}

/// Le fichier de tokens, cherché en remontant depuis le dossier courant :
/// `flutter test` part de `apps/mobile`, mais rien n'oblige à l'y lancer.
File _tokensFile() {
  var directory = Directory.current;
  for (var depth = 0; depth < 6; depth++) {
    final candidate = File(
      '${directory.path}/packages/design-tokens/src/tokens.json',
    );
    if (candidate.existsSync()) return candidate;
    directory = directory.parent;
  }
  throw StateError(
    'tokens.json introuvable au-dessus de ${Directory.current.path}',
  );
}
