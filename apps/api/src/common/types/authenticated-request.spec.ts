import { clientContextOf } from './authenticated-request';
import { type RequestWithId } from './request-with-id';

function fakeRequest(overrides: Record<string, unknown> = {}): RequestWithId {
  return {
    ip: '203.0.113.7',
    headers: { 'user-agent': 'Carlys/1.0 (Android)' },
    ...overrides,
  } as unknown as RequestWithId;
}

/**
 * CE QUE CE FICHIER PROTÈGE : la corrélation. Vingt-sept écritures d'audit
 * passent ce contexte tel quel, et la plus sensible d'entre elles — la
 * réutilisation d'un jeton de rafraîchissement — n'a d'intérêt que si on peut
 * la rapprocher des lignes Pino de la requête qui l'a provoquée. La colonne
 * existait, le service l'acceptait, mais ce contexte ne la remplissait pas :
 * elle valait `null` partout.
 */
describe('clientContextOf', () => {
  it('emporte le requestId de la requête', () => {
    expect(clientContextOf(fakeRequest({ id: 'req-abc123' })).requestId).toBe('req-abc123');
  });

  it('accepte un identifiant numérique (pino-http en émet)', () => {
    expect(clientContextOf(fakeRequest({ id: 42 })).requestId).toBe('42');
  });

  it('ne rend jamais null : « unknown » plutôt qu’un trou', () => {
    // Un audit sans corrélation reste lisible ; un `null` silencieux laissait
    // croire que la corrélation existait ailleurs.
    expect(clientContextOf(fakeRequest()).requestId).toBe('unknown');
  });

  it('emporte toujours l’adresse et l’agent, tronqué à 400 caractères', () => {
    const context = clientContextOf(
      fakeRequest({ id: 'r', headers: { 'user-agent': 'x'.repeat(500) } }),
    );
    expect(context.ipAddress).toBe('203.0.113.7');
    expect(context.userAgent).toHaveLength(400);
  });
});
