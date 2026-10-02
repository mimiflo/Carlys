import { ContextBudget } from './context-budget';

const turn = (role: 'user' | 'assistant', words: number) => ({
  role,
  content: 'mot '.repeat(words),
});

describe('ContextBudget — la place de la réponse, toujours gardée', () => {
  it('l’historique le plus ancien cède, la dernière question jamais', () => {
    const budget = new ContextBudget(2_048, []);
    const system = [{ role: 'system', content: 'Tu es le coach.' }];
    // Douze échanges d'environ 270 jetons : bien plus que le contexte.
    const history = Array.from({ length: 24 }, (_, i) =>
      turn(i % 2 === 0 ? 'user' : 'assistant', 200),
    );
    history.push(turn('user', 10));
    const after = [{ role: 'tool', content: '{"records":[]}' }];
    const messages = [...system, ...history, ...after];

    const removed = budget.trim(messages, system.length, history.length, 512);

    expect(removed).toBeGreaterThan(0);
    expect(messages).toHaveLength(system.length + history.length - removed + after.length);
    // Les consignes et les lectures restent ; l'historique repart d'une question.
    expect(messages[0]).toBe(system[0]);
    expect(messages.at(-1)).toBe(after[0]);
    expect(messages.at(-2)).toBe(history.at(-1));
    expect(messages[1]?.role).toBe('user');
    expect(budget.room(messages)).toBeGreaterThanOrEqual(512);
  });

  it('un historique court reste entier', () => {
    const budget = new ContextBudget(8_192, []);
    const messages = [turn('user', 5), turn('assistant', 5), turn('user', 5)];
    expect(budget.trim(messages, 0, 3, 2_048)).toBe(0);
    expect(messages).toHaveLength(3);
  });

  it('se recale sur le compte exact du moteur', () => {
    const budget = new ContextBudget(8_192, []);
    const messages = [{ role: 'user', content: 'x'.repeat(3_000) }];
    const estimated = budget.tokens(messages);

    budget.calibrate(messages, estimated * 2);

    // Au jeton près : l'arrondi du calcul en virgule flottante.
    expect(Math.abs(budget.tokens(messages) - estimated * 2)).toBeLessThanOrEqual(1);
    expect(budget.tokens([{ role: 'user', content: 'x'.repeat(6_000) }])).toBeGreaterThan(
      estimated * 3,
    );
  });
});
