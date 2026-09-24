import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../shadows/app_shadows.dart';
import '../spacing/app_spacing.dart';
import '../theme/app_dark_theme.dart';
import '../typography/app_typography.dart';
import 'app_button.dart';

/// Le ton d'une popup. Il ne change QUE le médaillon : la carte, le liseré
/// et les boutons restent ceux de l'application.
enum AppPopupTone {
  /// Le violet de l'application ([AppColors.cta]) : une information, un
  /// succès, une question posée avant un geste.
  brand,

  /// Le rouge SÉMANTIQUE [AppColors.danger] : un geste qui n'a pas abouti.
  ///
  /// Un sémantique n'est pas un accent. Une confirmation de suppression
  /// reste [brand] : c'est une question, pas une erreur, et c'est son
  /// bouton (`AppButtonVariant.destructive`) qui dit le danger.
  danger,
}

/// LA carte des popups Carlys : messages passagers (`AppNotices`),
/// confirmations (`showAppConfirm`), saisies (`showAppPrompt`) et toute
/// autre popup (`showAppDialog`).
///
/// Demande du propriétaire (24 septembre 2026) : « une popup qui apparaît au
/// milieu de l'écran dans le thème de l'application pour toutes les
/// popup ». D'où une seule coquille, que chaque porte réutilise :
///  - carte SOMBRE ([AppColors.darkSurface]) au liseré violet discret et au
///    halo violet qui descend du médaillon ;
///  - médaillon rond au dégradé violet [AppColors.cta], icône claire ;
///  - titre puis message centrés ; un contenu facultatif (un champ) ;
///  - boutons EMPILÉS sur toute la largeur, l'action principale d'abord.
///    Côte à côte, deux libellés ne tiennent plus à 320 points de large dès
///    que le texte est agrandi : empilés, ils ne débordent jamais.
///
/// La carte est sombre dans les DEUX thèmes, et elle impose donc le thème
/// sombre à son contenu : en thème clair, un bouton fantôme prendrait le
/// violet vif du thème clair, illisible sur cette surface.
class AppPopupCard extends StatelessWidget {
  const AppPopupCard({
    required this.icon,
    this.title,
    this.message,
    this.content,
    this.actions = const <Widget>[],
    this.tone = AppPopupTone.brand,
    super.key,
  });

  /// Le glyphe du médaillon : un nom de la famille `AppIcons.notice…`,
  /// `AppIcons.confirm…` ou `AppIcons.prompt…`.
  final IconData icon;

  final String? title;

  /// Sous le titre, en texte secondaire. SEUL (sans titre), il prend la
  /// place et la couleur du texte principal : une phrase unique n'est pas
  /// une précision, c'est le message. Vide, il n'est pas affiché.
  final String? message;

  /// Ce qui s'insère entre le texte et les boutons : un champ de saisie,
  /// une pastille de constat.
  final Widget? content;

  /// Les boutons, de l'action principale à la renonciation. Ils occupent
  /// toute la largeur de la carte.
  final List<Widget> actions;

  final AppPopupTone tone;

  /// Largeur maximale de la carte. Sur un téléphone, elle prend la largeur
  /// de l'écran moins la gouttière ; sur une tablette, elle ne s'étale pas
  /// en bandeau.
  static const double maxWidth = 400;

  /// Libellé du voile, lu par les lecteurs d'écran : le toucher ferme.
  static const String dismissLabel = 'Fermer';

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    final message = this.message;
    final content = this.content;
    final hasMessage = message != null && message.isNotEmpty;
    // Un bouton fantôme en dernier porte déjà son vide : sa zone tactile de
    // 48 pt entoure un libellé de 20. Garder la marge pleine dessous
    // doublait le blanc du bas, et la carte paraissait lestée. La marge du
    // bas s'en retire, jamais la zone tactile.
    final last = actions.isEmpty ? null : actions.last;
    final endsOnGhost =
        last is AppButton && last.variant == AppButtonVariant.ghost;

    return AppDarkTheme(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          borderRadius: AppRadius.cardMainAll,
          boxShadow: AppShadows.lg,
        ),
        child: Material(
          color: AppColors.darkSurface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardMainAll,
            side: BorderSide(color: AppColors.primaryLightBorder),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.popupHalo),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                endsOnGhost ? AppSpacing.xs : AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _Medallion(icon: icon, tone: tone),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (title != null) ...[
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    if (hasMessage) const SizedBox(height: AppSpacing.xs),
                  ],
                  if (hasMessage)
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: title == null
                          ? AppTypography.bodyLarge.copyWith(
                              color: AppColors.darkTextPrimary,
                            )
                          : AppTypography.body.copyWith(
                              color: AppColors.darkTextSecondary,
                            ),
                    ),
                  if (content != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    content,
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    for (final (index, action) in actions.indexed) ...[
                      if (index > 0) const SizedBox(height: AppSpacing.xs),
                      action,
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le médaillon du haut de la carte : un disque plein, l'icône en clair.
///
/// Décoratif pour les lecteurs d'écran : le titre et le message disent déjà
/// tout ce que le glyphe annonce.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon, required this.tone});

  final IconData icon;
  final AppPopupTone tone;

  /// Diamètre du disque, et taille du glyphe qu'il porte.
  static const double _size = 56;
  static const double _iconSize = 28;

  @override
  Widget build(BuildContext context) {
    final brand = tone == AppPopupTone.brand;
    return ExcludeSemantics(
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: brand ? AppColors.cta : null,
          color: brand ? null : AppColors.danger,
          boxShadow: brand ? AppShadows.primaryGlow : null,
        ),
        child: Icon(icon, size: _iconSize, color: AppColors.neutral0),
      ),
    );
  }
}
