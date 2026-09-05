import { type MessageWithProposal } from '../infrastructure/coach.repository';
import { assistantReplyTo, buildHistory, extractExerciseIds, titleFrom } from './coach.turn';

function message(role: 'USER' | 'ASSISTANT', id: string, content = id): MessageWithProposal {
  return {
    id,
    conversationId: 'fil-1',
    role,
    content,
    inputTokens: null,
    outputTokens: null,
    createdAt: new Date('2026-08-09T10:00:00.000Z'),
    proposal: null,
  };
}

describe('assistantReplyTo', () => {
  const question = message('USER', 'q1');
  const answer = message('ASSISTANT', 'r1');
  const later = message('USER', 'q2');

  it('rend la réponse qui suit immédiatement le message', () => {
    expect(assistantReplyTo([question, answer, later], question)).toBe(answer);
  });

  it('rien si le message est le dernier du fil (tour interrompu avant la réponse)', () => {
    expect(assistantReplyTo([question], question)).toBeUndefined();
  });

  it('rien si ce qui suit est une autre question : ce n’est pas sa réponse', () => {
    expect(
      assistantReplyTo([question, later, message('ASSISTANT', 'r2')], question),
    ).toBeUndefined();
  });

  it('rien si le message n’est pas dans le fil', () => {
    expect(assistantReplyTo([answer], question)).toBeUndefined();
  });
});

describe('buildHistory', () => {
  it('reprend les tours précédents et colle le rappel de date au DERNIER message seulement', () => {
    const now = new Date('2026-08-09T10:00:00.000Z');
    const history = buildHistory(
      [message('USER', 'q1', 'Bonjour'), message('ASSISTANT', 'r1', 'Salut.')],
      'Et maintenant ?',
      now,
    );

    expect(history.map((turn) => turn.role)).toEqual(['user', 'assistant', 'user']);
    expect(history[0]?.content).toBe('Bonjour');
    expect(history[2]?.content).toContain('Et maintenant ?');
    // Le préfixe cacheable ne bouge pas : la date n'est que dans le dernier tour.
    expect(history[2]?.content).not.toBe('Et maintenant ?');
    expect(history[0]?.content).toBe('Bonjour');
  });

  it('ne renvoie que les 20 derniers tours', () => {
    const many = Array.from({ length: 30 }, (_, index) => message('USER', `q${index}`));
    expect(buildHistory(many, 'Fin')).toHaveLength(21);
  });
});

describe('extractExerciseIds', () => {
  it('cite chaque identifiant une seule fois, ignore le reste', () => {
    expect(
      extractExerciseIds({
        items: [{ exerciseId: 'a' }, { exerciseId: 'a' }, { exerciseId: 7 }, null, { autre: 'b' }],
      }),
    ).toEqual(['a']);
    expect(extractExerciseIds({ items: 'pas une liste' })).toEqual([]);
  });
});

describe('titleFrom', () => {
  it('garde une question courte telle quelle, tronque une longue', () => {
    expect(titleFrom('  Où j’en suis ?  ')).toBe('Où j’en suis ?');
    const long = 'a'.repeat(80);
    expect(titleFrom(long)).toHaveLength(60);
    expect(titleFrom(long).endsWith('…')).toBe(true);
  });
});
