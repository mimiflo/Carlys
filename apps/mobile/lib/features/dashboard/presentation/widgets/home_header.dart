import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../../onboarding/presentation/widgets/brand_signature.dart';

/// En-tête de l'accueil : date du jour en mono, salutation, phrase d'état,
/// avatar 44×44 en dégradé violet portant l'initiale.
///
/// La salutation tient sur UNE ligne : la zone haute appartient au cœur, et
/// chaque ligne de texte gagnée est du cœur rendu visible.
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

  /// Hauteur FIXE de l'en-tête.
  ///
  /// Elle vaut le pire cas de la colonne de texte — rangée marque et date
  /// (15) + 8 + salutation (24,2) + 4 + phrase d'état sur DEUX lignes
  /// (37,7) ≈ 89 — donc au-delà de l'avatar. La fixer permet à la zone haute
  /// de calculer exactement la place qui reste à la citation, plutôt que de
  /// la mesurer après coup.
  ///
  /// C'est le sceau de marque qui commande : sans lui, la première rangée
  /// tenait dans les 10 points du libellé mono.
  static const double height = 89;

  /// La phrase d'état ne dépasse jamais deux lignes : au-delà elle pousserait
  /// la citation hors de sa bande.
  static const int _subtitleMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final firstName = displayName?.split(' ').first;
    final initial = firstName == null || firstName.isEmpty
        ? '?'
        : firstName.characters.first.toUpperCase();

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Le sceau de marque, à hauteur de la date : l'accueil
                    // est le seul écran où Carlys signe son nom.
                    const _BrandMark(),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: AppSectionLabel(
                        formatLongDateMono(DateTime.now()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  firstName == null ? 'Bonjour' : 'Bonjour, $firstName.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title
                      .copyWith(color: AppColors.darkTextPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  maxLines: _subtitleMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body
                      .copyWith(color: AppColors.darkTextSecondary),
                ),
              ],
            ),
          ),
          Semantics(
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
                child: Center(
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
        ],
      ),
    );
  }
}

/// Le sceau de marque de l'en-tête, halo violet compris.
///
/// Il reprend l'image de la page de bienvenue — la même signature du premier
/// jour au centième, sans deuxième fichier à tenir à jour.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  static const double _height = 15;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.45),
            blurRadius: 10,
          ),
        ],
      ),
      child: Image.asset(
        BrandSignature.markAsset,
        height: _height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        // La marque est décorative ici : elle ne doit pas retarder la
        // première image de l'écran le plus ouvert de l'application.
        gaplessPlayback: true,
      ),
    );
  }
}

/// L'avatar est LA porte du profil depuis la réorganisation en cinq onglets :
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
