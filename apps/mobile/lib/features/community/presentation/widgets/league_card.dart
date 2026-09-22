import 'package:flutter/material.dart';

import '../../../../core/utilities/formatting.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/entities/league.dart';
import 'league_ladder_bar.dart';

/// LA LIGUE de la semaine : où j'en suis, qui est devant, ce qu'il reste.
///
/// Deux visages, et c'est le « périmètre CHOISI » du principe 5 :
/// sans adhésion, la carte montre l'échelle et l'invitation à entrer, jamais
/// des noms d'inconnus ; une fois entrée, elle montre le classement, avec MA
/// ligne même hors du podium — un classement où l'on ne se trouve pas ne
/// motive personne.
class LeagueCard extends StatelessWidget {
  const LeagueCard({
    required this.league,
    required this.onJoin,
    required this.onLeave,
    super.key,
  });

  final League league;
  final VoidCallback onJoin;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(league: league),
          const SizedBox(height: AppSpacing.sm),
          LeagueLadderBar(division: league.division),
          const SizedBox(height: AppSpacing.sm),
          if (league.joined) ..._joined(context) else ..._invitation(),
        ],
      ),
    );
  }

  List<Widget> _joined(BuildContext context) {
    final moi = league.me;
    final podium = league.standings.take(3).toList(growable: false);

    return [
      if (league.lastResult != null) ...[
        _LastResultBanner(result: league.lastResult!),
        const SizedBox(height: AppSpacing.sm),
      ],
      Text(
        '${formatThousands(league.score)} points cette semaine',
        style: AppTypography.subheading.copyWith(
          color: AppColors.darkTextPrimary,
        ),
      ),
      // Ce qui fait un point, dit une fois : un score sans sa règle n'est
      // qu'un chiffre, et la règle disparaissait avec la carte d'invitation.
      Text(
        '50 points la séance, 1 la minute d’effort, 1 les cent mètres.',
        style: AppTypography.label.copyWith(color: AppColors.darkTextTertiary),
      ),
      const SizedBox(height: AppSpacing.xs),
      if (podium.isEmpty)
        Text(
          'Personne n’a encore marqué. Une séance suffit à ouvrir le bal.',
          style: AppTypography.label.copyWith(
            color: AppColors.darkTextSecondary,
          ),
        )
      else ...[
        for (final ligne in podium) _StandingRow(standing: ligne),
        // Ma ligne, même hors du podium.
        if (moi != null && moi.rank > podium.length)
          _StandingRow(standing: moi),
      ],
      const SizedBox(height: AppSpacing.sm),
      Align(
        alignment: Alignment.centerRight,
        child: AppButton(
          label: 'Quitter la ligue',
          variant: AppButtonVariant.secondary,
          size: AppButtonSize.small,
          onPressed: onLeave,
        ),
      ),
    ];
  }

  List<Widget> _invitation() {
    return [
      Text(
        'Une semaine, vingt personnes, et ça repart à zéro.',
        style: AppTypography.subheading.copyWith(
          color: AppColors.darkTextPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        'Tes séances, tes minutes d’effort et tes kilomètres deviennent des '
        'points. Rien n’est compté tant que tu n’es pas entrée, et ton rang '
        'ne touche jamais à ton titre Carlys.',
        style: AppTypography.label.copyWith(color: AppColors.darkTextSecondary),
      ),
      const SizedBox(height: AppSpacing.sm),
      AppButton(
        label: 'Rejoindre la ligue',
        isExpanded: true,
        onPressed: onJoin,
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.league});

  final League league;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          AppIcons.leagueOutline,
          size: 18,
          color: AppColors.primaryLight,
        ),
        const SizedBox(width: AppSpacing.xs),
        // Le nom de la division SEUL : l'en-tête de section dit déjà
        // « Ligue », et « Ligue / Ligue Or » bégayait à l'écran.
        AppSectionLabel(league.division.label),
        const Spacer(),
        // Pas de compte à rebours tant qu'on n'a pas rejoint : il compterait
        // une semaine qu'on ne joue pas. La division, elle, reste affichée —
        // c'est celle où l'on ENTRERAIT, et l'échelle en dessous le dit.
        if (league.joined)
          Text(
            league.daysLeft <= 0 ? 'dernier jour' : 'J−${league.daysLeft}',
            style: AppTypography.labelMono.copyWith(
              color: AppColors.darkTextTertiary,
            ),
          ),
      ],
    );
  }
}

/// Le résultat de la semaine passée, annoncé UNE fois.
class _LastResultBanner extends StatelessWidget {
  const _LastResultBanner({required this.result});

  final LeagueResult result;

  @override
  Widget build(BuildContext context) {
    final (icone, phrase) = switch (result) {
      final r when r.isPromotion => (
        AppIcons.trendingUp,
        '${r.rank}e la semaine passée : te voilà en ${r.to.label}.',
      ),
      final r when r.isRelegation => (
        AppIcons.trendingDown,
        '${r.rank}e la semaine passée : retour en ${r.to.label}.',
      ),
      final r => (
        AppIcons.trendingFlat,
        '${r.rank}e la semaine passée : tu restes en ${r.to.label}.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.primaryBadgeBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryBadgeBorder),
      ),
      child: Row(
        children: [
          Icon(icone, size: 16, color: AppColors.primaryLight),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              phrase,
              style: AppTypography.label.copyWith(
                color: AppColors.darkTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing});

  final LeagueStanding standing;

  @override
  Widget build(BuildContext context) {
    final couleur = standing.isMe
        ? AppColors.primaryLight
        : AppColors.darkTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${standing.rank}',
              style: AppTypography.labelMono.copyWith(color: couleur),
            ),
          ),
          Expanded(
            child: Text(
              standing.isMe ? 'Toi' : standing.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body.copyWith(color: couleur),
            ),
          ),
          Text(
            '${formatThousands(standing.score)} pts',
            style: AppTypography.label.copyWith(color: couleur),
          ),
        ],
      ),
    );
  }
}
