import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'carlys_profile_content.dart';

/// L'illustration ENTIÈRE dans une case plus étroite qu'elle : l'image en
/// `contain`, posée sur elle-même agrandie et floutée pour que la case reste
/// pleine. Un `cover` seul rognait un tiers de la largeur du dessin (le
/// marteau du Constructeur, les pièces du Stratège sortaient du cadre).
class ProfileIllustration extends StatelessWidget {
  const ProfileIllustration({required this.content, super.key});

  final CarlysProfileContent content;

  /// Largeur de la case d'illustration : c'est aussi la largeur LOGIQUE à
  /// laquelle l'image se décode, quel que soit l'appelant (l'onboarding pose
  /// les mêmes cartes dans la même case).
  static const double imageWidth = 116;

  /// Flou du fond de case : on doit y lire une matière, plus une image.
  static const double _backdropSigma = 8;

  /// Largeur de DÉCODAGE : la case à la densité de l'écran, jamais la taille
  /// du fichier (800 × 598). Sur un écran ×3, 348 pixels de large suffisent,
  /// soit cinq fois moins de mémoire par carte — et l'écran en pose quatre.
  static int decodeWidthOf(BuildContext context) =>
      (imageWidth * MediaQuery.devicePixelRatioOf(context)).round();

  @override
  Widget build(BuildContext context) {
    // Le fond flouté et le premier plan partagent le même décodage.
    final decodeWidth = decodeWidthOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: _backdropSigma,
            sigmaY: _backdropSigma,
          ),
          child: Image.asset(
            content.assetPath,
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            // Le fond n'a pas de repli propre : celui du premier plan suffit.
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
        Image.asset(
          content.assetPath,
          fit: BoxFit.contain,
          cacheWidth: decodeWidth,
          // L'illustration manque : repli de marque, jamais un trou ni une
          // icône d'erreur.
          errorBuilder: (_, __, ___) => _Placeholder(icon: content.icon),
        ),
      ],
    );
  }
}

/// Repli d'illustration : dégradé de marque + icône du profil.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.neutral950],
        ),
      ),
      child: Icon(icon, size: 40, color: AppColors.primaryLight),
    );
  }
}
