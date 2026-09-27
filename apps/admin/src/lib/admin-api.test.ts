import {
  managedEntitlementDecisionSchema,
  managedUserSummarySchema,
  PREMIUM_ENTITLEMENT_KEYS,
} from '@carlys/api-contracts';
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
      .setEntitlement(USER.id, { key: 'premium_exercises', isActive: true })
      .catch((cause: unknown) => cause);

    expect(failure).toBeInstanceOf(AdminApiError);
    expect((failure as AdminApiError).status).toBe(403);
    expect((failure as AdminApiError).message).toBe('Permission entitlement:grant requise.');
  });

  it('coupe un droit avec sa raison, et le rend à l’abonnement par DELETE', async () => {
    const detail = {
      ...USER,
      sessionsCount: 0,
      completedWorkoutsCount: 0,
      entitlements: [],
      paidSubscription: null,
    };
    const fetchMock = vi.fn().mockImplementation(() => Promise.resolve(respond({ data: detail })));
    vi.stubGlobal('fetch', fetchMock);

    await adminApi.setEntitlement(USER.id, {
      key: 'premium_exercises',
      isActive: false,
      reason: 'Fraude',
    });
    await adminApi.releaseEntitlement(USER.id, 'premium_exercises');

    const [putUrl, put] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(putUrl).toBe(`http://localhost:3000/api/v1/admin/users/${USER.id}/entitlements`);
    expect(put.method).toBe('PUT');
    expect(JSON.parse(put.body as string)).toEqual({
      key: 'premium_exercises',
      isActive: false,
      reason: 'Fraude',
    });
    const [deleteUrl, remove] = fetchMock.mock.calls[1] as [string, RequestInit];
    expect(deleteUrl).toBe(
      `http://localhost:3000/api/v1/admin/users/${USER.id}/entitlements/premium_exercises`,
    );
    expect(remove.method).toBe('DELETE');
  });

  /**
   * « Premium » est tout le plan : une coupure qui ne visait que
   * `premium_exercises` laissait le coach IA et les programmes illimités ouverts.
   */
  it('le premium se décide sur chaque droit du plan, l’un après l’autre, et s’arrête au premier refus', async () => {
    const detail = {
      ...USER,
      sessionsCount: 0,
      completedWorkoutsCount: 0,
      entitlements: [],
      paidSubscription: null,
    };
    const fetchMock = vi.fn().mockImplementation(() => Promise.resolve(respond({ data: detail })));
    vi.stubGlobal('fetch', fetchMock);

    await adminApi.setPremium(USER.id, { isActive: false, reason: 'Fraude' });
    await adminApi.releasePremium(USER.id);

    const calls = fetchMock.mock.calls as [string, RequestInit][];
    expect(calls.slice(0, 6).map(([, init]) => JSON.parse(init.body as string) as unknown)).toEqual(
      PREMIUM_ENTITLEMENT_KEYS.map((key) => ({ key, isActive: false, reason: 'Fraude' })),
    );
    expect(calls.slice(6).map(([url, init]) => `${init.method} ${url}`)).toEqual(
      PREMIUM_ENTITLEMENT_KEYS.map(
        (key) => `DELETE http://localhost:3000/api/v1/admin/users/${USER.id}/entitlements/${key}`,
      ),
    );

    fetchMock.mockClear();
    fetchMock
      .mockImplementationOnce(() => Promise.resolve(respond({ data: detail })))
      .mockImplementationOnce(() => Promise.resolve(new Response('', { status: 502 })));
    await expect(adminApi.setPremium(USER.id, { isActive: true })).rejects.toBeInstanceOf(
      AdminApiError,
    );
    expect(fetchMock).toHaveBeenCalledTimes(2);
  });

  /**
   * L'API refuse une coupure sans raison (400) : le client ne doit même pas
   * pouvoir l'écrire. `Omit<…, 'key'>` sur l'union du contrat effaçait la
   * distinction, et `{ isActive: false }` compilait.
   */
  it('couper sans raison ne compile pas, et le contrat le refuse', () => {
    // @ts-expect-error — une coupure exige sa raison (contrat `managedEntitlementDecisionSchema`).
    const sansRaison: Parameters<typeof adminApi.setPremium>[1] = { isActive: false };
    expect(managedEntitlementDecisionSchema.safeParse(sansRaison).success).toBe(false);
    expect(
      managedEntitlementDecisionSchema.safeParse({ isActive: false, reason: '   ' }).success,
    ).toBe(false);
    expect(managedEntitlementDecisionSchema.safeParse({ isActive: true }).success).toBe(true);
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

/**
 * Le jeton vit douze heures et la coquille ne vérifiait que sa PRÉSENCE : un
 * onglet resté ouvert, ou un compte désactivé, recevait des 401 partout sans
 * jamais revenir à la connexion. Un 401 sur une requête qui portait un jeton
 * termine désormais la session, quelle que soit la route.
 */
describe('fin de session sur 401', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    adminToken.clear();
  });

  const refus = (status: number) =>
    respond({ error: { code: 'X', message: 'Refus.', details: [], requestId: 'r' } }, status);

  it('un 401 avec jeton oublie le jeton et marque la session comme expirée', async () => {
    adminToken.set('jeton-perime');
    const ecoute = vi.fn();
    const desabonne = adminToken.subscribe(ecoute);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(refus(401)));

    await expect(adminApi.overview()).rejects.toMatchObject({ status: 401 });

    expect(adminToken.get()).toBeNull();
    expect(adminToken.wasExpired()).toBe(true);
    expect(ecoute).toHaveBeenCalled();
    desabonne();
  });

  it('vaut aussi pour un dépôt de fichier', async () => {
    adminToken.set('jeton-perime');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(refus(401)));

    await expect(
      adminApi.uploadMedia(new File(['x'], 'a.webp'), 'IMAGE', 'id-1'),
    ).rejects.toMatchObject({ status: 401 });

    expect(adminToken.get()).toBeNull();
  });

  it('un 403 laisse la session intacte : c’est le rôle, pas la session', async () => {
    adminToken.set('jeton-admin');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(refus(403)));

    await expect(adminApi.overview()).rejects.toMatchObject({ status: 403 });

    expect(adminToken.get()).toBe('jeton-admin');
    expect(adminToken.wasExpired()).toBe(false);
  });

  it('la connexion part SANS jeton : un mot de passe faux n’est pas une fin de session', async () => {
    adminToken.set('jeton-perime-reste-dans-l-onglet');
    const fetchMock = vi.fn().mockResolvedValue(refus(401));
    vi.stubGlobal('fetch', fetchMock);

    await expect(adminApi.login('a@carlys.test', 'mauvais-mdp')).rejects.toMatchObject({
      status: 401,
    });

    const [, init] = requestOf(fetchMock);
    expect(Object.keys(init.headers as Record<string, string>)).not.toContain('Authorization');
    expect(adminToken.wasExpired()).toBe(false);
  });

  it('une nouvelle connexion efface la marque d’expiration', () => {
    adminToken.expire();
    expect(adminToken.wasExpired()).toBe(true);

    adminToken.set('jeton-neuf');

    expect(adminToken.wasExpired()).toBe(false);
  });
});
