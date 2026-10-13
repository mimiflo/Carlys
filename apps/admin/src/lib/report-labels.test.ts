import type { AdminCommunityReport } from '@carlys/api-contracts';
import { describe, expect, it } from 'vitest';
import { contentStillThere, decisionSummary, reportTarget } from './report-labels';

const BASE = {
  encouragementId: null,
  encouragementMessage: null,
  friendChallengeId: null,
  friendChallengeTitle: null,
  friendChallengeMessage: null,
  friendChallengeMessageRemoved: false,
  contentRemoved: false,
  userSuspended: false,
} as unknown as AdminCommunityReport;

describe('report-labels', () => {
  it('reconnaît la cible et si son contenu existe encore', () => {
    expect(reportTarget(BASE)).toBe('person');
    expect(contentStillThere(BASE)).toBe(false);

    const mot = { ...BASE, encouragementId: 'e1', encouragementMessage: 'Nul.' };
    expect(reportTarget(mot)).toBe('encouragement');
    expect(contentStillThere(mot)).toBe(true);
    expect(contentStillThere({ ...mot, encouragementId: null })).toBe(false);

    const defi = {
      ...BASE,
      friendChallengeId: 'c1',
      friendChallengeTitle: 'Dix séances',
      friendChallengeMessage: 'Perdant.',
    };
    expect(reportTarget(defi)).toBe('challenge');
    expect(contentStillThere(defi)).toBe(true);
    expect(contentStillThere({ ...defi, friendChallengeMessageRemoved: true })).toBe(false);
    expect(contentStillThere({ ...defi, friendChallengeMessage: null })).toBe(false);
    expect(contentStillThere({ ...defi, friendChallengeId: null })).toBe(false);
  });

  it('résume la décision', () => {
    expect(decisionSummary(BASE)).toBe('Classé sans suite');
    expect(decisionSummary({ ...BASE, contentRemoved: true })).toBe('Contenu retiré');
    expect(decisionSummary({ ...BASE, contentRemoved: true, userSuspended: true })).toBe(
      'Contenu retiré et compte suspendu',
    );
  });
});
