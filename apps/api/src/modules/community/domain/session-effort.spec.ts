import {
  creditedEffort,
  MAX_CREDITED_DISTANCE_METERS,
  NO_EFFORT,
  SESSIONS_CREDITED_PER_DAY,
} from './session-effort';

/// CE QUE CE FICHIER PROTÈGE : ce qu'une séance verse aux défis et à la
/// ligue reste PLAUSIBLE. Mesuré avant ces bornes : une séance vide valait
/// 50 points, une séance d'une minute déclarant 1 000 km et 24 h en valait
/// 11 540 — trente semaines régulières d'un coup.

const base = {
  setsCount: 3,
  activeSeconds: 1_800,
  distanceMeters: 5_000,
  windowSeconds: 3_600,
  completedThatDay: 1,
};

describe('creditedEffort', () => {
  it('une séance ordinaire passe telle quelle', () => {
    expect(creditedEffort(base)).toEqual({
      countsAsWorkout: true,
      activeSeconds: 1_800,
      distanceMeters: 5_000,
    });
  });

  it('une séance SANS série ne compte pas comme une séance', () => {
    expect(creditedEffort({ ...base, setsCount: 0, activeSeconds: 0, distanceMeters: 0 })).toEqual(
      NO_EFFORT,
    );
  });

  it('1 000 km et 24 h déclarés dans une séance d’une minute : bornés au créneau', () => {
    const effort = creditedEffort({
      ...base,
      activeSeconds: 86_400,
      distanceMeters: 1_000_000,
      windowSeconds: 60,
    });
    expect(effort.activeSeconds).toBe(60);
    // 72 km/h pendant une minute : 1,2 km, pas 1 000.
    expect(effort.distanceMeters).toBe(1_200);
  });

  it('la distance ne dépasse jamais 300 km, même sur un créneau de 24 h', () => {
    const effort = creditedEffort({
      ...base,
      distanceMeters: 1_000_000,
      windowSeconds: 86_400,
    });
    expect(effort.distanceMeters).toBe(MAX_CREDITED_DISTANCE_METERS);
  });

  it('le créneau lui-même est borné à 24 h, et jamais négatif', () => {
    expect(
      creditedEffort({ ...base, activeSeconds: 200_000, windowSeconds: 10 * 86_400 }).activeSeconds,
    ).toBe(86_400);
    expect(creditedEffort({ ...base, windowSeconds: -5 })).toMatchObject({
      activeSeconds: 0,
      distanceMeters: 0,
    });
  });

  it('un créneau à la milliseconde crédite des secondes ENTIÈRES', () => {
    // Séance ouverte à 10:00:00.483 et close à 10:10:00.999 : 600,516 s.
    // Une fraction se comptait 600 au défi collectif (Prisma tronque) et 601
    // au défi entre amis (`::int` arrondit) — le même effort, deux valeurs.
    const effort = creditedEffort({ ...base, activeSeconds: 2_700, windowSeconds: 600.516 });
    expect(effort.activeSeconds).toBe(600);
    expect(Number.isInteger(effort.distanceMeters)).toBe(true);
  });

  it(`au-delà de ${SESSIONS_CREDITED_PER_DAY} séances le même jour, rien`, () => {
    expect(creditedEffort({ ...base, completedThatDay: SESSIONS_CREDITED_PER_DAY })).toMatchObject({
      countsAsWorkout: true,
    });
    expect(creditedEffort({ ...base, completedThatDay: SESSIONS_CREDITED_PER_DAY + 1 })).toEqual(
      NO_EFFORT,
    );
  });
});
