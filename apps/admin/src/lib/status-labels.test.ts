import { describe, expect, it } from 'vitest';
import {
  entitlementStatus,
  healthStatus,
  planStatus,
  reportStatus,
  userStatus,
} from './status-labels';

describe('les statuts parlent français, jamais en constante', () => {
  it('compte', () => {
    expect(userStatus('ACTIVE')).toEqual({ label: 'Actif', tone: 'success' });
    expect(userStatus('SUSPENDED')).toEqual({ label: 'Suspendu', tone: 'warning' });
    expect(userStatus('DELETED')).toEqual({ label: 'Supprimé', tone: 'neutral' });
  });

  it('plan et signalement', () => {
    expect(planStatus(true).label).toBe('Premium');
    expect(planStatus(false).label).toBe('Gratuit');
    expect(reportStatus('OPEN')).toEqual({ label: 'Ouvert', tone: 'warning' });
    expect(reportStatus('RESOLVED')).toEqual({ label: 'Résolu', tone: 'success' });
  });

  it('un droit coupé à la main n’est pas un droit simplement fermé', () => {
    const base = { key: 'coach_ai', expiresAt: null } as const;
    expect(
      entitlementStatus({ ...base, isActive: false, source: 'MANUAL_REVOCATION' } as never).label,
    ).toBe('Coupé');
    expect(entitlementStatus({ ...base, isActive: false, source: 'NONE' } as never).label).toBe(
      'Inactif',
    );
    expect(
      entitlementStatus({ ...base, isActive: true, source: 'SUBSCRIPTION' } as never).label,
    ).toBe('Actif');
  });

  it('santé', () => {
    expect(healthStatus(true).label).toBe('En service');
    expect(healthStatus(false)).toEqual({ label: 'Indisponible', tone: 'danger' });
  });
});
