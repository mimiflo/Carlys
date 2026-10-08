import 'package:flutter/material.dart';

import '../colors/app_colors.dart';
import '../icons/app_icons.dart';

/// Le métal d'une [AppMedal] : ceux des ligues, du plus commun au plus rare.
enum AppMedalMetal {
  bronze(
    AppColors.leagueBronzeLight,
    AppColors.leagueBronze,
    AppColors.leagueBronzeDark,
  ),
  silver(
    AppColors.leagueSilverLight,
    AppColors.leagueSilver,
    AppColors.leagueSilverDark,
  ),
  gold(
    AppColors.leagueGoldLight,
    AppColors.leagueGold,
    AppColors.leagueGoldDark,
  ),
  platinum(
    AppColors.leaguePlatinumLight,
    AppColors.leaguePlatinum,
    AppColors.leaguePlatinumDark,
  );

  const AppMedalMetal(this.light, this.base, this.dark);

  final Color light;
  final Color base;

  /// La couleur du ruban gravé sur le disque.
  final Color dark;
}

/// Une médaille ronde (maquettes Progrès et Academy d'octobre 2026) : un
/// disque de métal et sa médaille gravée ; sans métal, un disque éteint et
/// un cadenas — ce qui reste à gagner se voit, sans ressembler à un échec.
///
/// Purement décorative : c'est la ligne qui la porte qui dit ce qu'elle vaut
/// au lecteur d'écran.
class AppMedal extends StatelessWidget {
  const AppMedal({required this.metal, this.size = 40, super.key});

  /// `null` : pas encore gagnée.
  final AppMedalMetal? metal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final metal = this.metal;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: metal == null ? AppColors.darkSurfaceAlt : null,
          gradient: metal == null
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [metal.light, metal.base, metal.dark],
                ),
          border: Border.all(
            color: metal == null ? AppColors.darkBorder : metal.light,
          ),
        ),
        child: Icon(
          metal == null ? AppIcons.lock : AppIcons.rank,
          size: size * (metal == null ? 0.42 : 0.6),
          color: metal == null ? AppColors.darkTextTertiary : metal.dark,
        ),
      ),
    );
  }
}
