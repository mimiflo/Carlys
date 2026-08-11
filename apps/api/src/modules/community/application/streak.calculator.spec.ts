import { computeStreakDays, dayKeyInZone } from './streak.calculator';

describe('dayKeyInZone', () => {
  it('découpe les jours dans le fuseau demandé, pas en UTC', () => {
    // 23 h 30 à Paris le 10 août = 21 h 30 UTC le 10 août ; mais
    // 23 h 30 UTC le 10 août = 01 h 30 à Paris le 11 août.
    const lateUtc = new Date('2026-08-10T23:30:00Z');
    expect(dayKeyInZone(lateUtc, 'Europe/Paris')).toBe('2026-08-11');
    expect(dayKeyInZone(lateUtc, 'UTC')).toBe('2026-08-10');
  });

  it('replie sur UTC quand le fuseau est inconnu', () => {
    const date = new Date('2026-08-10T23:30:00Z');
    expect(dayKeyInZone(date, 'Pas/Un_Fuseau')).toBe('2026-08-10');
  });
});

describe('computeStreakDays', () => {
  const paris = 'Europe/Paris';
  const noonUtc = (day: string): Date => new Date(`${day}T12:00:00Z`);

  it('0 sans aucune séance', () => {
    expect(
      computeStreakDays({ sessionStarts: [], timeZone: paris, now: noonUtc('2026-08-11') }),
    ).toBe(0);
  });

  it('compte les jours consécutifs finissant aujourd’hui', () => {
    const streak = computeStreakDays({
      sessionStarts: ['2026-08-09', '2026-08-10', '2026-08-11'].map(noonUtc),
      timeZone: paris,
      now: noonUtc('2026-08-11'),
    });
    expect(streak).toBe(3);
  });

  it('rien encore aujourd’hui ne BRISE pas la série d’hier', () => {
    const streak = computeStreakDays({
      sessionStarts: ['2026-08-08', '2026-08-09', '2026-08-10'].map(noonUtc),
      timeZone: paris,
      now: noonUtc('2026-08-11'),
    });
    expect(streak).toBe(3);
  });

  it('un trou casse la série — seuls les jours récents comptent', () => {
    const streak = computeStreakDays({
      sessionStarts: ['2026-08-05', '2026-08-06', '2026-08-10', '2026-08-11'].map(noonUtc),
      timeZone: paris,
      now: noonUtc('2026-08-11'),
    });
    expect(streak).toBe(2);
  });

  it('une série arrêtée avant-hier vaut 0', () => {
    const streak = computeStreakDays({
      sessionStarts: ['2026-08-07', '2026-08-08'].map(noonUtc),
      timeZone: paris,
      now: noonUtc('2026-08-11'),
    });
    expect(streak).toBe(0);
  });

  it('deux séances le même jour ne comptent qu’une fois', () => {
    const streak = computeStreakDays({
      sessionStarts: [new Date('2026-08-11T06:00:00Z'), new Date('2026-08-11T18:00:00Z')],
      timeZone: paris,
      now: noonUtc('2026-08-11'),
    });
    expect(streak).toBe(1);
  });

  it('la séance de 23 h 30 heure locale compte pour le bon jour', () => {
    // 21 h 30 UTC le 10 = 23 h 30 à Paris le 10 : la série 10→11 tient.
    const streak = computeStreakDays({
      sessionStarts: [new Date('2026-08-10T21:30:00Z'), noonUtc('2026-08-11')],
      timeZone: paris,
      now: noonUtc('2026-08-11'),
    });
    expect(streak).toBe(2);
  });
});
