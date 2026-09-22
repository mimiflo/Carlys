import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';
import '../motion/app_motion.dart';
import '../typography/app_typography.dart';
import 'app_translucent_bar.dart';

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
/// Réorganisation d'août 2026 : des destinations qui sont chacune un VERBE
/// du parcours — arriver (Accueil), s'entraîner (Training), mesurer
/// (Progrès), comprendre (Academy), s'encourager (Communauté). L'exercice et
/// le coach vivent DANS ces destinations ; le profil s'ouvre depuis l'avatar
/// de l'accueil.
///
/// SE NOURRIR rejoint la liste en septembre 2026, entre s'entraîner et
/// mesurer. Ce n'est pas un retour sur la décision d'août, qui portait sur
/// le COACH — lui reste dans le hub Training, là où il a un sens. La
/// nutrition, elle, était rangée sous Academy : un pilier quotidien caché
/// derrière « comprendre », alors que manger se décide trois fois par jour.
const List<AppBottomBarItem> appBottomBarItems = [
  AppBottomBarItem(
    icon: Icons.home_outlined,
    activeIcon: AppIcons.home,
    label: 'Accueil',
  ),
  AppBottomBarItem(
    icon: Icons.fitness_center_outlined,
    activeIcon: AppIcons.workout,
    label: 'Training',
  ),
  AppBottomBarItem(
    icon: Icons.restaurant_outlined,
    activeIcon: AppIcons.nutrition,
    label: 'Nutrition',
  ),
  AppBottomBarItem(
    icon: Icons.insights_outlined,
    activeIcon: AppIcons.progress,
    label: 'Progrès',
  ),
  AppBottomBarItem(
    icon: Icons.school_outlined,
    activeIcon: Icons.school_rounded,
    label: 'Academy',
  ),
  AppBottomBarItem(
    icon: Icons.group_outlined,
    activeIcon: Icons.group_rounded,
    label: 'Communauté',
  ),
];

/// Bottom bar de la refonte : hauteur 84 + safe area, fond assombri +
/// blur 20, bordure haute 1px. Actif en accent (icône remplie), inactif
/// en `iconInactive`, transition [AppMotion.tab].
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

    return AppTranslucentBar(
      // Fond plus dense que celui des barres d'action : la navigation reste
      // lisible au-dessus de n'importe quel écran, y compris une photo.
      color: _background,
      child: SizedBox(
        height: height + bottomInset,
        child: Padding(
          // Le `top` n'est pas une marge choisie : c'est l'épaisseur du trait
          // du haut. `Container` la posait TOUT SEUL — il ajoute
          // `decoration.padding`, c'est-à-dire les dimensions de la bordure,
          // autour de son enfant. `DecoratedBox`, lui, ne le fait pas : en
          // passant de l'un à l'autre, les six onglets remontaient d'un
          // pixel logique. Mesuré, pas deviné — 0,24 % de pixels différents
          // sur les vingt-trois captures qui portent cette barre.
          padding: EdgeInsets.only(
            top: AppTranslucentBar.borderWidth,
            bottom: bottomInset,
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
    final duration = AppMotion.resolve(context, AppMotion.tab);

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
