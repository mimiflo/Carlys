import 'dart:ui';

import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../motion/app_motion.dart';
import '../typography/app_typography.dart';

/// Un onglet de la bottom bar : icône outline/remplie + libellé.
class AppBottomBarItem {
  const AppBottomBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Les 6 onglets de l'application.
///
/// La maquette en montrait cinq (home, exercices, insights, nutrition,
/// profil) ; le coach s'est ajouté au **centre** de la barre — c'est la
/// position la plus atteignable au pouce, et la fonctionnalité qu'on veut
/// voir. Écart assumé, consigné dans `docs/product/design-conformity.md`.
const List<AppBottomBarItem> appBottomBarItems = [
  AppBottomBarItem(
    icon: Icons.home_outlined,
    activeIcon: AppIcons.home,
    label: 'Accueil',
  ),
  AppBottomBarItem(
    icon: Icons.fitness_center_outlined,
    activeIcon: AppIcons.workout,
    label: 'Exercices',
  ),
  AppBottomBarItem(
    icon: AppIcons.coachOutline,
    activeIcon: AppIcons.coach,
    label: 'Coach',
  ),
  AppBottomBarItem(
    icon: Icons.insights_outlined,
    activeIcon: AppIcons.progress,
    label: 'Progrès',
  ),
  AppBottomBarItem(
    icon: Icons.restaurant_outlined,
    activeIcon: AppIcons.nutrition,
    label: 'Nutrition',
  ),
  AppBottomBarItem(
    icon: Icons.person_outline_rounded,
    activeIcon: AppIcons.profile,
    label: 'Profil',
  ),
];

/// Bottom bar de la refonte : hauteur 84 + safe area, fond assombri +
/// blur 20, bordure haute 1px. Actif en accent (icône remplie), inactif
/// en `iconInactive`, transition 180 ms.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const double height = 84;
  static const Color _background = Color(0xDB08080E); // rgba(8,8,14,.86)

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: height + bottomInset,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: _background,
            border: Border(top: BorderSide(color: AppColors.darkBorder)),
          ),
          child: Row(
            children: [
              for (final (index, item) in appBottomBarItems.indexed)
                Expanded(
                  child: _BarItem(
                    item: item,
                    active: index == currentIndex,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final AppBottomBarItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.accent : AppColors.darkIconInactive;
    final duration =
        AppMotion.resolve(context, const Duration(milliseconds: 180));

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: duration,
                child: Icon(
                  active ? item.activeIcon : item.icon,
                  key: ValueKey(active),
                  size: 23,
                  color: color,
                ),
              ),
              const SizedBox(height: 7),
              AnimatedDefaultTextStyle(
                duration: duration,
                style: (active ? AppTypography.tabActive : AppTypography.tab)
                    .copyWith(color: color),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
