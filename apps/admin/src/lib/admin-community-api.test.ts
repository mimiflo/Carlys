import { afterEach, describe, expect, it, vi } from 'vitest';
import { AdminApiError, adminApi, adminToken } from './admin-api';

/**
 * Signalements : routes portées par `admin-community-api.ts`, appelées ici
 * PAR `adminApi` — le test défend donc aussi leur étalement dans l'objet, ce
 * dont dépendent les `vi.spyOn(adminApi, …)` des tests de page.
 */

const REPORTER = {
  id: '11111111-2222-4333-8444-555555555555',
  email: 'membre@carlys.test',
  displayName: 'Membre',
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

const REPORT = {
  id: '77777777-2222-4333-8444-555555555555',
  reportedUserId: '22222222-2222-4333-8444-555555555555',
  encouragementId: '33333333-2222-4333-8444-555555555555',
  reason: 'HARCELEMENT',
  details: 'Il insiste après mon refus.',
  status: 'OPEN',
  createdAt: '2026-09-01T10:00:00.000Z',
  resolvedAt: null,
  reporter: REPORTER,
  reportedUser: {
    id: '22222222-2222-4333-8444-555555555555',
    email: 'vise@carlys.test',
    displayName: null,
  },
  encouragementMessage: 'Réponds-moi.',
};

/**
 * Les signalements sont lus et résolus par la page « Signalements » : c'est
 * ici que se joue le contrat exact avec `/admin/community/reports` (filtre,
 * curseur, corps du PATCH) et la validation de la réponse.
 */
describe('signalements de la communauté', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    adminToken.clear();
  });

  it('liste avec le filtre de statut et la taille de page, sans curseur au premier appel', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(respond({ data: [REPORT], meta: { nextCursor: null, hasMore: false } }));
    vi.stubGlobal('fetch', fetchMock);

    const page = await adminApi.listCommunityReports('OPEN');

    const [url] = requestOf(fetchMock);
    expect(url).toBe('http://localhost:3000/api/v1/admin/community/reports?status=OPEN&limit=50');
    expect(page.items).toHaveLength(1);
    expect(page.items[0]?.reporter.email).toBe(REPORTER.email);
    expect(page.items[0]?.encouragementMessage).toBe('Réponds-moi.');
    expect(page.hasMore).toBe(false);
  });

  it('sans statut, ne filtre pas ; avec curseur, le transmet', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(respond({ data: [], meta: { nextCursor: REPORT.id, hasMore: true } }));
    vi.stubGlobal('fetch', fetchMock);

    const page = await adminApi.listCommunityReports(undefined, REPORT.id);

    const [url] = requestOf(fetchMock);
    expect(url).toBe(
      `http://localhost:3000/api/v1/admin/community/reports?cursor=${REPORT.id}&limit=50`,
    );
    expect(page.hasMore).toBe(true);
    expect(page.nextCursor).toBe(REPORT.id);
  });

  it('résout par un PATCH portant le statut, et rend le signalement validé', async () => {
    adminToken.set('jeton-admin');
    const resolved = { ...REPORT, status: 'RESOLVED', resolvedAt: '2026-09-02T08:00:00.000Z' };
    const fetchMock = vi.fn().mockResolvedValue(respond({ data: resolved, meta: {} }));
    vi.stubGlobal('fetch', fetchMock);

    const report = await adminApi.setCommunityReportStatus(REPORT.id, 'RESOLVED');

    const [url, init] = requestOf(fetchMock);
    expect(url).toBe(`http://localhost:3000/api/v1/admin/community/reports/${REPORT.id}`);
    expect(init.method).toBe('PATCH');
    expect(JSON.parse(init.body as string)).toEqual({ status: 'RESOLVED' });
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer jeton-admin');
    expect(report.status).toBe('RESOLVED');
    expect(report.resolvedAt).toBe('2026-09-02T08:00:00.000Z');
  });

  it('refuse un signalement qui ne respecte pas le contrat (auteur absent)', async () => {
    // `JSON.stringify` omet la clé à `undefined` : le corps arrive SANS `reporter`.
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(respond({ data: [{ ...REPORT, reporter: undefined }], meta: {} })),
    );

    await expect(adminApi.listCommunityReports('OPEN')).rejects.toBeInstanceOf(AdminApiError);
  });
});
