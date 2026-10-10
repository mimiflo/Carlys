import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';

/// L'en-tête des feuilles du Mentor (maquette d'octobre 2026) : le titre
/// centré, sa ligne mono, et la croix qui ferme.
class MentorSheetHeader extends StatelessWidget {
  const MentorSheetHeader({
    required this.title,
    required this.tagline,
    super.key,
  });

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return AppScreenHeader.centered(
      title: title,
      tagline: tagline,
      showBack: false,
      actions: [
        AppRoundIconButton(
          icon: AppIcons.close,
          tooltip: 'Fermer',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
