import { afterEach, describe, expect, it, vi } from 'vitest';
import { adminToken } from './admin-api';
import { ApiError } from './api-transport';
import { NETWORK_FAILURE_MESSAGE, publicApi, publicFailureMessage } from './public-api';

function requestOf(fetchMock: ReturnType<typeof vi.fn>): [string, RequestInit] {
  return fetchMock.mock.calls[0] as [string, RequestInit];
}

afterEach(() => {
  vi.unstubAllGlobals();
  adminToken.clear();
});

describe('API publique', () => {
  it('poste le jeton et le nouveau mot de passe vers /auth/reset-password', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    await expect(
      publicApi.resetPassword('jeton-123', 'motdepasse-solide'),
    ).resolves.toBeUndefined();

    const [url, init] = requestOf(fetchMock);
    expect(url).toBe('http://localhost:3000/api/v1/auth/reset-password');
    expect(init.method).toBe('POST');
    expect(JSON.parse(init.body as string)).toEqual({
      token: 'jeton-123',
      newPassword: 'motdepasse-solide',
    });
  });

  it('poste le jeton vers /auth/verify-email', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    await expect(publicApi.verifyEmail('jeton-123')).resolves.toBeUndefined();

    const [url, init] = requestOf(fetchMock);
    expect(url).toBe('http://localhost:3000/api/v1/auth/verify-email');
    expect(JSON.parse(init.body as string)).toEqual({ token: 'jeton-123' });
  });

  it('n’envoie JAMAIS le jeton d’administration, même s’il traîne dans l’onglet', async () => {
    adminToken.set('jeton-admin');
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    await publicApi.verifyEmail('jeton-123');

    const [, init] = requestOf(fetchMock);
    expect(Object.keys(init.headers as Record<string, string>)).not.toContain('Authorization');
  });

  it('remonte le refus du serveur avec son statut', async () => {
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(
          new Response(
            JSON.stringify({ error: { message: 'Lien de réinitialisation invalide ou expiré.' } }),
            { status: 401, headers: { 'Content-Type': 'application/json' } },
          ),
        ),
    );

    const failure: unknown = await publicApi
      .resetPassword('jeton-mort', 'motdepasse-solide')
      .catch((cause: unknown) => cause);

    expect(failure).toBeInstanceOf(ApiError);
    expect((failure as ApiError).status).toBe(401);
  });
});

describe('publicFailureMessage', () => {
  it('donne la formulation de la page pour un statut qu’elle connaît', () => {
    expect(publicFailureMessage(new ApiError('x', 401), { 401: 'Lien mort.' })).toBe('Lien mort.');
  });

  it('parle de connexion quand l’échec ne vient pas d’une réponse de l’API', () => {
    expect(publicFailureMessage(new TypeError('Failed to fetch'), {})).toBe(
      NETWORK_FAILURE_MESSAGE,
    );
  });

  it('nomme les tentatives trop nombreuses (429) et reste générique sinon', () => {
    expect(publicFailureMessage(new ApiError('x', 429), {})).toMatch(/trop de tentatives/i);
    expect(publicFailureMessage(new ApiError('x', 500), {})).toMatch(/réessaie/i);
  });
});
