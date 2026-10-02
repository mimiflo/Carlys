import { type CoachComposition } from '../domain/coach-model.port';
import { compositionFor, compositionSchema, exerciseRange } from './coach-session';
import { fallbackChoice, fitTo, parseChoice, sessionProposal } from './coach-session-choice';

const exercise = (id: string, muscle: string, equipment: string[] = [], extra = {}) => ({
  id,
  name: `Exercice ${id}`,
  difficulty: 'BEGINNER',
  muscle,
  equipment,
  ...extra,
});

const read = (id: string, name: string, content: unknown, isError = false) => ({
  call: { id, name, input: {} },
  result: { id, content: JSON.stringify(content), isError },
});

const proposal = (request: string, minutes: number | null = null) =>
  ({ kind: 'WORKOUT_PROPOSAL_REQUIRED', request, minutes }) as const;

/**
 * « tu me conseilles, quoi en séance quad fessiers ? » : constaté le
 * 2 octobre 2026, cinq fois signalé, la séance arrivait en texte, sans carte.
 */
describe('compositionFor', () => {
  const profile = read('lecture00', 'get_training_profile', {
    equipmentSlugs: ['poids-du-corps', 'halteres'],
  });
  const quads = read('lecture01', 'search_exercises', [
    exercise('squat-barre', 'quadriceps', ['barre']),
    exercise('squat-pdc', 'quadriceps', ['poids-du-corps']),
    exercise('gobelet', 'quadriceps', ['halteres']),
  ]);
  const glutes = read('lecture02', 'search_exercises', [
    exercise('hip-thrust', 'fessiers', ['poids-du-corps']),
    exercise('squat-pdc', 'quadriceps', ['poids-du-corps']),
  ]);
  const message = 'tu me conseilles, quoi en séance quad fessiers ?';

  it('les exercices lus, une fois chacun, faisables avec son matériel', () => {
    const composition = compositionFor(proposal(message), [profile, quads, glutes], null, message);
    expect(composition?.candidates.map((item) => item.id)).toEqual([
      'squat-pdc',
      'gobelet',
      'hip-thrust',
    ]);
  });

  it('trop peu de faisables : tous, plutôt qu’une séance impossible à composer', () => {
    const owned = read('lecture00', 'get_training_profile', { equipmentSlugs: ['kettlebell'] });
    const only = read('lecture01', 'search_exercises', [
      exercise('a', 'quadriceps', ['barre']),
      exercise('b', 'fessiers', ['machine']),
    ]);
    expect(
      compositionFor(proposal('Une séance jambes'), [owned, only], null, '')?.candidates,
    ).toHaveLength(2);
  });

  it('ni étirement, ni exercice avancé pour un débutant', () => {
    const beginner = read('lecture00', 'get_training_profile', {
      trainingExperience: 'BEGINNER',
      equipmentSlugs: [],
    });
    const mixed = read('lecture01', 'search_exercises', [
      exercise('etirement', 'ischio-jambiers', [], { type: 'STRETCHING' }),
      exercise('nordic', 'ischio-jambiers', [], { difficulty: 'ADVANCED' }),
      exercise('pont', 'fessiers'),
      exercise('souleve', 'ischio-jambiers'),
      exercise('fentes', 'quadriceps'),
    ]);
    expect(
      compositionFor(proposal('Une séance jambes'), [beginner, mixed], null, '')?.candidates.map(
        (i) => i.id,
      ),
    ).toEqual(['pont', 'souleve', 'fentes']);
  });

  it('ses records accompagnent les exercices : la charge en sera tirée', () => {
    const records = read('lecture03', 'get_personal_records', [
      { exerciseId: 'gobelet', weightKg: 20, reps: 10 },
      { exerciseId: 'gobelet', weightKg: 24, reps: 8 },
      { exerciseId: 'gobelet', weightKg: null, reps: 30 },
    ]);
    const composition = compositionFor(proposal(message), [profile, quads, records], null, message);
    expect(composition?.candidates.find((item) => item.id === 'gobelet')?.record).toEqual({
      weightKg: 24,
      reps: 8,
    });
    expect(composition?.candidates.find((item) => item.id === 'squat-pdc')?.record).toBeUndefined();
  });

  it('le contexte : la demande d’avant, le temps, la séance à modifier, ses dernières séances', () => {
    const recent = read('lecture04', 'get_recent_sessions', [
      { name: 'Jambes', startedAt: '2026-09-28T18:00' },
    ]);
    const composition = compositionFor(
      {
        kind: 'WORKOUT_MODIFICATION_REQUIRED',
        proposalId: 'p',
        request: 'Plus courte',
        minutes: 20,
      },
      [quads, recent],
      { name: 'Quadriceps', items: [{ exerciseId: 'presse', exerciseName: 'Presse' }] },
      'Plus courte',
    );
    // La séance à modifier d'abord : ses exercices restent possibles.
    expect(composition?.candidates[0]).toMatchObject({ id: 'presse', name: 'Presse' });
    expect(composition?.context).toEqual([
      'La séance à modifier, « Quadriceps » : Presse 1 séries.',
      'Temps disponible : 20 minutes, pas plus.',
      'Ses dernières séances : Jambes (2026-09-28).',
    ]);
    const asked = compositionFor(proposal(message), [quads], null, 'Ça fait 5 fois !');
    expect(asked?.context).toEqual([`Sa demande, plus haut : « ${message} ».`]);
  });

  it('rien de lisible : rien à composer, la raison métier se dira', () => {
    const failed = read('lecture01', 'search_exercises', 'panne', true);
    expect(compositionFor(proposal('Une séance jambes'), [profile, failed], null, '')).toBeNull();
  });
});

describe('le choix', () => {
  const composition: CoachComposition = {
    candidates: [
      { id: 'squat', name: 'Squat', muscle: 'quadriceps', equipment: [] },
      { id: 'fentes', name: 'Fentes', muscle: 'quadriceps', equipment: [] },
      {
        id: 'hip',
        name: 'Hip thrust',
        muscle: 'fessiers',
        equipment: [],
        record: { weightKg: 60, reps: 10 },
      },
      { id: 'pont', name: 'Pont fessier', muscle: 'fessiers', equipment: [] },
    ],
    minutes: null,
    context: [],
  };
  // Par alias, dans l'ordre de la liste : e1 squat, e2 fentes, e3 hip, e4 pont.
  const set = (id: string) => ({ id, sets: 3, reps: 12, rest: 60 });

  it('le format imposé n’admet que les alias lus, autant d’exercices que le temps en permet', () => {
    const schema = compositionSchema(composition);
    expect(schema.properties.exercises.items.properties.id.enum).toEqual(['e1', 'e2', 'e3', 'e4']);
    expect(exerciseRange(null)).toEqual({ min: 3, max: 6 });
    expect(exerciseRange(20)).toEqual({ min: 3, max: 3 });
    expect(exerciseRange(10)).toEqual({ min: 2, max: 2 });
    expect(compositionSchema({ ...composition, minutes: 20 }).properties.exercises.maxItems).toBe(
      3,
    );
  });

  it('une réponse qui tient est gardée ; un alias inconnu ou répété est écarté', () => {
    const choice = parseChoice(
      JSON.stringify({
        message: 'j’ai choisi le squat et le hip thrust.',
        name: 'Quadriceps et fessiers',
        exercises: [set('e1'), set('e9'), set('e3'), set('e1'), set('e2')],
      }),
      composition,
    );
    expect(choice?.exercises.map((item) => item.exerciseId)).toEqual(['squat', 'hip', 'fentes']);
    expect(choice?.message).toBe('J’ai choisi le squat et le hip thrust.');
    // Sa durée, calculée : 3 × (12 × 4 s + 60 s) par exercice.
    expect(choice?.estimatedMinutes).toBe(16);
  });

  it('illisible, sans message ou presque vide : null, le serveur composera', () => {
    expect(parseChoice('pas du JSON', composition)).toBeNull();
    expect(
      parseChoice(JSON.stringify({ name: 'S', exercises: [set('e1'), set('e3')] }), composition),
    ).toBeNull();
    expect(
      parseChoice(JSON.stringify({ message: 'M', name: 'S', exercises: [set('e1')] }), composition),
    ).toBeNull();
  });

  it('« J’ai 20 minutes » : la séance tient en 20 minutes', () => {
    const heavy = [1, 2, 3].map((i) => ({
      exerciseId: `x${i}`,
      sets: 5,
      reps: 10,
      restSeconds: 120,
    }));
    const fitted = fitTo(heavy, 20);
    const seconds = fitted.reduce((s, i) => s + i.sets * (i.reps * 4 + i.restSeconds), 0);
    expect(seconds).toBeLessThanOrEqual(20 * 60);
    expect(fitted.length).toBeGreaterThanOrEqual(2);
    expect(fitTo(heavy, null)).toEqual(heavy);
  });

  it('composée par le serveur : les muscles à tour de rôle, dans le temps annoncé', () => {
    expect(fallbackChoice(composition).exercises.map((item) => item.exerciseId)).toEqual([
      'squat',
      'hip',
      'fentes',
      'pont',
    ]);
    expect(fallbackChoice(composition).message).toContain(
      'squat, hip thrust, fentes et pont fessier',
    );
    expect(fallbackChoice({ ...composition, minutes: 15 }).estimatedMinutes).toBeLessThanOrEqual(
      15,
    );
  });

  it('la proposition : une entrée PAR SÉRIE, la charge tirée du record, aucune sans', () => {
    const items = sessionProposal(
      {
        message: 'M',
        name: 'S',
        estimatedMinutes: 30,
        exercises: [
          { exerciseId: 'squat', sets: 2, reps: 10, restSeconds: 90 },
          { exerciseId: 'hip', sets: 1, reps: 10, restSeconds: 60 },
        ],
      },
      composition,
    ).items as Record<string, unknown>[];
    expect(items).toEqual([
      expect.objectContaining({ exercisePosition: 0, exerciseId: 'squat', setPosition: 0 }),
      expect.objectContaining({ exercisePosition: 0, exerciseId: 'squat', setPosition: 1 }),
      // 60 kg × 10 : 90 % de la même charge, au 2,5 kg inférieur.
      expect.objectContaining({ exercisePosition: 1, exerciseId: 'hip', targetWeightKg: 52.5 }),
    ]);
    expect(items[0]).not.toHaveProperty('targetWeightKg');
  });

  it('une durée calculée jamais au-delà de ce que le validateur accepte', () => {
    // Six exercices de 6 × 30, 5 min de repos : 252 min.
    const six: CoachComposition = {
      candidates: ['a', 'b', 'c', 'd', 'e', 'f'].map((id) => ({
        id,
        name: id,
        muscle: null,
        equipment: [],
      })),
      minutes: null,
      context: [],
    };
    const choice = parseChoice(
      JSON.stringify({
        message: 'M',
        name: 'S',
        exercises: six.candidates.map((_, i) => ({
          id: `e${i + 1}`,
          sets: 6,
          reps: 30,
          rest: 300,
        })),
      }),
      six,
    );
    expect(choice?.estimatedMinutes).toBe(240);
  });
});
