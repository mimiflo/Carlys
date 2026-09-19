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

  it('la fenêtre s’OUVRE sur un tour utilisateur, même si la découpe tombe mal', () => {
    // L'API du modèle refuse un historique commençant par une réponse — et ce
    // refus arrive APRÈS que le quota du jour a été décompté. Un tour
    // interrompu (la réponse jamais archivée) laisse un message utilisateur
    // orphelin qui retourne la parité du fil : la découpe des 20 derniers
    // pouvait alors commencer sur un `assistant`.
    const fil = Array.from({ length: 40 }, (_, index) =>
      message(index % 2 === 0 ? 'USER' : 'ASSISTANT', `m${index}`),
    );
    // Un message utilisateur orphelin en fin de fil : la parité bascule.
    fil.push(message('USER', 'orphelin'));

    const history = buildHistory(fil, 'Nouvelle question');

    expect(history[0]?.role).toBe('user');
    // Au pire UN tour d'historique sacrifié, jamais plus.
    expect(history.length).toBeGreaterThanOrEqual(20);
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
