import { coachReflection, coachSteps } from './coach-steps';

describe('coachSteps — la réflexion, nommée depuis les vrais appels', () => {
  it('une étape par outil connu, une seule fois, dans l’ordre', () => {
    const steps = coachSteps();

    expect(steps.add([{ name: 'get_personal_records' }, { name: 'get_personal_records' }])).toEqual(
      ['Je regarde tes records'],
    );
    expect(steps.add([{ name: 'get_personal_records' }, { name: 'propose_program' }])).toEqual([
      'Je prépare ton programme',
    ]);
    // Un outil inconnu ne s'invente pas d'étape, pas même un nom d'objet.
    expect(
      steps.add([{ name: 'outil_inconnu' }, { name: 'toString' }, { name: 'constructor' }]),
    ).toEqual([]);
    expect(steps.all({ session: false, program: true })).toEqual([
      'Je regarde tes records',
      'Je prépare ton programme',
    ]);
    // Une proposition rejetée par la validation : son « Je prépare… » ne s'archive pas.
    expect(steps.all({ session: false, program: false })).toEqual(['Je regarde tes records']);
  });
});

describe('coachReflection — chaque étape commence puis finit, et la réflexion a sa durée', () => {
  afterEach(() => jest.useRealTimers());

  it('commencée (les trois points), finie (la coche), durée jusqu’au premier mot', async () => {
    jest.useFakeTimers({ now: new Date('2026-10-02T10:00:00Z') });
    const events: string[] = [];
    const reflection = coachReflection((label, done, elapsedMs) =>
      events.push(`${done ? 'fini' : 'début'} : ${label} (${elapsedMs / 1000} s)`),
    );

    reflection.start([{ name: 'get_personal_records' }]);
    reflection.end([{ name: 'get_personal_records' }]);
    const run = reflection.track(() => Promise.resolve('lu'));
    reflection.begin([{ name: 'search_exercises' }]);
    jest.setSystemTime(new Date('2026-10-02T10:00:31Z'));
    await expect(run([{ name: 'search_exercises', input: {}, id: 'a' }])).resolves.toBe('lu');
    reflection.wrote();
    jest.setSystemTime(new Date('2026-10-02T10:01:30Z'));

    expect(events).toEqual([
      'début : Je regarde tes records (0 s)',
      'fini : Je regarde tes records (0 s)',
      'début : Je cherche des exercices (0 s)',
      // Le temps écoulé, que le chrono de l'appli reprend.
      'fini : Je cherche des exercices (31 s)',
    ]);
    // Du créneau au premier mot, pas jusqu'à la fin de la réponse.
    expect(reflection.seconds()).toBe(31);
  });

  it('une étape ne finit que si elle a commencé, et une fois', () => {
    const events: string[] = [];
    const reflection = coachReflection((label, done) => done && events.push(label));
    // Un outil exécuté sans avoir été annoncé (ou annoncé, puis fini deux fois).
    reflection.end([{ name: 'get_personal_records' }]);
    reflection.begin([{ name: 'search_exercises' }]);
    reflection.end([{ name: 'search_exercises' }, { name: 'search_exercises' }]);
    reflection.end([{ name: 'search_exercises' }]);

    expect(events).toEqual(['Je cherche des exercices']);
  });

  it('pas commencée, ou sans premier mot mesuré : pas de durée', () => {
    expect(coachReflection().seconds()).toBeNull();
    const reflection = coachReflection();
    reflection.start([]);
    expect(reflection.seconds()).toBeNull();
  });
});
