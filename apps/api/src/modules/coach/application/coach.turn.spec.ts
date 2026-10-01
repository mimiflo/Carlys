import { type MessageWithProposal } from '../infrastructure/coach.repository';
import { buildHistory, extractExerciseIds, titleFrom } from './coach.turn';

function message(
  role: 'USER' | 'ASSISTANT',
  id: string,
  content = id,
  createdAt = new Date('2026-08-09T10:00:00.000Z'),
): MessageWithProposal {
  return {
    id,
    conversationId: 'fil-1',
    role,
    content,
    inputTokens: null,
    outputTokens: null,
    createdAt,
    proposal: null,
    programProposal: null,
  };
}

describe('buildHistory', () => {
  it('reprend les tours précédents et colle le rappel de date au DERNIER message seulement', () => {
    const now = new Date('2026-08-09T10:00:00.000Z');
    const history = buildHistory(
      [message('USER', 'q1', 'Bonjour'), message('ASSISTANT', 'r1', 'Salut.')],
      'Et maintenant ?',
      20,
      null,
      now,
    );

    expect(history.map((turn) => turn.role)).toEqual(['user', 'assistant', 'user']);
    expect(history[0]?.content).toBe('Bonjour');
    expect(history[2]?.content).toContain('Et maintenant ?');
    // Le préfixe cacheable ne bouge pas : la date n'est que dans le dernier tour.
    expect(history[2]?.content).not.toBe('Et maintenant ?');
    expect(history[0]?.content).toBe('Bonjour');
  });

  it('ne renvoie que les N derniers tours (COACH_HISTORY_MESSAGES)', () => {
    const many = Array.from({ length: 30 }, (_, index) => message('USER', `q${index}`));
    expect(buildHistory(many, 'Fin', 20)).toHaveLength(21);
    expect(buildHistory(many, 'Fin', 12)).toHaveLength(13);
  });

  it('ne reprend que ce que la mémoire n’a pas résumé : le début ne bouge qu’avec elle', () => {
    const minute = (m: number) => new Date(Date.UTC(2026, 8, 1, 10, m));
    const fil = Array.from({ length: 16 }, (_, i) =>
      message(i % 2 === 0 ? 'USER' : 'ASSISTANT', `m${i}`, `m${i}`, minute(i)),
    );

    // Résumé jusqu'à m9 : l'historique repart de m10, pas des 12 derniers.
    const history = buildHistory(fil, 'Suite', 12, minute(9));
    expect(history.map((turn) => turn.content).slice(0, -1)).toEqual([
      'm10',
      'm11',
      'm12',
      'm13',
      'm14',
      'm15',
    ]);

    // Le tour suivant PROLONGE le précédent : même début, Ollama ne relit que la fin.
    const next = buildHistory(
      [
        ...fil,
        message('USER', 'm16', 'm16', minute(16)),
        message('ASSISTANT', 'm17', 'm17', minute(17)),
      ],
      'Encore',
      12,
      minute(9),
    );
    expect(next.slice(0, 6)).toEqual(history.slice(0, 6));

    // Mémoire en retard : le plafond de la fenêtre reprend la main.
    expect(buildHistory(fil, 'Suite', 4, minute(1))).toHaveLength(5);
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

    const history = buildHistory(fil, 'Nouvelle question', 20);

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
