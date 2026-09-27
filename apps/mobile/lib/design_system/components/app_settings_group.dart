import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';
import 'app_whole_words_text.dart';

/// Groupe de réglages de la maquette : libellé mono au-dessus, puis une carte
/// unique dont les lignes sont séparées par un filet aligné sur le texte.
class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({required this.label, required this.rows, super.key});

  /// Libellé de section (« ENTRAÎNEMENT »), rendu en mono MAJUSCULES.
  final String label;
  final List<AppSettingsRow> rows;

  /// Retrait du filet : largeur de l'icône + gouttière, pour qu'il démarre
  /// sous le libellé et non sous l'icône.
  static const double dividerInset = 51;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.resized(
            AppTypography.labelMono,
            10,
          ).copyWith(color: AppColors.darkTextTertiary),
        ),
        const SizedBox(height: AppSpacing.gapTile),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.darkBorder),
            ),
          ),
          child: ClipRRect(
            borderRadius: AppRadius.cardSecondaryAll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < rows.length; index++) ...[
                  if (index > 0)
                    const Padding(
                      padding: EdgeInsets.only(left: dividerInset),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.rowDivider,
                      ),
                    ),
                  rows[index],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Ligne de réglage : icône 21 primaryLight, libellé 14, puis valeur et
/// chevron — ou un interrupteur quand la ligne est un basculement.
class AppSettingsRow extends StatelessWidget {
  const AppSettingsRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueIsMono = false,
    this.onTap,
    this.toggleValue,
    this.onToggle,
    this.destructive = false,
    super.key,
  });

  final IconData icon;
  final String label;

  /// Valeur affichée à droite, avant le chevron.
  final String? value;

  /// Vrai pour les valeurs chiffrées (« 2:00 »), rendues en mono.
  final bool valueIsMono;
  final VoidCallback? onTap;

  /// Non nul quand la ligne porte un interrupteur au lieu d'un chevron.
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;

  /// Ligne d'action risquée (déconnexion) — libellé et icône en rouge.
  final bool destructive;

  /// Au-delà de ce facteur de texte, la valeur passe SOUS le libellé : à
  /// côté, elle ne lui laissait plus que quelques lettres par ligne.
  static const double stackedValueTextScale = 1.3;

  /// Côte à côte, la part de la ligne que la valeur peut prendre au plus ;
  /// plus longue, elle passe à la ligne dans sa colonne.
  static const double _valueShare = 0.45;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? AppColors.danger
        : AppColors.darkTextPrimary;
    final isToggle = toggleValue != null;
    final stacked =
        value != null &&
        MediaQuery.textScalerOf(context).scale(1) > stackedValueTextScale;
    final valueStyle =
        (valueIsMono
                ? AppTypography.resized(AppTypography.labelMono, 12)
                : AppTypography.body.copyWith(fontSize: 12))
            .copyWith(color: AppColors.darkTextTertiary);

    Widget toggle() {
      final bascule = Switch.adaptive(
        value: toggleValue!,
        onChanged: onToggle,
        activeThumbColor: AppColors.darkBackground,
        activeTrackColor: AppColors.accent,
      );
      // Quand la ligne a son propre geste, la bascule est un nœud à part :
      // elle y reçoit le nom de la ligne, sans quoi elle s'annonçait
      // « commutateur, activé » sans dire de quoi.
      return onTap == null ? bascule : Semantics(label: label, child: bascule);
    }

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: destructive ? AppColors.danger : AppColors.primaryLight,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppWholeWordsText(
                    label,
                    style: AppTypography.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                  if (stacked) Text(value!, style: valueStyle),
                ],
              ),
            ),
            if (value != null && !stacked) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * _valueShare,
                ),
                child: Text(
                  value!,
                  textAlign: TextAlign.end,
                  style: valueStyle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (isToggle)
              toggle()
            else if (!destructive)
              const Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: AppColors.darkIconInactive,
              ),
          ],
        ),
      ),
    );

    // Chaque ligne est une FRONTIÈRE : son libellé, sa valeur et sa bascule
    // ne se fondent jamais dans les lignes voisines.
    if (onTap == null) {
      return Semantics(
        container: true,
        // Sans geste propre, la ligne entière EST l'interrupteur : un nœud,
        // son libellé, son état.
        child: isToggle ? MergeSemantics(child: content) : content,
      );
    }
    return Semantics(
      container: true,
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
