import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// Surface commune des propositions du coach (séance, programme) : on ne
/// doit pas réapprendre ce qu'est une proposition en passant de l'une à
/// l'autre. Alignée à gauche, du côté de celui qui propose.
class CoachCardFrame extends StatelessWidget {
  const CoachCardFrame({
    required this.maxWidth,
    required this.children,
    super.key,
  });

  final double maxWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.darkSurfaceAlt,
            borderRadius: AppRadius.cardSecondaryAll,
            border: Border.fromBorderSide(
              BorderSide(color: AppColors.darkBorderStrong),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// « SÉANCE ADAPTÉE », « PROGRAMME PROPOSÉ » : le sur-titre d'une carte.
class CoachCardHeader extends StatelessWidget {
  const CoachCardHeader({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  static const double _iconSize = 14;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: _iconSize, color: AppColors.primaryLight),
        const SizedBox(width: AppSpacing.xxs + 2),
        Text(
          label,
          style: AppTypography.labelMono.copyWith(
            color: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }
}
