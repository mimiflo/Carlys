import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../typography/app_typography.dart';

/// Ton d'une pastille de la refonte.
///
/// `accentSolid` est l'orange en aplat (texte sombre) : réservé au filtre actif
/// de la bibliothèque, seul usage plein du orange sur cet écran.
enum AppPillTone { neutral, accent, accentSolid, primary }

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
      return pill;
    }
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: pill,
        ),
      ),
    );
  }
}
