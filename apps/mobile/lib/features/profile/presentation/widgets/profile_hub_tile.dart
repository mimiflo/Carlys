import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// La teinte d'un disque d'icône du profil.
///
/// Violet partout, sauf là où la maquette pose une autre lumière : le
/// lavande des gens (amis), la braise des récompenses. Aucune troisième
/// couleur : la règle de marque reste « violet d'abord ».
enum ProfileTileTone {
  violet(AppColors.primary, AppColors.primaryBadgeBg),
  lavender(AppColors.primaryLight, AppColors.primaryBadgeBg),
  ember(AppColors.accent, AppColors.accentBadgeBg);

  const ProfileTileTone(this.icon, this.disc);

  final Color icon;
  final Color disc;
}

/// Le disque d'icône des lignes du profil.
class ProfileIconDisc extends StatelessWidget {
  const ProfileIconDisc({
    required this.icon,
    this.tone = ProfileTileTone.violet,
    super.key,
  });

  final IconData icon;
  final ProfileTileTone tone;

  static const double size = 44;
  static const double _iconSize = 24;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.disc, shape: BoxShape.circle),
      child: Icon(icon, size: _iconSize, color: tone.icon),
    );
  }
}

/// Une surface du profil : fond de carte, filet, coins arrondis.
///
/// Plusieurs [children] s'empilent séparés d'un filet pleine largeur — la
/// carte « Mes badges / Mes amis » de la maquette. Un seul enfant, c'est une
/// carte simple.
class ProfileHubCard extends StatelessWidget {
  const ProfileHubCard({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: AppColors.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.rowDivider,
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Une ligne du profil : disque, titre, une ou deux lignes, chevron.
///
/// [below] prend toute la largeur sous le texte, chevron compris — la jauge
/// de l'objectif. Le chevron remonte alors à hauteur du titre, comme sur la
/// maquette ; sans [below], il reste centré.
class ProfileHubTile extends StatelessWidget {
  const ProfileHubTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.detail,
    this.tone = ProfileTileTone.violet,
    this.below,
    this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Seconde ligne grise : le rythme d'un programme.
  final String? detail;
  final ProfileTileTone tone;
  final Widget? below;
  final VoidCallback onTap;

  /// Ce que le lecteur d'écran annonce, quand le texte visible ne suffit
  /// pas (une jauge n'a pas de texte).
  final String? semanticLabel;

  static const double _chevronSize = 24;

  @override
  Widget build(BuildContext context) {
    final secondary = AppTypography.body.copyWith(
      color: AppColors.darkTextSecondary,
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.subheading.copyWith(
            color: AppColors.darkTextPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(subtitle!, style: secondary),
        ],
        if (detail != null) Text(detail!, style: secondary),
      ],
    );

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              ProfileIconDisc(icon: icon, tone: tone),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: below == null
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Expanded(child: texts),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          AppIcons.chevronRight,
                          size: _chevronSize,
                          color: AppColors.darkTextSecondary,
                        ),
                      ],
                    ),
                    ?below,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
