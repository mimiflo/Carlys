import { computeStreakDays, dayKeyInZone } from './streak.calculator';

describe('dayKeyInZone', () => {
  it('découpe les jours dans le fuseau demandé, pas en UTC', () => {
    // 23 h 30 à Paris le 10 août = 21 h 30 UTC le 10 août ; mais
    // 23 h 30 UTC le 10 août = 01 h 30 à Paris le 11 août.
    const lateUtc = new Date('2026-08-10T23:30:00Z');
    expect(dayKeyInZone(lateUtc, 'Europe/Paris')).toBe('2026-08-11');
    expect(dayKeyInZone(lateUtc, 'UTC')).toBe('2026-08-10');
  });

  it('un fuseau à l’OUEST de Greenwich recule le jour, il ne l’avance pas', () => {
    // 19 h à Montréal le dimanche 9 août (UTC−4 en été) = 23 h UTC le 9 :
    // le jour local est encore le 9, alors que Paris est déjà au 10.
    const sundayEveningMontreal = new Date('2026-08-09T23:00:00Z');
    expect(dayKeyInZone(sundayEveningMontreal, 'America/Montreal')).toBe('2026-08-09');
    expect(dayKeyInZone(sundayEveningMontreal, 'Europe/Paris')).toBe('2026-08-10');
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

  it('à Montréal, la séance du dimanche 19 h compte pour le dimanche, pas pour lundi', () => {
    // Dimanche 9 août, 19 h à Montréal (UTC−4 en été) = 23 h UTC = lundi 10,
    // 1 h à Paris. Le mardi 11 au matin (heure locale), cette séance date
    // d'avant-hier : la série est retombée à 0. Découpée à Paris, la même
    // séance daterait d'hier et la série vaudrait encore 1 : le jour de trop
    // que verraient les amis.
    const montreal = 'America/Montreal';
    const sundayEvening = [new Date('2026-08-09T23:00:00Z')];
    const tuesdayMorningMontreal = new Date('2026-08-11T12:00:00Z');

    expect(
      computeStreakDays({
        sessionStarts: sundayEvening,
        timeZone: montreal,
        now: tuesdayMorningMontreal,
      }),
    ).toBe(0);
    expect(
      computeStreakDays({
        sessionStarts: sundayEvening,
        timeZone: paris,
        now: tuesdayMorningMontreal,
      }),
    ).toBe(1);
  });

  it('à Montréal, une séance du soir prolonge la série jusqu’à minuit LOCAL', () => {
    // Séances les 8 et 9 août à 19 h locales ; « maintenant » = dimanche 9,
    // 23 h 30 à Montréal (3 h 30 UTC le 10). La journée locale n'est pas
    // finie : la série vaut 2 et finit aujourd'hui.
    const montreal = 'America/Montreal';
    const streak = computeStreakDays({
      sessionStarts: [new Date('2026-08-08T23:00:00Z'), new Date('2026-08-09T23:00:00Z')],
      timeZone: montreal,
      now: new Date('2026-08-10T03:30:00Z'),
    });
    expect(streak).toBe(2);
  });
});
