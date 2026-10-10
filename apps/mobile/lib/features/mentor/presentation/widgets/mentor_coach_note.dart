import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// La note qui rappelle que la voix du Mentor teinte aussi le Coach IA :
/// une précision, pas une alerte.
class MentorCoachNote extends StatelessWidget {
  const MentorCoachNote({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(AppIcons.info, size: 20, color: AppColors.primaryLight),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
