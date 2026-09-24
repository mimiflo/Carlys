import { type LeagueDivision, type LeagueMembership } from '@prisma/client';
import { type CommunityModerationRepository } from '../infrastructure/community-moderation.repository';
import {
  type LeagueMemberWithName,
  type LeaguesRepository,
} from '../infrastructure/leagues.repository';
import { periodKeyOf, previousPeriodKey } from '../domain/league-ladder';
import { LeaguesService } from './leagues.service';

/// CE QUE CE FICHIER PROTÈGE : ce que la lecture de la ligue sert, et à qui.
/// La zone de montée part avec la ligue, et seulement vers qui l'a rejointe ;
/// le classement est celui du GROUPE du lecteur ; une personne bloquée en est
/// absente sans décaler les rangs ; le résultat de la semaine passée se lit
/// en base, quel que soit le lecteur qui l'a réglée. Le calcul lui-même est
/// éprouvé cas par cas dans `league-ladder.spec.ts` ; ici, on vérifie le
/// BRANCHEMENT — sans PostgreSQL, là où l'e2e des ligues en demande un.

const ME = 'utilisateur-moi';
const COHORT = 3;

/** Une ligne de classement telle que le dépôt la rend, nom compris. */
const membre = (userId: string, score: number): LeagueMemberWithName => ({
  userId,
  periodKey: '2026-W39',
  division: 'OR',
  cohort: COHORT,
  score,
  finalRank: null,
  nextDivision: null,
  settledAt: null,
  createdAt: new Date('2026-09-21T08:00:00Z'),
  user: { profile: { displayName: userId } },
});

function buildService(options: {
  joined: boolean;
  division?: LeagueDivision;
  standings?: LeagueMemberWithName[];
  blocked?: string[];
  /** Ma ligne de la semaine PASSÉE, telle qu'en base. */
  lastWeek?: LeagueMembership | null;
  unsettled?: LeagueMembership[];
  /**
   * Mes lignes telles qu'en base AU MOMENT où on les relit, par période —
   * elles peuvent différer de `unsettled`, lu avant tout règlement. Par
   * défaut, les lignes de `unsettled` elles-mêmes.
   */
  rows?: LeagueMembership[];
}) {
  const enBase = new Map(
    [
      ...(options.lastWeek ? [options.lastWeek] : []),
      ...(options.rows ?? options.unsettled ?? []),
    ].map((ligne) => [ligne.periodKey, ligne]),
  );
  const repository = {
    hasJoined: jest.fn().mockResolvedValue(options.joined),
    setJoined: jest.fn().mockResolvedValue(undefined),
    divisionToOpen: jest.fn().mockResolvedValue(options.division ?? 'OR'),
    placeInPeriod: jest.fn().mockResolvedValue(COHORT),
    standings: jest.fn().mockResolvedValue(options.standings ?? []),
    membership: jest.fn((_userId: string, periodKey: string) =>
      Promise.resolve(enBase.get(periodKey) ?? null),
    ),
    unsettledBefore: jest.fn().mockResolvedValue(options.unsettled ?? []),
    settle: jest.fn().mockResolvedValue(0),
  };
  const moderation = {
    blockedUserIdsEitherWay: jest.fn().mockResolvedValue(new Set(options.blocked ?? [])),
  };
  return {
    service: new LeaguesService(
      repository as unknown as LeaguesRepository,
      moderation as unknown as CommunityModerationRepository,
    ),
    repository,
    moderation,
  };
}

/** Douze joueurs, moi quatrième à 240. */
const douze = [300, 280, 260, 240, 220, 200, 180, 160, 140, 120, 100, 80].map((score, index) =>
  membre(index === 3 ? ME : `u${index}`, score),
);

describe('LeaguesService — la zone de montée', () => {
  it('ne situe PAS un non-membre : ni classement, ni zone', async () => {
    // La zone se lit sur le classement ; un non-membre n'en voit aucun, il
    // n'a donc rien à situer.
    const { service, repository } = buildService({ joined: false, standings: douze });

    const ligue = await service.read(ME);

    expect(ligue.standings).toEqual([]);
    expect(ligue.promotion).toBeNull();
    expect(repository.standings).not.toHaveBeenCalled();
  });

  it('situe un membre sur les MÊMES membres que le classement servi', async () => {
    const { service } = buildService({ joined: true, standings: douze });

    const ligue = await service.read(ME);

    expect(ligue.standings.find((ligne) => ligne.isMe)?.rank).toBe(4);
    expect(ligue.promotion).toEqual({
      promotedCount: 5,
      minPlayers: 10,
      activePlayers: 12,
      topDivision: false,
      inZone: true,
      zoneScore: 200,
      pointsToZone: 0,
    });
  });

  it('lit la division OUVERTE : en Diamant, rien au-dessus', async () => {
    const { service } = buildService({ joined: true, division: 'DIAMANT', standings: douze });

    expect((await service.read(ME)).promotion).toMatchObject({
      topDivision: true,
      inZone: false,
      pointsToZone: 0,
    });
  });

  it('rend la zone à l’entrée, et plus rien à la sortie', async () => {
    // `join` et `leave` renvoient la même lecture que GET : l'écran n'a pas
    // à relire pour savoir où il en est.
    const entree = buildService({ joined: true, standings: douze });
    expect((await entree.service.setJoined(ME, true)).promotion).not.toBeNull();
    expect(entree.repository.setJoined).toHaveBeenCalledWith(ME, true);

    const sortie = buildService({ joined: false, standings: douze });
    expect((await sortie.service.setJoined(ME, false)).promotion).toBeNull();
  });
});

describe('LeaguesService — le classement est celui de MON groupe', () => {
  it('lit le classement du groupe où la période du lecteur est rangée', async () => {
    const { service, repository } = buildService({ joined: true, standings: douze });

    const ligue = await service.read(ME);

    expect(repository.placeInPeriod).toHaveBeenCalledWith(ME, ligue.periodKey, 'OR');
    expect(repository.standings).toHaveBeenCalledWith(ligue.periodKey, 'OR', COHORT);
  });

  it('règle une période échue sur SON groupe, pas sur la division entière', async () => {
    const echue: LeagueMembership = { ...membre(ME, 90), periodKey: '2026-W30', cohort: 7 };
    const { service, repository } = buildService({ joined: true, unsettled: [echue] });

    await service.read(ME);

    expect(repository.standings).toHaveBeenCalledWith('2026-W30', 'OR', 7);
    expect(repository.settle).toHaveBeenCalledWith('2026-W30', expect.any(Array));
  });

  it('règle chaque semaine échue sur sa ligne RELUE, que le règlement d’avant a pu déplacer', async () => {
    // Deux semaines échues, lues AVANT tout règlement. Régler la première
    // (une montée) réaligne la seconde : autre division, autre groupe. La
    // régler avec la ligne lue d'abord réglait l'ancien groupe — sans moi —
    // et laissait ma semaine passée en suspens, sans résultat annoncé.
    const avantDerniere: LeagueMembership = {
      ...membre(ME, 900),
      periodKey: '2026-W30',
      division: 'ARGENT',
      cohort: 4,
    };
    const derniereLue: LeagueMembership = {
      ...membre(ME, 50),
      periodKey: '2026-W31',
      division: 'ARGENT',
      cohort: 5,
    };
    const derniereRealignee: LeagueMembership = { ...derniereLue, division: 'OR', cohort: 9 };
    const { service, repository } = buildService({
      joined: true,
      unsettled: [avantDerniere, derniereLue],
      rows: [avantDerniere, derniereRealignee],
    });

    await service.read(ME);

    expect(repository.standings).toHaveBeenCalledWith('2026-W30', 'ARGENT', 4);
    expect(repository.standings).toHaveBeenCalledWith('2026-W31', 'OR', 9);
    expect(repository.standings).not.toHaveBeenCalledWith('2026-W31', 'ARGENT', 5);
  });

  it('ne règle pas une semaine échue qu’un autre lecteur a réglée entre-temps', async () => {
    const lue: LeagueMembership = { ...membre(ME, 90), periodKey: '2026-W30' };
    const reglee: LeagueMembership = {
      ...lue,
      finalRank: 2,
      nextDivision: 'OR',
      settledAt: new Date(),
    };
    const { service, repository } = buildService({
      joined: true,
      unsettled: [lue],
      rows: [reglee],
    });

    await service.read(ME);

    expect(repository.settle).not.toHaveBeenCalled();
  });
});

describe('LeaguesService — une personne bloquée est absente du classement', () => {
  it('la tait dans les deux sens, sans décaler les rangs ni la zone', async () => {
    // u1 (2e) et u5 (6e) sont séparés du lecteur par un blocage.
    const { service, moderation } = buildService({
      joined: true,
      standings: douze,
      blocked: ['u1', 'u5'],
    });

    const ligue = await service.read(ME);

    expect(moderation.blockedUserIdsEitherWay).toHaveBeenCalledWith(ME);
    const servis = ligue.standings.map((ligne) => ligne.userId);
    expect(servis).not.toContain('u1');
    expect(servis).not.toContain('u5');
    expect(servis).toHaveLength(10);
    // Les rangs restent ceux du groupe ENTIER : un trou, pas un décalage.
    expect(ligue.standings.map((ligne) => ligne.rank)).toEqual([1, 3, 4, 5, 7, 8, 9, 10, 11, 12]);
    expect(ligue.standings.find((ligne) => ligne.isMe)?.rank).toBe(4);
    // La zone se lit aussi sur le groupe entier : taire quelqu'un ne
    // rapproche personne de la montée.
    expect(ligue.promotion).toMatchObject({ activePlayers: 12, zoneScore: 200 });
  });
});

describe('LeaguesService — le résultat de la semaine passée, pour chacun', () => {
  const semainePassee = previousPeriodKey(periodKeyOf(new Date()));

  it('se lit en base, même quand un AUTRE a réglé la semaine', async () => {
    // Rien à régler pour moi (un autre membre du groupe l'a fait), et le
    // règlement n'écrit rien : mon résultat existe quand même.
    const reglee: LeagueMembership = {
      ...membre(ME, 900),
      periodKey: semainePassee,
      finalRank: 1,
      nextDivision: 'PLATINE',
      settledAt: new Date(),
    };
    const { service, repository } = buildService({ joined: true, lastWeek: reglee });

    const ligue = await service.read(ME);

    expect(repository.membership).toHaveBeenCalledWith(ME, semainePassee);
    expect(ligue.lastResult).toEqual({
      periodKey: semainePassee,
      rank: 1,
      from: 'OR',
      to: 'PLATINE',
    });
  });

  it('rien tant que la semaine passée n’est pas réglée', async () => {
    const ouverte: LeagueMembership = { ...membre(ME, 900), periodKey: semainePassee };
    const { service } = buildService({ joined: true, lastWeek: ouverte });

    expect((await service.read(ME)).lastResult).toBeNull();
  });

  it('rien sans ligne la semaine passée (absence de plusieurs semaines)', async () => {
    const { service } = buildService({ joined: true, lastWeek: null });

    expect((await service.read(ME)).lastResult).toBeNull();
  });
});
