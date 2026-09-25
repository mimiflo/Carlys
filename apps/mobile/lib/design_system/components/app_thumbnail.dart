import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';

/// Le geste posé en surimpression sur une [AppThumbnail] : un petit bouton
/// rond, en bas à droite (changer la photo d'un plat).
class AppThumbnailAction {
  const AppThumbnailAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;

  /// Ce que le lecteur d'écran annonce, et l'infobulle d'un appui long.
  final String tooltip;
  final VoidCallback onPressed;
}

/// Une VIGNETTE carrée aux angles arrondis : une photo, ou à défaut un
/// dessin violet — jamais une case vide.
///
/// Sans [image] (ou si elle ne se charge pas), la vignette se peint au
/// dégradé violet de l'application ([AppColors.violetRamp], une surface sans
/// texte) et porte [fallbackIcon] en blanc : le moment du repas, une
/// assiette. Un cadre gris vide laisserait croire à une photo manquée.
///
/// [action] pose un petit bouton rond en bas à droite. Le disque est un
/// ornement de 32 points ; la zone qui répond au doigt fait la cible
/// tactile, logée dans l'angle de la vignette.
class AppThumbnail extends StatelessWidget {
  const AppThumbnail({
    required this.fallbackIcon,
    required this.semanticLabel,
    this.image,
    this.size = defaultSize,
    this.action,
    this.busy = false,
    this.loading = false,
    this.busyLabel = 'Préparation de la photo',
    super.key,
  });

  final ImageProvider? image;
  final IconData fallbackIcon;

  /// Ce que la vignette montre, dit au lecteur d'écran (« Photo du repas »,
  /// « Pas encore de photo »).
  final String semanticLabel;
  final double size;
  final AppThumbnailAction? action;

  /// Une image se prépare (prise, redressée, réduite) : le dessin violet
  /// porte un indicateur à la place de l'icône, et le bouton attend.
  final bool busy;

  /// Une image qui EXISTE se charge (lue sur le réseau) : même indicateur,
  /// mais le bouton reste à la main — rien ne se prépare, et un réseau lent
  /// ne doit pas empêcher de changer la photo.
  final bool loading;

  /// Ce que le lecteur d'écran annonce pendant [busy] ou [loading].
  final String busyLabel;

  /// La vignette d'une carte de saisie : assez grande pour reconnaître un
  /// plat, assez petite pour laisser le nom à côté.
  static const double defaultSize = 104;

  static const double _actionDisc = 32;
  static const double _actionIcon = 18;

  @override
  Widget build(BuildContext context) {
    final photo = image;
    final waiting = busy || loading;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.violetRamp),
      child: Center(
        child: waiting
            ? SizedBox.square(
                dimension: size * 0.3,
                child: CircularProgressIndicator(
                  color: AppColors.neutral0,
                  semanticsLabel: busyLabel,
                ),
              )
            : Icon(fallbackIcon, size: size * 0.4, color: AppColors.neutral0),
      ),
    );
    final picture = Semantics(
      image: true,
      label: semanticLabel,
      child: ClipRRect(
        borderRadius: AppRadius.lgAll,
        child: SizedBox.square(
          dimension: size,
          child: photo == null || waiting
              ? fallback
              : Image(
                  image: photo,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
    final geste = action;
    if (geste == null) {
      return picture;
    }
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          picture,
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox.square(
              dimension: AppSpacing.touchTarget,
              child: IconButton(
                tooltip: geste.tooltip,
                onPressed: busy ? null : geste.onPressed,
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(alignment: Alignment.bottomRight),
                icon: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.darkSurface,
                      border: Border.fromBorderSide(
                        BorderSide(color: AppColors.primaryLightBorder),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: _actionDisc,
                      child: Icon(
                        geste.icon,
                        size: _actionIcon,
                        color: AppColors.primaryLight,
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

/// Un DISQUE violet qui porte une icône : la vignette d'une ligne de liste
/// quand il n'y a pas de photo (la famille d'un aliment).
///
/// La teinte des badges violets de l'application : fond à 12 %, filet à
/// 28 %, icône en violet clair (graphique à 3:1 au moins sur toute surface
/// sombre).
class AppIconDisc extends StatelessWidget {
  const AppIconDisc({required this.icon, this.size = defaultSize, super.key});

  final IconData icon;
  final double size;

  static const double defaultSize = 40;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.primaryBadgeBg,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.primaryBadgeBorder),
          ),
        ),
        child: Icon(icon, size: size * 0.5, color: AppColors.primaryLight),
      ),
    );
  }
}
