import type { ManagedEntitlement } from '@carlys/api-contracts';
import { describe, expect, it } from 'vitest';
import { paidSubscriptionSentence, premiumStateSentence, sourceLabel } from './entitlement-labels';

const BASE: ManagedEntitlement = {
  key: 'premium_exercises',
  isActive: true,
  expiresAt: null,
  source: 'SUBSCRIPTION',
  provider: 'APP_STORE',
};

describe('origine d’un droit', () => {
  it('nomme le fournisseur d’un accès payé', () => {
    expect(sourceLabel(BASE)).toBe('abonnement App Store');
    expect(premiumStateSentence(BASE)).toBe(
      'Ouvert par l’abonnement App Store : il suit les paiements.',
    );
  });

  it('un abonnement qui ne paie plus ferme l’accès, et le dit', () => {
    expect(premiumStateSentence({ ...BASE, isActive: false })).toBe(
      'Fermé : l’abonnement App Store ne l’ouvre plus.',
    );
  });

  it('distingue une offre sans échéance, une offre datée et une offre échue', () => {
    const offert: ManagedEntitlement = { ...BASE, source: 'MANUAL_GRANT', provider: undefined };
    expect(premiumStateSentence(offert)).toMatch(/sans échéance/);
    expect(premiumStateSentence({ ...offert, expiresAt: '2026-12-31T12:00:00.000Z' })).toBe(
      'Offert à la main par l’administration jusqu’au 31/12/2026.',
    );
    expect(
      premiumStateSentence({ ...offert, isActive: false, expiresAt: '2026-01-31T12:00:00.000Z' }),
    ).toBe('L’offre manuelle a pris fin le 31/01/2026.');
  });

  it('une coupure dit qu’elle bloque les achats', () => {
    const coupe: ManagedEntitlement = {
      ...BASE,
      isActive: false,
      source: 'MANUAL_REVOCATION',
      provider: undefined,
    };
    expect(sourceLabel(coupe)).toBe('coupé à la main');
    expect(premiumStateSentence(coupe)).toMatch(/bloque les achats/);
  });

  it('résume l’abonnement payé : fournisseur, statut, échéance, résiliation', () => {
    expect(
      paidSubscriptionSentence({
        provider: 'PLAY_STORE',
        status: 'PAST_DUE',
        currentPeriodEnd: '2026-10-07T12:00:00.000Z',
        cancelAtPeriodEnd: true,
      }),
    ).toBe(
      'Abonnement Google Play paiement en retard, période payée jusqu’au 07/10/2026, résilié à l’échéance.',
    );
  });
});
