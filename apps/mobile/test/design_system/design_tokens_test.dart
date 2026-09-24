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
      'reveal': AppMotion.reveal,
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

    test('deux thèmes identiques portent le même thème de transitions', () {
      // Sans égalité de valeur sur les bâtisseurs, deux AppTheme.dark() ne
      // sont jamais égaux et MaterialApp anime une transition de thème à
      // chaque reconstruction, entre deux thèmes pourtant identiques.
      expect(
        AppTheme.dark().pageTransitionsTheme,
        AppTheme.dark().pageTransitionsTheme,
      );
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

  group('color.brand (dégradés, accents) ↔ AppColors', () {
    // Les bornes des dégradés de marque — la signature du logo, sa variante
    // sous un texte, et le violet des libellés blancs (ctaStart assombri
    // depuis la maquette pour tenir AA) — et le rose clair des icônes de
    // champ des écrans d'entrée.
    const gradients = <String, Color>{
      'signatureStart': AppColors.signatureStart,
      'signatureMid': AppColors.signatureMid,
      'signatureEnd': AppColors.signatureEnd,
      'signatureInkMid': AppColors.signatureInkMid,
      'signatureInkEnd': AppColors.signatureInkEnd,
      'ctaStart': AppColors.ctaStart,
      'ctaEnd': AppColors.ctaEnd,
      'fieldIcon': AppColors.fieldIcon,
    };

    test('chaque borne reflète son hexadécimal', () {
      final declared = section('color.brand');
      for (final entry in gradients.entries) {
        final hex = declared[entry.key];
        expect(hex, isA<String>(), reason: 'color.brand.${entry.key}');
        expect(
          entry.value.toARGB32().toRadixString(16).toUpperCase(),
          'FF${(hex! as String).substring(1).toUpperCase()}',
          reason: 'color.brand.${entry.key}',
        );
      }
    });

    test('le bouton d’entrée court du clair au profond, sans autre arrêt', () {
      expect(AppColors.cta.colors, const [
        AppColors.ctaStart,
        AppColors.ctaEnd,
      ]);
    });

    test('la signature sous un texte reflète color.gradient.signatureInk', () {
      final declared =
          (tokens['color']! as Map<String, Object?>)['gradient']!
              as Map<String, Object?>;
      final ink = declared['signatureInk']! as Map<String, Object?>;
      expect(
        [
          for (final color in AppColors.signatureInk.colors)
            color.toARGB32().toRadixString(16).toUpperCase(),
        ],
        [
          for (final hex in ink['colors']! as List<Object?>)
            'FF${(hex! as String).substring(1).toUpperCase()}',
        ],
      );
      expect(AppColors.signatureInk.stops, [
        for (final stop in ink['stops']! as List<Object?>)
          (stop! as num).toDouble(),
      ]);
    });
  });

  group('color.semantic ↔ AppColors', () {
    // Les rouges, verts, ambres et bleus d'ÉTAT, et le rouge de remplissage
    // des boutons destructifs : chacun a son reflet, et aucun reflet n'est
    // sans token.
    const semantic = <String, Color>{
      'success': AppColors.success,
      'warning': AppColors.warning,
      'danger': AppColors.danger,
      'info': AppColors.info,
      'dangerStrong': AppColors.dangerStrong,
    };

    test(
      'chaque couleur d’état reflète son hexadécimal, et rien ne manque',
      () {
        final declared = section('color.semantic');
        expect(
          declared.keys.toSet(),
          semantic.keys.toSet(),
          reason: 'un token sans reflet, ou un reflet sans token',
        );
        for (final entry in semantic.entries) {
          final hex = declared[entry.key];
          expect(hex, isA<String>(), reason: 'color.semantic.${entry.key}');
          expect(
            entry.value.toARGB32().toRadixString(16).toUpperCase(),
            'FF${(hex! as String).substring(1).toUpperCase()}',
            reason: 'color.semantic.${entry.key}',
          );
        }
      },
    );
  });

  group('color.surface.darkScrim* ↔ AppColors', () {
    // Les voiles des popups : des couleurs TRANSLUCIDES, écrites en rgba
    // dans le fichier de tokens et en ARGB ici — l'alpha se compare à
    // l'octet près (0,72 × 255 = 183,6 → 184 ; 0,4 × 255 = 102).
    const voiles = {
      'darkScrim': AppColors.darkScrim,
      'darkScrimSoft': AppColors.darkScrimSoft,
    };
    for (final MapEntry(key: name, value: color) in voiles.entries) {
      test('$name reflète son rgba, alpha compris', () {
        final declared = section('color.surface')[name];
        expect(declared, isA<String>(), reason: 'color.surface.$name');
        final rgba = RegExp(
          r'^rgba\((\d+),(\d+),(\d+),([\d.]+)\)$',
        ).firstMatch(declared! as String);
        expect(rgba, isNotNull, reason: 'rgba(r,g,b,a) attendu : $declared');
        final expected = Color.fromARGB(
          (double.parse(rgba![4]!) * 255).round(),
          int.parse(rgba[1]!),
          int.parse(rgba[2]!),
          int.parse(rgba[3]!),
        );
        expect(color.toARGB32(), expected.toARGB32());
      });
    }
  });

  group('color.vendor ↔ AppColors', () {
    // Les couleurs de marques TIERCES (le « G » de Google) : des constantes
    // de charte externes — une dérive d'un côté du pont trahirait le logo.
    const vendor = <String, Color>{
      'googleBlue': AppColors.googleBlue,
      'googleRed': AppColors.googleRed,
      'googleYellow': AppColors.googleYellow,
      'googleGreen': AppColors.googleGreen,
    };

    test(
      'chaque couleur tierce reflète son hexadécimal, et rien ne manque',
      () {
        final declared = section('color.vendor');
        expect(
          declared.keys.toSet(),
          vendor.keys.toSet(),
          reason: 'un token sans reflet, ou un reflet sans token',
        );
        for (final entry in vendor.entries) {
          final hex = declared[entry.key];
          expect(hex, isA<String>(), reason: 'color.vendor.${entry.key}');
          expect(
            entry.value.toARGB32().toRadixString(16).toUpperCase(),
            'FF${(hex! as String).substring(1).toUpperCase()}',
            reason: 'color.vendor.${entry.key}',
          );
        }
      },
    );
  });

  group('color.league ↔ AppColors', () {
    // Les métaux des cinq divisions, réservés aux ligues : trois tons par
    // métal (reflet, corps, ombre). Quinze teintes recopiées à la main — une
    // table de clés seule laisserait passer celle qu'on a oublié de porter.
    const league = <String, Color>{
      'bronzeLight': AppColors.leagueBronzeLight,
      'bronze': AppColors.leagueBronze,
      'bronzeDark': AppColors.leagueBronzeDark,
      'silverLight': AppColors.leagueSilverLight,
      'silver': AppColors.leagueSilver,
      'silverDark': AppColors.leagueSilverDark,
      'goldLight': AppColors.leagueGoldLight,
      'gold': AppColors.leagueGold,
      'goldDark': AppColors.leagueGoldDark,
      'platinumLight': AppColors.leaguePlatinumLight,
      'platinum': AppColors.leaguePlatinum,
      'platinumDark': AppColors.leaguePlatinumDark,
      'diamondLight': AppColors.leagueDiamondLight,
      'diamond': AppColors.leagueDiamond,
      'diamondDark': AppColors.leagueDiamondDark,
    };

    test('chaque ton de métal reflète son hexadécimal, et rien ne manque', () {
      final declared = section('color.league');
      expect(
        declared.keys.toSet(),
        league.keys.toSet(),
        reason: 'un token sans reflet, ou un reflet sans token',
      );
      for (final entry in league.entries) {
        final hex = declared[entry.key];
        expect(hex, isA<String>(), reason: 'color.league.${entry.key}');
        expect(
          entry.value.toARGB32().toRadixString(16).toUpperCase(),
          'FF${(hex! as String).substring(1).toUpperCase()}',
          reason: 'color.league.${entry.key}',
        );
      }
    });

    test('chaque métal va du reflet à l’ombre, en s’assombrissant', () {
      // `…Light`, le corps, `…Dark` : l'ordre que le nom promet. Un reflet
      // plus sombre que le corps éteindrait le blason au lieu de l'éclairer.
      for (final metal in ['bronze', 'silver', 'gold', 'platinum', 'diamond']) {
        final reflet = league['${metal}Light']!.computeLuminance();
        final corps = league[metal]!.computeLuminance();
        final ombre = league['${metal}Dark']!.computeLuminance();
        expect(reflet, greaterThan(corps), reason: '$metal : reflet ≤ corps');
        expect(corps, greaterThan(ombre), reason: '$metal : corps ≤ ombre');
      }
    });
  });

  group('radius ↔ AppRadius', () {
    const radius = <String, double>{
      'xs': AppRadius.xs,
      'sm': AppRadius.sm,
      'md': AppRadius.md,
      'lg': AppRadius.lg,
      'xl': AppRadius.xl,
      'full': AppRadius.full,
      'cardMain': AppRadius.cardMain,
      'cardSecondary': AppRadius.cardSecondary,
      'listRow': AppRadius.listRow,
      'statTile': AppRadius.statTile,
      'button': AppRadius.button,
      'avatar': AppRadius.avatar,
      'phoneFrame': AppRadius.phoneFrame,
    };

    test('chaque token a son reflet, au point près', () {
      final declared = section('radius');
      expect(
        declared.keys.toSet(),
        radius.keys.toSet(),
        reason: 'un token sans reflet, ou un reflet sans token',
      );
      for (final entry in declared.entries) {
        expect(
          radius[entry.key],
          (entry.value! as num).toDouble(),
          reason: 'radius.${entry.key}',
        );
      }
    });
  });

  group('breakpoint ↔ AppBreakpoints', () {
    const breakpoints = <String, double>{
      'compact': AppBreakpoints.compact,
      'medium': AppBreakpoints.medium,
      'expanded': AppBreakpoints.expanded,
      'large': AppBreakpoints.large,
      'xlarge': AppBreakpoints.xlarge,
    };

    test('chaque token a son reflet, au point près', () {
      final declared = section('breakpoint');
      expect(
        declared.keys.toSet(),
        breakpoints.keys.toSet(),
        reason: 'un token sans reflet, ou un reflet sans token',
      );
      for (final entry in declared.entries) {
        expect(
          breakpoints[entry.key],
          (entry.value! as num).toDouble(),
          reason: 'breakpoint.${entry.key}',
        );
      }
    });
  });

  group('shadow ↔ AppShadows', () {
    const shadows = <String, List<BoxShadow>>{
      'sm': AppShadows.sm,
      'md': AppShadows.md,
      'lg': AppShadows.lg,
    };

    test('décalage, flou et opacité suivent le token', () {
      final declared = section('shadow');
      expect(
        declared.keys.toSet(),
        shadows.keys.toSet(),
        reason: 'un token sans reflet, ou un reflet sans token',
      );
      for (final entry in declared.entries) {
        final token = entry.value! as Map<String, Object?>;
        final ombres = shadows[entry.key]!;
        expect(ombres, hasLength(1), reason: 'shadow.${entry.key}');
        final ombre = ombres.single;
        expect(
          ombre.offset.dy,
          (token['y']! as num).toDouble(),
          reason: 'shadow.${entry.key}.y',
        );
        expect(
          ombre.blurRadius,
          (token['blur']! as num).toDouble(),
          reason: 'shadow.${entry.key}.blur',
        );
        // L'opacité du token se lit dans le canal alpha de la couleur, à
        // l'arrondi d'un octet près (0.08 × 255 = 20,4 → 20).
        expect(
          (ombre.color.a * 255).round(),
          ((token['opacity']! as num).toDouble() * 255).round(),
          reason: 'shadow.${entry.key}.opacity',
        );
      }
    });
  });

  group('typography.scale ↔ AppTypography', () {
    const styles = <String, TextStyle>{
      'display': AppTypography.display,
      'title': AppTypography.title,
      'heading': AppTypography.heading,
      'subheading': AppTypography.subheading,
      'body': AppTypography.body,
      'label': AppTypography.label,
      'tab': AppTypography.tab,
      'metricXL': AppTypography.metricXL,
      'metricL': AppTypography.metricL,
      'metricM': AppTypography.metricM,
      'metricS': AppTypography.metricS,
      'labelMono': AppTypography.labelMono,
    };

    const familles = <String, String>{
      'body': AppTypography.textFamily,
      'mono': AppTypography.monoFamily,
      'quote': AppTypography.quoteFamily,
    };

    test('taille, interligne, graisse et FAMILLE suivent le token', () {
      final declared = section('typography.scale');
      expect(
        declared.keys.toSet(),
        styles.keys.toSet(),
        reason: 'un token sans reflet, ou un reflet sans token',
      );
      for (final entry in declared.entries) {
        final token = entry.value! as Map<String, Object?>;
        final style = styles[entry.key]!;
        expect(
          style.fontSize,
          (token['size']! as num).toDouble(),
          reason: 'typography.scale.${entry.key}.size',
        );
        expect(
          style.height,
          (token['lineHeight']! as num).toDouble(),
          reason: 'typography.scale.${entry.key}.lineHeight',
        );
        expect(
          style.fontWeight!.value,
          token['weight'],
          reason: 'typography.scale.${entry.key}.weight',
        );
        expect(
          style.fontFamily,
          familles[token['family']],
          reason: 'typography.scale.${entry.key}.family',
        );
      }
    });

    test('l’interlettrage est le token × la taille — il est en EM', () {
      // Le piège de ce pont, et la raison pour laquelle il méritait d'être
      // tendu : `letterSpacingEm` est RELATIF dans le fichier de jetons, là
      // où Flutter stocke des points absolus. Cinq titres d'écran écrivaient
      // `display.copyWith(fontSize: 27)` et gardaient donc l'interlettrage
      // calculé pour 30 — le style dérivé était plus serré que le jeton ne le
      // demande, sans que rien ne le signale.
      final declared = section('typography.scale');
      for (final entry in declared.entries) {
        final token = entry.value! as Map<String, Object?>;
        final em = (token['letterSpacingEm']! as num).toDouble();
        final taille = (token['size']! as num).toDouble();
        final attendu = em * taille;
        final style = styles[entry.key]!;
        expect(
          style.letterSpacing ?? 0,
          closeTo(attendu, 0.005),
          reason: 'typography.scale.${entry.key}.letterSpacingEm',
        );
      }
    });

    test('AppTypography.resized garde la PROPORTION de l’interlettrage', () {
      // La sortie de secours quand une taille hors échelle est vraiment
      // voulue : `copyWith(fontSize:)` laisse l'interlettrage d'origine,
      // `resized` le recalcule.
      final derive = AppTypography.resized(AppTypography.display, 15);

      expect(derive.fontSize, 15);
      expect(derive.letterSpacing, closeTo(-0.45, 0.001)); // -0,03 × 15
      expect(
        AppTypography.display.copyWith(fontSize: 15).letterSpacing,
        AppTypography.display.letterSpacing,
      );
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
