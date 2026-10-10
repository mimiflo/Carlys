import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Une ligne du Mentor (maquette d'octobre 2026) : sa pastille, où elle
/// mène, ce qu'on y trouve, l'état en violet, puis le chevron — ou, à la
/// place du chevron, une bascule ([toggleValue]).
///
/// Sans fond : la feuille la pose seule dans une carte, la page en groupe
/// deux sous une même carte.
class MentorLinkRow extends StatelessWidget {
  const MentorLinkRow({
    required this.icon,
    required this.label,
    required this.description,
    this.value,
    this.onTap,
    this.toggleValue,
    this.onToggle,
    super.key,
  });

  final IconData icon;
  final String label;
  final String description;
  final String? value;
  final VoidCallback? onTap;
  final bool? toggleValue;
  final ValueChanged<bool>? onToggle;

  static const double _badgeSize = 48;

  @override
  Widget build(BuildContext context) {
    final toggle = toggleValue;
    final value = this.value;
    final tap = toggle == null ? onTap : () => onToggle?.call(!toggle);
    return Semantics(
      button: toggle == null,
      toggled: toggle,
      label: value == null ? '$label. $description' : '$label, $value',
      // Relais d'action : `excludeSemantics` masque celle de l'InkWell.
      onTap: tap,
      excludeSemantics: true,
      child: InkWell(
        onTap: tap,
        borderRadius: AppRadius.cardSecondaryAll,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              AppIconBadge(icon: icon, size: _badgeSize),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTypography.subheading.copyWith(
                        color: AppColors.darkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      description,
                      style: AppTypography.body.copyWith(
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: AppSpacing.xs),
                // Bornée : en grand texte, une valeur longue ne pousse pas le
                // libellé hors de l'écran, elle s'abrège.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.3,
                  ),
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      color: AppColors.primaryLight,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AppSpacing.xs),
              if (toggle != null)
                Switch.adaptive(
                  value: toggle,
                  onChanged: onToggle,
                  // Le violet du Mentor (maquette), pas l'orange des
                  // réglages généraux.
                  activeThumbColor: AppColors.neutral0,
                  activeTrackColor: AppColors.primary,
                )
              else
                const Icon(
                  AppIcons.chevronRight,
                  size: 20,
                  color: AppColors.primaryLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
