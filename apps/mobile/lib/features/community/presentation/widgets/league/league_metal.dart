import 'package:flutter/material.dart';

import '../../../../../design_system/design_system.dart';
import '../../../domain/entities/league.dart';

/// LE MÉTAL d'une division : trois tons, du reflet à l'ombre.
///
/// Ces teintes sont RÉSERVÉES aux ligues — le blason de division et les
/// couronnes du podium — par arbitrage produit du 23 septembre 2026. Partout
/// ailleurs, l'application se peint en violet : voir `color.league` dans
/// `packages/design-tokens/src/tokens.json`.
class LeagueMetal {
  const LeagueMetal(this.light, this.base, this.dark);

  final Color light;
  final Color base;
  final Color dark;

  /// Le dégradé d'une face éclairée par le haut.
  LinearGradient get face => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [light, base, dark],
    stops: const [0, 0.45, 1],
  );

  /// Le métal de [division].
  static LeagueMetal of(LeagueDivision division) => switch (division) {
    LeagueDivision.bronze => bronze,
    LeagueDivision.argent => silver,
    LeagueDivision.or => gold,
    LeagueDivision.platine => const LeagueMetal(
      AppColors.leaguePlatinumLight,
      AppColors.leaguePlatinum,
      AppColors.leaguePlatinumDark,
    ),
    LeagueDivision.diamant => const LeagueMetal(
      AppColors.leagueDiamondLight,
      AppColors.leagueDiamond,
      AppColors.leagueDiamondDark,
    ),
  };

  /// Les trois métaux du PODIUM, dans l'ordre des places : or, argent,
  /// bronze — la convention de tout podium, quelle que soit la division.
  static const LeagueMetal gold = LeagueMetal(
    AppColors.leagueGoldLight,
    AppColors.leagueGold,
    AppColors.leagueGoldDark,
  );
  static const LeagueMetal silver = LeagueMetal(
    AppColors.leagueSilverLight,
    AppColors.leagueSilver,
    AppColors.leagueSilverDark,
  );
  static const LeagueMetal bronze = LeagueMetal(
    AppColors.leagueBronzeLight,
    AppColors.leagueBronze,
    AppColors.leagueBronzeDark,
  );

  /// Le métal de la couronne d'un rang, ou `null` hors du podium.
  static LeagueMetal? ofPodiumRank(int rank) => switch (rank) {
    1 => gold,
    2 => silver,
    3 => bronze,
    _ => null,
  };
}
