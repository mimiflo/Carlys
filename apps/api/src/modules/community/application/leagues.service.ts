import { type League as LeagueContract } from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { type ChallengeMetric, type Prisma } from '@prisma/client';
import { competitionRanks } from '../domain/competition-ranks';
import {
  periodKeyOf,
  periodWindow,
  pointsOf,
  previousPeriodKey,
  promotionOutlook,
  settleDivision,
} from '../domain/league-ladder';
import { CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import { LeaguesRepository } from '../infrastructure/leagues.repository';

/**
 * LES LIGUES : un classement hebdomadaire, choisi, qui ne rend rien au profil.
 *
 * On est classé dans un GROUPE de 20 de sa division (`LEAGUE_GROUP_SIZE`),
 * jamais avec la division entière : classement, règlement et zone de montée
 * se lisent tous sur `(période, division, groupe)`.
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
  constructor(
    private readonly leagues: LeaguesRepository,
    private readonly moderation: CommunityModerationRepository,
  ) {}

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

    await this.settleDue(userId, periodKey);
    // Lue sur les périodes AVANT celle-ci, maintenant réglées : une séance
    // a pu ouvrir la semaine avant le règlement, dans l'ancienne division.
    const division = await this.leagues.divisionToOpen(userId, periodKey);
    const cohort = await this.leagues.placeInPeriod(userId, periodKey, division);

    const [membres, lastResult, bloques] = await Promise.all([
      this.leagues.standings(periodKey, division, cohort),
      this.lastResult(userId, periodKey),
      this.moderation.blockedUserIdsEitherWay(userId),
    ]);
    // Les rangs se calculent sur le groupe ENTIER, avant de taire qui que
    // ce soit : retirer une personne bloquée ne décale personne, et un trou
    // dans la numérotation est plus honnête qu'un rang qui ment.
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
      // Principe 6 : une personne bloquée, dans un sens ou dans l'autre, est
      // absente des listes — celle-ci comprise.
      standings: membres
        .filter((membre) => !bloques.has(membre.userId))
        .map((membre) => ({
          userId: membre.userId,
          displayName: membre.user.profile?.displayName ?? 'Membre Carlys',
          score: membre.score,
          // Le rang FIGÉ l'emporte dès qu'il existe : c'est celui du résultat.
          rank: membre.finalRank ?? rangs.get(membre.userId) ?? membres.length,
          isMe: membre.userId === userId,
        })),
      lastResult,
      // Lu sur les MÊMES membres que les rangs ci-dessus, groupe entier : la
      // zone annoncée et les rangs affichés ne peuvent pas se contredire, et
      // taire quelqu'un ne rapproche personne de la montée.
      promotion: promotionOutlook(division, membres, userId),
    };
  }

  /**
   * Règle les périodes échues de cette personne.
   *
   * Une lecture règle le GROUPE ENTIER de chaque période, pas seulement la
   * ligne de l'appelant : deux personnes liraient sinon deux classements
   * différents de la même semaine.
   *
   * Chaque ligne est RELUE juste avant son règlement, jamais prise dans la
   * liste lue d'abord : régler une semaine réaligne la suivante (division
   * et groupe changés, voir `realignFollowing`). La régler ensuite avec sa
   * ligne d'avant réglait l'ancien groupe, sans moi, et laissait ma semaine
   * en suspens — sans résultat annoncé, et la semaine en cours ouverte dans
   * la mauvaise division.
   */
  private async settleDue(userId: string, periodKey: string): Promise<void> {
    const echues = await this.leagues.unsettledBefore(userId, periodKey);
    for (const { periodKey: echue } of echues) {
      const ligne = await this.leagues.membership(userId, echue);
      if (ligne === null || ligne.settledAt !== null) {
        continue; // Réglée entre-temps, par une lecture concurrente.
      }
      const membres = await this.leagues.standings(echue, ligne.division, ligne.cohort);
      // L'écriture reste conditionnée à `settledAt: null`, ligne par ligne :
      // un règlement concurrent du même groupe n'y touche plus.
      await this.leagues.settle(echue, settleDivision(ligne.division, membres));
    }
  }

  /**
   * Le résultat de la semaine PASSÉE (la semaine ISO qui précède
   * `periodKey`), s'il est réglé et que cette personne y figurait.
   *
   * Lu en base, et non rendu par le règlement : quiconque règle la semaine
   * (moi ou un autre membre du groupe), chacun lit SON résultat, et pendant
   * toute la semaine en cours — la phrase affichée dit « la semaine
   * passée », elle reste vraie jusqu'à dimanche. Absent la semaine passée
   * (six semaines d'absence, par exemple) : aucun résultat à annoncer.
   */
  private async lastResult(
    userId: string,
    periodKey: string,
  ): Promise<LeagueContract['lastResult']> {
    const passee = await this.leagues.membership(userId, previousPeriodKey(periodKey));
    if (
      passee === null ||
      passee.settledAt === null ||
      passee.finalRank === null ||
      passee.nextDivision === null
    ) {
      return null;
    }
    return {
      periodKey: passee.periodKey,
      rank: passee.finalRank,
      from: passee.division,
      to: passee.nextDivision,
    };
  }
}
