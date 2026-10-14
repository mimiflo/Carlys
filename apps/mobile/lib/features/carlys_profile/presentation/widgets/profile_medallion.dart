import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import 'carlys_profile_content.dart';

/// Le médaillon d'un profil (maquette d'octobre 2026) : le disque violet et
/// son pictogramme, tirés des maquettes (`assets/profiles/medaillon_*.webp`,
/// canal alpha : le Stratège laisse déborder sa carte du cercle).
///
/// Décoratif pour un lecteur d'écran : le nom du profil est toujours écrit
/// à côté. Si le fichier manque, un disque de marque et l'icône du profil
/// le remplacent — jamais un trou.
class ProfileMedallion extends StatelessWidget {
  const ProfileMedallion({required this.content, this.size = 76, super.key});

  final CarlysProfileContent content;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          content.assetPath,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceIcon,
            ),
            child: Icon(
              content.icon,
              size: size * 0.45,
              color: AppColors.primaryLight,
            ),
          ),
        ),
      ),
    );
  }
}
