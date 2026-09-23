import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Ton d'une pastille de la refonte.
///
/// `accentSolid` est l'orange en aplat (texte sombre) : réservé au filtre actif
/// de la bibliothèque, seul usage plein du orange sur cet écran.
///
/// `success` est le vert sémantique d'un état ACQUIS (un ami dans le défi) :
/// jamais une couleur d'ambiance.
enum AppPillTone { neutral, accent, accentSolid, primary, success }

/// Pastille stadium : durée, groupe musculaire, filtre…
/// Accent = fond orange .12 + bordure .28 ; neutre = blanc .07.
class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    this.tone = AppPillTone.neutral,
    this.mono = false,
    this.onTap,
    this.selected = false,
    this.icon,
    this.selectedTone = AppPillTone.accent,
    super.key,
  });

  final String label;
  final AppPillTone tone;

  /// Icône optionnelle devant le libellé (ex. tendance « ↗ +18 % »).
  final IconData? icon;

  /// Ton appliqué quand la pastille est sélectionnée.
  final AppPillTone selectedTone;

  /// Vrai pour les valeurs chiffrées (« 52 MIN ») — rendu mono MAJUSCULES.
  final bool mono;

  /// Pastille-filtre interactive.
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final effectiveTone = selected ? selectedTone : tone;
    final (background, borderColor, textColor) = switch (effectiveTone) {
      AppPillTone.accent => (
        AppColors.accentBadgeBg,
        AppColors.accentBadgeBorder,
        AppColors.accent,
      ),
      AppPillTone.accentSolid => (
        AppColors.accent,
        Colors.transparent,
        AppColors.darkBackground,
      ),
      AppPillTone.primary => (
        AppColors.primaryCardSoft,
        AppColors.primaryLightBorder,
        AppColors.primaryLight,
      ),
      AppPillTone.success => (
        AppColors.successBadgeBg,
        AppColors.successBadgeBorder,
        AppColors.success,
      ),
      AppPillTone.neutral => (
        AppColors.neutralBadgeBg,
        Colors.transparent,
        AppColors.neutralBadgeText,
      ),
    };

    final style = mono
        ? AppTypography.labelMono.copyWith(color: textColor)
        : AppTypography.label.copyWith(fontSize: 11, color: textColor);

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(mono ? label.toUpperCase() : label, style: style),
        ],
      ),
    );

    if (onTap == null) {
      // Pastille décorative : rien ne se presse, aucune cible tactile à
      // ménager. Elle garde sa hauteur d'ornement.
      return pill;
    }
    // CIBLE TACTILE : l'ornement reste à 32, la zone qui répond au doigt
    // s'élargit AUTOUR de lui jusqu'à AppSpacing.touchTarget.
    //
    // La `ConstrainedBox(minHeight: 32)` d'avant était à la fois la boîte
    // peinte ET la boîte sensible : 32 dp, soit une constante rivale du seul
    // repère de cible tactile de l'application, que sept écrans franchissent
    // — filtres de progression, amorces du coach, séries prévues, leçons,
    // domaines d'académie, onglets de recettes. Un `GestureDetector` n'a, lui,
    // aucun rembourrage automatique, contrairement à un `IconButton`.
    //
    // `Center` garde la pastille à sa taille et la pose au milieu des 48 ;
    // `HitTestBehavior.opaque` fait répondre toute la boîte, y compris les
    // huit dixièmes transparents au-dessus et au-dessous.
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: AppSpacing.touchTarget,
          // `widthFactor: 1` : la boîte ne prend QUE la largeur de la
          // pastille. Sans lui, un Center placé dans une largeur bornée
          // (une cellule d'`Expanded`, par exemple) s'étalerait et
          // recentrerait la pastille — un changement visuel là où on ne
          // voulait toucher qu'à la hauteur sensible.
          child: Center(
            widthFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 32),
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}
