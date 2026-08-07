import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../typography/app_typography.dart';

/// Label mono MAJUSCULES qui introduit une section (« MÉTABOLISME »,
/// « SÉANCE DU JOUR ») — en primaryLight par convention, tertiaire quand
/// il légende une valeur.
class AppSectionLabel extends StatelessWidget {
  const AppSectionLabel(
    this.text, {
    this.color = AppColors.primaryLight,
    super.key,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelMono.copyWith(color: color),
    );
  }
}
