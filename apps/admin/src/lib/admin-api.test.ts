import { managedUserSummarySchema } from '@carlys/api-contracts';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminApiError, adminApi, adminToken, parseData, parsePage } from './admin-api';

const USER = {
  id: '11111111-2222-4333-8444-555555555555',
  email: 'membre@carlys.test',
  displayName: 'Membre',
  status: 'ACTIVE',
  emailVerified: true,
  isPremium: false,
  createdAt: '2026-08-07T10:00:00.000Z',
};

const ME = {
  id: '99999999-2222-4333-8444-555555555555',
  email: 'admin@carlys.test',
  displayName: 'Admin',
  roles: ['support'],
  permissions: ['user:read'],
};

function respond(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function requestOf(fetchMock: ReturnType<typeof vi.fn>): [string, RequestInit] {
  return fetchMock.mock.calls[0] as [string, RequestInit];
}

describe('parseData', () => {
  it('extrait et valide data depuis l’enveloppe de succès', () => {
    const body = { data: USER, meta: {}, requestId: 'req-1' };

    const parsed = parseData(body, managedUserSummarySchema);

    expect(parsed.email).toBe('membre@carlys.test');
  });

  it('rejette une enveloppe absente ou un contrat cassé — jamais silencieux', () => {
    expect(() => parseData(USER, managedUserSummarySchema)).toThrow(AdminApiError);
    expect(() =>
      parseData({ data: { ...USER, status: 'INCONNU' } }, managedUserSummarySchema),
    ).toThrow(AdminApiError);
  });
});

describe('parsePage', () => {
  it('associe data et méta de pagination par curseur', () => {
    const body = {
      data: [USER],
      meta: { nextCursor: USER.id, hasMore: true },
      requestId: 'req-1',
    };

    const page = parsePage(body, managedUserSummarySchema);

    expect(page.items).toHaveLength(1);
    expect(page.hasMore).toBe(true);
    expect(page.nextCursor).toBe(USER.id);
  });

  it('tolère une méta absente (page unique)', () => {
    const page = parsePage({ data: [] }, managedUserSummarySchema);

    expect(page.items).toHaveLength(0);
    expect(page.hasMore).toBe(false);
    expect(page.nextCursor).toBeNull();
  });
});

/**
 * Le transport JSON porte TOUTES les requêtes du back-office : c'est lui qui
 * attache le jeton, qui lit (ou non) le corps, et qui traduit un refus du
 * serveur en erreur exploitable par l'interface.
 */
describe('transport JSON', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    adminToken.clear();
  });

  it('porte le jeton d’administration en Authorization: Bearer quand il existe', async () => {
    adminToken.set('jeton-admin');
    const fetchMock = vi.fn().mockResolvedValue(respond({ data: ME }));
    vi.stubGlobal('fetch', fetchMock);

    await adminApi.me();

    const [url, init] = requestOf(fetchMock);
    const headers = init.headers as Record<string, string>;
    expect(url).toBe('http://localhost:3000/api/v1/admin/auth/me');
    expect(headers.Authorization).toBe('Bearer jeton-admin');
    expect(headers['Content-Type']).toBe('application/json');
    expect(init.cache).toBe('no-store');
  });

  it('n’envoie AUCUN en-tête Authorization sans jeton', async () => {
    const fetchMock = vi.fn().mockResolvedValue(respond({ data: ME }));
    vi.stubGlobal('fetch', fetchMock);

    await adminApi.me();

    const [, init] = requestOf(fetchMock);
    expect(Object.keys(init.headers as Record<string, string>)).not.toContain('Authorization');
  });

  it('rend null sur un 204 sans jamais tenter de lire un corps', async () => {
    // Un `Response` réel refuse un corps sur 204 ; on vérifie ici que le
    // transport ne l'appelle même pas, plutôt que de compter sur `catch`.
    const json = vi.fn().mockRejectedValue(new Error('corps lu sur un 204'));
    const response = { ok: true, status: 204, json } as unknown as Response;
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(response));

    await expect(adminApi.deleteExercise('ex-1')).resolves.toBeUndefined();

    expect(json).not.toHaveBeenCalled();
  });

  it('traduit l’enveloppe d’erreur en AdminApiError : message du serveur, statut HTTP', async () => {
    // C'est ce `status` que l'interface lit pour distinguer un refus de
    // permission (403) d'une panne, et ce `message` qu'elle peut relayer.
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(
        respond(
          {
            error: {
              code: 'FORBIDDEN',
              message: 'Permission entitlement:grant requise.',
              details: [],
              requestId: 'req-1',
            },
          },
          403,
        ),
      ),
    );

    const failure: unknown = await adminApi
      .setEntitlement(USER.id, 'premium_exercises', true)
      .catch((cause: unknown) => cause);

    expect(failure).toBeInstanceOf(AdminApiError);
    expect((failure as AdminApiError).status).toBe(403);
    expect((failure as AdminApiError).message).toBe('Permission entitlement:grant requise.');
  });

  it('sans enveloppe lisible (proxy, HTML), garde le statut et un message générique', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(new Response('<html>Bad gateway</html>', { status: 502 })),
    );

    const failure: unknown = await adminApi.overview().catch((cause: unknown) => cause);

    expect(failure).toBeInstanceOf(AdminApiError);
    expect((failure as AdminApiError).status).toBe(502);
    expect((failure as AdminApiError).message).toBe('Erreur 502');
  });
});
