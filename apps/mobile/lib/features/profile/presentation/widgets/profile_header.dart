import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../authentication/domain/entities/auth_user.dart';

/// En-tête du profil : avatar dégradé violet, nom, puis identité mono.
///
/// La maquette affiche « MEMBRE DEPUIS MARS 2025 » : l'API d'authentification
/// ne renvoie pas la date de création du compte, la ligne porte donc l'adresse
/// e-mail — la seule identité réellement disponible. Le crayon d'édition est
/// absent pour la même raison : aucune édition de profil n'existe côté domaine.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({required this.user, super.key});

  final AuthUser? user;

  static const double _avatarSize = 66;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '';
    final email = user?.email ?? '';

    return Row(
      children: [
        Semantics(
          label: name.isEmpty ? 'Profil' : 'Profil de $name',
          child: Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardSecondaryAll,
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
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: AppTypography.title.copyWith(
                  fontSize: 24,
                  letterSpacing: 0,
                  color: AppColors.neutral0,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name.isEmpty ? 'Profil' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.title.copyWith(
                  fontSize: 21,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs + 2),
                Text(
                  email.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMono.copyWith(
                    fontSize: 12,
                    color: AppColors.darkTextTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
