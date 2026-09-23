import { type League as LeagueContract } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { type ChallengeMetric, type Prisma } from '@prisma/client';
import { competitionRanks } from '../domain/competition-ranks';
import {
  periodKeyOf,
  periodWindow,
  pointsOf,
  promotionOutlook,
  settleDivision,
} from '../domain/league-ladder';
import { LeaguesRepository } from '../infrastructure/leagues.repository';

/**
 * LES LIGUES : un classement hebdomadaire, choisi, qui ne rend rien au profil.
 *
 * Les trois garanties du principe 5 sont portées ici et nulle part ailleurs :
 *  - **périmètre choisi** — rien n'est écrit tant que `joinsLeague` est faux,
 *    et la lecture d'un non-membre rend un classement VIDE ;
 *  - **fenêtre qui se ferme** — la période est la semaine ISO, et le score
 *    repart de zéro à chaque semaine ;
 *  - **aucun report dans le profil** — ce service n'écrit que dans
 *    `LeagueMembership`. Ni `ProgressionFacts` ni `RewardFacts` ne le lisent,
 *    et c'est la garde à relire à chaque ajout.
 *
 * Barème complet et raisons : `docs/product/community.md`, « Les ligues,
 * barème complet ».
 */
@Injectable()
export class LeaguesService {
  constructor(private readonly leagues: LeaguesRepository) {}

  /**
   * Verse l'effort d'un fait à la ligue, dans l'unité du barème.
   *
   * Appelée par la MÊME couture que les deux familles de défis, ce qui
   * garantit qu'une séance compte partout ou nulle part.
   *
   * L'incrément est tenté AVANT l'ouverture de la période : le cas courant
   * est une ligne qui existe déjà, et l'ouvrir d'abord coûterait une lecture
   * de division à chaque série enregistrée.
   */
  async contribute(
    userId: string,
    metric: ChallengeMetric,
    amount: number,
    at: Date,
    client?: Prisma.TransactionClient,
  ): Promise<void> {
    const points = pointsOf(metric, amount);
    if (points <= 0 || !(await this.leagues.hasJoined(userId, client))) {
      return;
    }
    const periodKey = periodKeyOf(at);
    if ((await this.leagues.addPoints(userId, periodKey, points, client)) > 0) {
      return;
    }
    const division = await this.leagues.divisionToOpen(userId, periodKey, client);
    await this.leagues.openPeriod(userId, periodKey, division, client);
    await this.leagues.addPoints(userId, periodKey, points, client);
  }

  /** Entrer dans la ligue, ou en sortir. Le geste EST le consentement. */
  async setJoined(userId: string, joined: boolean): Promise<LeagueContract> {
    await this.leagues.setJoined(userId, joined);
    return this.read(userId);
  }

  async read(userId: string): Promise<LeagueContract> {
    const periodKey = periodKeyOf(new Date());
    const endsAt = periodWindow(periodKey).endsAt.toISOString();

    if (!(await this.leagues.hasJoined(userId))) {
      // Un non-membre voit l'échelle et l'invitation à entrer, jamais le
      // classement : montrer des noms à qui n'a pas rejoint contredirait le
      // « périmètre CHOISI ». Ni la zone de montée, qui se lit sur lui.
      return {
        joined: false,
        periodKey,
        endsAt,
        division: await this.leagues.divisionToOpen(userId, periodKey),
        score: 0,
        standings: [],
        lastResult: null,
        promotion: null,
      };
    }

    const lastResult = await this.settleDue(userId, periodKey);
    // Lue sur les périodes AVANT celle-ci, maintenant réglées : une séance
    // a pu ouvrir la semaine avant le règlement, dans l'ancienne division.
    const division = await this.leagues.divisionToOpen(userId, periodKey);
    await this.leagues.openPeriod(userId, periodKey, division);
    await this.leagues.alignPeriod(userId, periodKey, division);

    const membres = await this.leagues.standings(periodKey, division);
    const rangs = competitionRanks(
      membres,
      (membre) => membre.score,
      (membre) => membre.userId,
    );

    return {
      joined: true,
      periodKey,
      endsAt,
      division,
      score: membres.find((membre) => membre.userId === userId)?.score ?? 0,
      standings: membres.map((membre) => ({
        userId: membre.userId,
        displayName: membre.user.profile?.displayName ?? 'Membre Carlys',
        score: membre.score,
        // Le rang FIGÉ l'emporte dès qu'il existe : c'est celui du résultat.
        rank: membre.finalRank ?? rangs.get(membre.userId) ?? membres.length,
        isMe: membre.userId === userId,
      })),
      lastResult,
      // Lu sur les MÊMES membres que le classement ci-dessus : la zone
      // annoncée et les rangs affichés ne peuvent pas se contredire.
      promotion: promotionOutlook(division, membres, userId),
    };
  }

  /**
   * Règle les périodes échues de cette personne, et rend le résultat de la
   * dernière — ce qui permet d'annoncer une montée UNE fois, au lieu d'un
   * changement de division sans explication.
   *
   * Une lecture règle la division ENTIÈRE de la période, pas seulement la
   * ligne de l'appelant : deux personnes liraient sinon deux classements
   * différents de la même semaine.
   */
  private async settleDue(
    userId: string,
    periodKey: string,
  ): Promise<LeagueContract['lastResult']> {
    const echues = await this.leagues.unsettledBefore(userId, periodKey);
    let dernier: LeagueContract['lastResult'] = null;

    for (const echue of echues) {
      const membres = await this.leagues.standings(echue.periodKey, echue.division);
      const resultats = settleDivision(echue.division, membres);
      const ecrites = await this.leagues.settle(echue.periodKey, resultats);
      const mien = resultats.find((resultat) => resultat.userId === userId);
      if (ecrites === 0 || mien === undefined) {
        continue; // Réglée par une lecture concurrente : rien à annoncer.
      }
      dernier = {
        periodKey: echue.periodKey,
        rank: mien.rank,
        from: echue.division,
        to: mien.nextDivision,
      };
    }
    return dernier;
  }
}
