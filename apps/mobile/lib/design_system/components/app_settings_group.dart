import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../radius/app_radius.dart';
import '../spacing/app_spacing.dart';
import '../typography/app_typography.dart';

/// Groupe de réglages de la maquette : libellé mono au-dessus, puis une carte
/// unique dont les lignes sont séparées par un filet aligné sur le texte.
class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({
    required this.label,
    required this.rows,
    super.key,
  });

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
          style: AppTypography.labelMono.copyWith(
            fontSize: 10,
            color: AppColors.darkTextTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.gapTile),
        DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: AppRadius.cardSecondaryAll,
            border:
                Border.fromBorderSide(BorderSide(color: AppColors.darkBorder)),
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

  @override
  Widget build(BuildContext context) {
    final foreground =
        destructive ? AppColors.logout : AppColors.darkTextPrimary;
    final isToggle = toggleValue != null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(
            icon,
            size: 21,
            color: destructive ? AppColors.logout : AppColors.primaryLight,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: AppTypography.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
          if (value != null) ...[
            Text(
              value!,
              style: (valueIsMono
                      ? AppTypography.labelMono.copyWith(fontSize: 12)
                      : AppTypography.body.copyWith(fontSize: 12))
                  .copyWith(color: AppColors.darkTextTertiary),
            ),
            const SizedBox(width: 10),
          ],
          if (isToggle)
            Switch.adaptive(
              value: toggleValue!,
              onChanged: onToggle,
              activeThumbColor: AppColors.darkBackground,
              activeTrackColor: AppColors.accent,
            )
          else if (!destructive)
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: AppColors.darkIconInactive,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
