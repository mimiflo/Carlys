import { LeagueDivision } from '@prisma/client';
import {
  LEAGUE_LADDER,
  LEAGUE_MIN_PLAYERS,
  periodKeyOf,
  periodWindow,
  pointsOf,
  previousPeriodKey,
  isPeriodKey,
  promoted,
  relegated,
  settleDivision,
} from './league-ladder';

/// CE QUE CE FICHIER PROTÈGE : le barème écrit dans `docs/product/community.md`
/// et le code qui le rend disent la même chose. Le barème est la seule partie
/// des ligues qu'on ne peut pas éprouver à l'œil sur un écran.

describe('Les points d’une contribution', () => {
  it('convertit chaque métrique dans son unité de barème', () => {
    expect(pointsOf('WORKOUTS', 1)).toBe(50);
    expect(pointsOf('ACTIVE_SECONDS', 3_600)).toBe(60);
    expect(pointsOf('DISTANCE_METERS', 10_000)).toBe(100);
    expect(pointsOf('QUIZ_CORRECT', 1)).toBe(10);
  });

  it('tronque, et ne reporte JAMAIS le reste', () => {
    // Reporter demanderait un registre de restes par personne et par
    // métrique, et rendrait le score dépendant de l'ordre des écritures.
    expect(pointsOf('ACTIVE_SECONDS', 59)).toBe(0);
    expect(pointsOf('ACTIVE_SECONDS', 119)).toBe(1);
    expect(pointsOf('DISTANCE_METERS', 119)).toBe(1);
  });

  it('refuse le négatif et le nul : un compteur de ligue ne descend pas', () => {
    expect(pointsOf('WORKOUTS', 0)).toBe(0);
    expect(pointsOf('WORKOUTS', -3)).toBe(0);
  });

  it('garde l’ordre de grandeur annoncé par la documentation', () => {
    // Trois séances de fonte : 150. Vingt kilomètres de course : 200.
    // Aucune métrique n'écrase l'autre — c'est le point du barème.
    expect(pointsOf('WORKOUTS', 3)).toBe(150);
    expect(pointsOf('DISTANCE_METERS', 20_000)).toBe(200);
  });
});

describe('La période est la semaine ISO, en UTC', () => {
  it('nomme la semaine d’un instant', () => {
    // Le 19 septembre 2026 est un samedi, semaine 38.
    expect(periodKeyOf(new Date('2026-09-19T22:00:00Z'))).toBe('2026-W38');
    // Le lundi suivant ouvre la 39.
    expect(periodKeyOf(new Date('2026-09-21T00:00:00Z'))).toBe('2026-W39');
  });

  it('range le tournant d’année selon son JEUDI, comme l’exige ISO 8601', () => {
    // Le 1er janvier 2027 est un vendredi : sa semaine est celle du jeudi
    // 31 décembre 2026, donc la 53e de 2026.
    expect(periodKeyOf(new Date('2027-01-01T12:00:00Z'))).toBe('2026-W53');
    // Le 4 janvier appartient TOUJOURS à la semaine 1.
    expect(periodKeyOf(new Date('2027-01-04T12:00:00Z'))).toBe('2027-W01');
  });

  it('rend une fenêtre du lundi au lundi suivant, exclu', () => {
    const { startsAt, endsAt } = periodWindow('2026-W38');
    expect(startsAt.toISOString()).toBe('2026-09-14T00:00:00.000Z');
    expect(endsAt.toISOString()).toBe('2026-09-21T00:00:00.000Z');
  });

  it('fait l’aller-retour, et recule d’une semaine', () => {
    expect(periodKeyOf(periodWindow('2026-W38').startsAt)).toBe('2026-W38');
    expect(previousPeriodKey('2026-W38')).toBe('2026-W37');
    expect(previousPeriodKey('2027-W01')).toBe('2026-W53');
  });

  it('reconnaît une clé de période, et rejette une semaine inexistante', () => {
    expect(isPeriodKey('2026-W38')).toBe(true);
    expect(isPeriodKey('2026-W99')).toBe(false);
    expect(isPeriodKey('2026-38')).toBe(false);
    expect(isPeriodKey(38)).toBe(false);
  });
});

describe('L’échelle des divisions', () => {
  it('recopie EXACTEMENT l’enum du schéma, dans l’ordre', () => {
    // Ajouter une division au schéma sans l'ajouter ici casse ce test,
    // jamais la production en silence.
    expect(LEAGUE_LADDER).toEqual(Object.values(LeagueDivision));
  });

  it('ne dépasse ni par le haut ni par le bas', () => {
    expect(promoted('OR')).toBe('PLATINE');
    expect(promoted('DIAMANT')).toBe('DIAMANT');
    expect(relegated('OR')).toBe('ARGENT');
    expect(relegated('BRONZE')).toBe('BRONZE');
  });
});

describe('Le règlement d’une division', () => {
  /** `count` joueurs aux scores décroissants, du plus fort au plus faible. */
  const division = (scores: number[]) =>
    scores.map((score, index) => ({ userId: `u${index}`, score }));

  const divisionOf = (results: ReturnType<typeof settleDivision>, userId: string) =>
    results.find((result) => result.userId === userId)?.nextDivision;

  it('fait monter les 5 premiers et descendre les 5 derniers', () => {
    const scores = [200, 190, 180, 170, 160, 150, 140, 130, 120, 110];
    const results = settleDivision('OR', division(scores));

    expect(results.slice(0, 5).map((r) => r.nextDivision)).toEqual(Array(5).fill('PLATINE'));
    expect(results.slice(5).map((r) => r.nextDivision)).toEqual(Array(5).fill('ARGENT'));
    expect(results.map((r) => r.rank)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  });

  it('ne fait JAMAIS descendre un score nul', () => {
    // « N'a pas joué » n'est pas une faute : aucun axe du dépôt ne punit une
    // absence, et une ligue qui reléguerait une semaine de maladie le ferait.
    const scores = [200, 190, 180, 170, 160, 150, 140, 130, 120, 110, 0, 0];
    const results = settleDivision('OR', division(scores));

    expect(divisionOf(results, 'u10')).toBe('OR');
    expect(divisionOf(results, 'u11')).toBe('OR');
    // Les absents n'occupent pas non plus les places de relégation : ce sont
    // bien les cinq derniers JOUEURS qui descendent.
    expect(divisionOf(results, 'u9')).toBe('ARGENT');
  });

  it('fige tout le monde en dessous du minimum de joueurs', () => {
    const results = settleDivision('OR', division([300, 200, 100]));

    expect(results.map((r) => r.nextDivision)).toEqual(['OR', 'OR', 'OR']);
    expect(LEAGUE_MIN_PLAYERS).toBe(10);
  });

  it('partage le rang des ex æquo, et fait sauter le suivant', () => {
    const results = settleDivision('OR', division([200, 200, 100]));

    expect(results.map((r) => r.rank)).toEqual([1, 1, 3]);
  });

  it('laisse une égalité à la frontière faire monter plus de cinq personnes', () => {
    // Conséquence ASSUMÉE de l'ex æquo : départager par l'identifiant serait
    // un tirage au sort déguisé. Seize joueurs, dont six à égalité en tête :
    // les six montent, et les cinq derniers descendent quand même.
    const scores = [200, 200, 200, 200, 200, 200, 190, 180, 170, 160, 150, 140, 130, 120, 110, 100];
    const results = settleDivision('OR', division(scores));

    expect(results.slice(0, 6).map((r) => r.nextDivision)).toEqual(Array(6).fill('PLATINE'));
    expect(results.slice(6, 11).map((r) => r.nextDivision)).toEqual(Array(5).fill('OR'));
    expect(results.slice(11).map((r) => r.nextDivision)).toEqual(Array(5).fill('ARGENT'));
  });

  it('ne bouge personne quand dix joueurs sont tous à égalité', () => {
    // Chacun est à la fois dans les 5 premiers et dans les 5 derniers : une
    // ligue parfaitement ambiguë ne relègue personne.
    const results = settleDivision('OR', division(Array.from({ length: 10 }, () => 120)));

    expect(results.map((r) => r.nextDivision)).toEqual(Array(10).fill('OR'));
    expect(results.map((r) => r.rank)).toEqual(Array(10).fill(1));
  });

  it('ne relègue pas en dessous de Bronze, ni ne promeut au-dessus de Diamant', () => {
    const scores = [200, 190, 180, 170, 160, 150, 140, 130, 120, 110];

    expect(
      settleDivision('BRONZE', division(scores))
        .slice(5)
        .map((r) => r.nextDivision),
    ).toEqual(Array(5).fill('BRONZE'));
    expect(
      settleDivision('DIAMANT', division(scores))
        .slice(0, 5)
        .map((r) => r.nextDivision),
    ).toEqual(Array(5).fill('DIAMANT'));
  });
});
