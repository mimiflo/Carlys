import { type Request } from 'express';
import { routeLabel, UNMATCHED_ROUTE } from './route-label';

/**
 * Une requête réduite à ce que `routeLabel` lit. Le type d'Express déclare
 * `route: any` : cette fabrique évite d'en construire un exemplaire complet
 * pour trois champs.
 */
function fakeRequest(route: unknown, baseUrl = ''): Request {
  return { route, baseUrl } as unknown as Request;
}

describe('routeLabel', () => {
  it('rend le motif de la route trouvée, pas le chemin réel', () => {
    const label = routeLabel(fakeRequest({ path: '/api/v1/exercises/:id' }));

    expect(label).toBe('/api/v1/exercises/:id');
  });

  it('préfixe par baseUrl quand un routeur imbriqué a servi la requête', () => {
    expect(routeLabel(fakeRequest({ path: '/:id' }, '/api/v1/exercises'))).toBe(
      '/api/v1/exercises/:id',
    );
  });

  it('borne la cardinalité : toute requête sans route rend le même libellé', () => {
    expect(routeLabel(fakeRequest(undefined))).toBe(UNMATCHED_ROUTE);
    expect(routeLabel(fakeRequest(null))).toBe(UNMATCHED_ROUTE);
    expect(routeLabel(fakeRequest({}))).toBe(UNMATCHED_ROUTE);
    expect(routeLabel(fakeRequest({ path: '' }))).toBe(UNMATCHED_ROUTE);
    // Le cas qui compte : un balayage d'URL au hasard ne doit pas créer une
    // série temporelle par requête.
    expect(routeLabel(fakeRequest({ path: 42 }))).toBe(UNMATCHED_ROUTE);
  });

  it('retire la barre finale sans jamais vider le libellé de la racine', () => {
    expect(routeLabel(fakeRequest({ path: '/health/' }))).toBe('/health');
    expect(routeLabel(fakeRequest({ path: '/' }))).toBe('/');
  });
});
