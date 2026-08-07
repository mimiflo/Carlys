import { managedUserSummarySchema } from '@carlys/api-contracts';
import { describe, expect, it } from 'vitest';
import { AdminApiError, parseData, parsePage } from './admin-api';

const USER = {
  id: '11111111-2222-4333-8444-555555555555',
  email: 'membre@carlys.test',
  displayName: 'Membre',
  status: 'ACTIVE',
  emailVerified: true,
  isPremium: false,
  createdAt: '2026-08-07T10:00:00.000Z',
};

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
