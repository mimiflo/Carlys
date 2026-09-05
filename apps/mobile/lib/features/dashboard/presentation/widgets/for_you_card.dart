import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/design_system.dart';
import '../../../carlys_profile/domain/entities/carlys_profile.dart';
import '../../../carlys_profile/presentation/widgets/carlys_profile_content.dart';
import '../../../community/domain/entities/community.dart';

/// POUR TOI : ce que Carlys a retenu, sans qu'on le lui demande.
///
/// Le cap de l'identité choisie et le mot reçu de la communauté vivaient
/// dans deux cartes séparées, chacune de la taille d'une section. Ce sont
/// deux MESSAGES, pas deux rubriques : ils tiennent en deux lignes d'une
/// même surface, et l'accueil y gagne une section entière.
///
/// La carte n'existe que s'il y a quelque chose à dire : ni cap choisi ni
/// mot reçu, et la section disparaît — jamais une surface vide.
class ForYouCard extends StatelessWidget {
  const ForYouCard({required this.entries, super.key});

  final List<ForYouEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(AppRadius.listRow),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          children: [
            for (final (index, entry) in entries.indexed) ...[
              if (index > 0)
                const Divider(height: 1, color: AppColors.gridRule),
              _Row(entry: entry),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ligne de la carte : de quoi ça parle, ce que ça dit, où ça mène.
class ForYouEntry {
  const ForYouEntry({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.label,
    required this.message,
    required this.onOpen,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;

  /// Libellé mono, mis en capitales à l'affichage.
  final String label;

  /// Le message, en une phrase.
  final String message;

  final VoidCallback onOpen;

  /// Le cap de l'identité Carlys choisie.
  static ForYouEntry focus(BuildContext context, CarlysProfile profile) {
    final content = carlysProfileContentOf(profile);
    final focus = _focusOf(profile);
    return ForYouEntry(
      icon: AppIcons.foundation,
      iconColor: AppColors.accent,
      iconSize: 22,
      label: 'Ton cap ${content.title}',
      message: focus.message,
      onOpen: () => focus.open(context),
    );
  }

  /// Le dernier mot reçu de la communauté.
  static ForYouEntry encouragement(
    BuildContext context,
    Encouragement received,
  ) {
    return ForYouEntry(
      icon: Icons.favorite_rounded,
      iconColor: AppColors.affection,
      iconSize: 20,
      label: '${received.fromName} t’encourage',
      message: received.message,
      onOpen: () => context.go(AppRoutes.community),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final ForYouEntry entry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${entry.label} : ${entry.message}',
      onTap: entry.onOpen,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: entry.onOpen,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(entry.icon, size: entry.iconSize, color: entry.iconColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.label.toUpperCase(),
                        style: AppTypography.labelMono.copyWith(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs - 1),
                      Text(
                        entry.message,
                        style: AppTypography.body.copyWith(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    AppIcons.chevronRight,
                    size: 18,
                    color: AppColors.textMuted,
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

/// Le cap et sa destination — propres à l'accueil, donc définis ici et pas
/// dans le contenu éditorial des profils, qui ignore la navigation.
class _ProfileFocus {
  const _ProfileFocus({required this.message, required this.open});

  /// Une phrase : ce qu'on vise, puis pourquoi c'est celle-là.
  final String message;

  /// `go` vers une branche de la barre d'onglets, `push` vers un plein écran.
  final void Function(BuildContext context) open;
}

_ProfileFocus _focusOf(CarlysProfile profile) {
  return switch (profile) {
    CarlysProfile.constructeur => _ProfileFocus(
      message:
          'Pose tes fondations — l’Académie t’explique les mouvements '
          'et les bases.',
      open: (context) => context.go(AppRoutes.academy),
    ),
    CarlysProfile.challenger => _ProfileFocus(
      message:
          'Va chercher un défi — la communauté en lance à ta hauteur '
          'cette semaine.',
      open: (context) => context.go(AppRoutes.community),
    ),
    CarlysProfile.athlete => _ProfileFocus(
      message:
          'Tiens ton plan — un programme sur plusieurs semaines change '
          'la discipline en résultats.',
      open: (context) => context.push(AppRoutes.programs),
    ),
    CarlysProfile.stratege => _ProfileFocus(
      message:
          'Comprends tes chiffres — records et tendances disent ce que '
          'ton corps répond.',
      open: (context) => context.go(AppRoutes.progress),
    ),
  };
}
