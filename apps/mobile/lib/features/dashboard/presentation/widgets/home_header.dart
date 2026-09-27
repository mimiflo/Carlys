import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import 'home_brand_mark.dart';

/// En-tête de l'accueil : date du jour en mono, salutation, phrase d'état,
/// avatar 44×44 en dégradé violet portant l'initiale.
///
/// La salutation tient sur une ligne à la taille d'origine, et passe à la
/// ligne plutôt que de perdre le prénom sous une ellipse (petit écran, texte
/// agrandi, prénom long) : l'en-tête grandit alors, comme pour la phrase
/// d'état, et la citation part dessous.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.displayName,
    required this.subtitle,
    super.key,
  });

  final String? displayName;

  /// Phrase d'état, toujours adossée à un fait (séance en cours, séance du
  /// jour faite, récupération écoulée).
  final String subtitle;

  /// Géométrie de la maquette : vignette carrée de 44.
  static const double _avatarSize = 44;

  /// Hauteur RÉSERVÉE à l'en-tête pour une échelle de texte donnée : un
  /// plancher, pas un plafond.
  ///
  /// Elle vaut la colonne de texte — rangée marque et date (15) + 8 +
  /// salutation (24,2) + 4 + phrase d'état sur DEUX lignes (37,7) ≈ 89 à la
  /// taille d'origine — donc au-delà de l'avatar. La calculer permet à la
  /// zone haute de connaître exactement la place qui reste à la citation,
  /// plutôt que de la mesurer après coup.
  ///
  /// Elle était FIXE, à 89 : dès le texte ×1,15, la seconde ligne de la
  /// phrase d'état se peignait par-dessus la citation. Chaque ligne suit
  /// désormais l'échelle du texte système ; seul le sceau de marque, une
  /// image, garde ses 15 points.
  static double heightFor(TextScaler scaler) {
    double lines(TextStyle style, int count) =>
        scaler.scale(style.fontSize!) * style.height! * count;
    final brandRow = math.max(HomeBrandMark.height, lines(_dateStyle, 1));
    return (brandRow +
            AppSpacing.xs +
            lines(_greetingStyle, 1) +
            AppSpacing.xxs +
            lines(_subtitleStyle, _reservedSubtitleLines))
        .ceilToDouble();
  }

  static const TextStyle _dateStyle = AppTypography.labelMono;
  static final TextStyle _greetingStyle = AppTypography.title.copyWith(
    color: AppColors.darkTextPrimary,
  );
  static final TextStyle _subtitleStyle = AppTypography.body.copyWith(
    color: AppColors.darkTextSecondary,
  );

  /// Deux lignes RÉSERVÉES à la phrase d'état : à la taille d'origine,
  /// chaque phrase y tient, et la zone haute garde la même hauteur tous les
  /// jours. Au-delà, l'en-tête donne à la phrase les lignes qu'elle demande
  /// plutôt que d'en couper la fin : [heightFor] est son plancher.
  ///
  /// Un plafond (trois lignes au-delà de ×1,3) ne suffisait pas : à 320
  /// points en texte ×2, « Ton corps encaisse encore la dernière séance. »
  /// en demande quatre, et perdait sa fin sous une ellipse. Et une mesure à
  /// part ne voit ni le style hérité ni le réglage « texte en gras » du
  /// système, que le texte peint, lui, applique.
  static const int _reservedSubtitleLines = 2;

  @override
  Widget build(BuildContext context) {
    final firstName = displayName?.split(' ').first;
    final initial = firstName == null || firstName.isEmpty
        ? '?'
        : firstName.characters.first.toUpperCase();

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: heightFor(MediaQuery.textScalerOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            // Une FRONTIÈRE pour le lecteur d'écran : sans elle, la date, la
            // salutation et la phrase d'état remontaient dans le bouton du
            // profil, citation comprise, et un double-tap pour relire
            // ouvrait le profil.
            child: Semantics(
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Le sceau de marque, à hauteur de la date : l'accueil
                      // est le seul écran où Carlys signe son nom.
                      const HomeBrandMark(),
                      const SizedBox(width: AppSpacing.xs),
                      // Une ligne, toujours : la hauteur de l'en-tête la
                      // compte pour une.
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AppSectionLabel(
                            formatLongDateMono(DateTime.now()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Entière, toujours : à 320 points en texte ×2,
                  // « Bonjour, Maximilien-Alexandre. » demande quatre lignes,
                  // et un plafond à deux le couperait encore.
                  Semantics(
                    header: true,
                    child: Text(
                      firstName == null ? 'Bonjour' : 'Bonjour, $firstName.',
                      style: _greetingStyle,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  // Entière, toujours : voir [_reservedSubtitleLines].
                  Text(subtitle, style: _subtitleStyle),
                ],
              ),
            ),
          ),
          Semantics(
            container: true,
            label: firstName == null ? 'Profil' : 'Profil de $firstName',
            button: true,
            child: _AvatarButton(
              child: Container(
                width: _avatarSize,
                height: _avatarSize,
                decoration: BoxDecoration(
                  borderRadius: AppRadius.avatarAll,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      // Violet éteint de la maquette, dérivé des tokens.
                      Color.lerp(
                        AppColors.primary,
                        AppColors.darkBackground,
                        0.55,
                      )!,
                    ],
                  ),
                  border: const Border.fromBorderSide(
                    BorderSide(color: AppColors.darkBorderStrong),
                  ),
                ),
                // L'initiale est un ornement : le bouton se dit par son
                // libellé, sans « M » accolé.
                child: Center(
                  child: ExcludeSemantics(
                    child: Text(
                      initial,
                      style: AppTypography.subheading.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.neutral0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'avatar est LA porte du profil depuis la réorganisation d'août 2026 :
/// l'onglet Profil n'existe plus, ce geste le remplace.
class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(AppRoutes.profile),
      borderRadius: AppRadius.avatarAll,
      child: child,
    );
  }
}
