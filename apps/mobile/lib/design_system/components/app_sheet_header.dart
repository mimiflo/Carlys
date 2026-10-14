import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import 'app_round_icon_button.dart';
import 'app_screen_header.dart';

/// L'en-tête d'une feuille (maquettes d'octobre 2026 : Mentor, profils) :
/// le titre centré, sa ligne mono, et la croix qui ferme.
class AppSheetHeader extends StatelessWidget {
  const AppSheetHeader({required this.title, required this.tagline, super.key});

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
