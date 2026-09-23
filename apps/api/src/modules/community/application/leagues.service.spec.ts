import { type LeagueDivision } from '@prisma/client';
import {
  type LeagueMemberWithName,
  type LeaguesRepository,
} from '../infrastructure/leagues.repository';
import { LeaguesService } from './leagues.service';

/// CE QUE CE FICHIER PROTÈGE : la zone de montée part avec la ligue, et
/// seulement vers qui l'a rejointe. Le calcul lui-même est éprouvé cas par
/// cas dans `league-ladder.spec.ts` ; ici, on vérifie le BRANCHEMENT — sans
/// PostgreSQL, là où l'e2e des ligues en demande un.

const ME = 'utilisateur-moi';

/** Une ligne de classement telle que le dépôt la rend, nom compris. */
const membre = (userId: string, score: number): LeagueMemberWithName => ({
  userId,
  periodKey: '2026-W39',
  division: 'OR',
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
}) {
  const repository = {
    hasJoined: jest.fn().mockResolvedValue(options.joined),
    setJoined: jest.fn().mockResolvedValue(undefined),
    divisionToOpen: jest.fn().mockResolvedValue(options.division ?? 'OR'),
    openPeriod: jest.fn().mockResolvedValue(undefined),
    standings: jest.fn().mockResolvedValue(options.standings ?? []),
    // Aucune période échue : le règlement paresseux a son e2e.
    unsettledBefore: jest.fn().mockResolvedValue([]),
    settle: jest.fn().mockResolvedValue(0),
  };
  return {
    service: new LeaguesService(repository as unknown as LeaguesRepository),
    repository,
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
