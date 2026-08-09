import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Carte d'un groupe musculaire dans la bibliothèque.
///
/// L'image est un **détourage** posé sur la surface de la carte, pas une
/// photographie encadrée : le muscle sollicité flotte sur le fond de
/// l'application. Le nom est écrit par l'application — il vient du référentiel
/// de l'API, il se traduit, et il reste net à toutes les tailles.
class MuscleGroupCard extends StatelessWidget {
  const MuscleGroupCard({
    required this.label,
    required this.slug,
    required this.onTap,
    super.key,
  });

  final String label;

  /// Slug du référentiel, ou `null` pour la carte « Tous les mouvements ».
  final String? slug;
  final VoidCallback onTap;

  /// Proportion de la carte : l'image respire au-dessus du nom.
  static const double aspectRatio = 0.80;

  /// Hauteur réservée au nom, deux lignes comprises.
  static const double _labelHeight = 28;

  /// Groupes dont le détourage est embarqué. Ce n'est pas un référentiel —
  /// c'est l'inventaire de `assets/muscles/`, qui ne peut pas se deviner à
  /// l'exécution. Un groupe absent d'ici s'affiche sans image, **jamais** avec
  /// celle d'un autre muscle : une anatomie fausse enseignerait une erreur.
  static const Set<String> illustrated = {
    'abdominaux',
    'avant-bras',
    'biceps',
    'dos',
    'epaules',
    'fessiers',
    'lombaires',
    'mollets',
    'pectoraux',
    'quadriceps',
    'triceps',
  };

  static const String allSlug = 'tous';

  static String? assetFor(String? slug) {
    final name = slug ?? allSlug;
    if (name != allSlug && !illustrated.contains(name)) return null;
    return 'assets/muscles/$name.webp';
  }

  @override
  Widget build(BuildContext context) {
    final asset = assetFor(slug);

    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: AppRadius.cardSecondaryAll,
              border: Border.fromBorderSide(
                BorderSide(color: AppColors.darkBorder),
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const _Halo(),
                      if (asset != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xs,
                            AppSpacing.xs,
                            AppSpacing.xs,
                            0,
                          ),
                          child: Image.asset(
                            asset,
                            fit: BoxFit.contain,
                            // Un fichier manquant ne casse pas l'écran : la
                            // carte garde sa forme et son nom.
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        )
                      else
                        const Center(
                          child: Icon(
                            AppIcons.exercises,
                            size: 40,
                            color: AppColors.darkIconInactive,
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxs,
                    0,
                    AppSpacing.xxs,
                    AppSpacing.xs,
                  ),
                  // Deux lignes réservées quel qu'en soit le besoin : sinon
                  // « Ischio-jambiers » descendrait son image d'un cran et la
                  // grille perdrait son alignement.
                  child: SizedBox(
                    height: _labelHeight,
                    child: Center(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        // Trois colonnes : le nom passe au corps « label »,
                        // sinon « Ischio-jambiers » se tronque à la première
                        // ligne.
                        style: AppTypography.label.copyWith(
                          color: AppColors.darkTextPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lueur violette derrière le sujet : sans elle, un détourage sombre posé sur
/// une surface sombre n'a plus de contour.
class _Halo extends StatelessWidget {
  const _Halo();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, 0.15),
          radius: 0.85,
          colors: [AppColors.primaryCardStrong, Color(0x00000000)],
        ),
      ),
    );
  }
}
