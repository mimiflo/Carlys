import {
  MONTHLY_CHALLENGE_CATALOG,
  buildMonthlyChallenges,
  monthWindowUtc,
} from './challenge-catalog';

describe('monthWindowUtc', () => {
  it('découpe le mois en UTC, du 1er minuit au 1er du mois suivant', () => {
    const window = monthWindowUtc(new Date('2026-09-15T13:45:00Z'));
    expect(window).toEqual({
      month: '2026-09',
      startsAt: new Date('2026-09-01T00:00:00Z'),
      endsAt: new Date('2026-10-01T00:00:00Z'),
    });
  });

  it('passe l’année en décembre', () => {
    const window = monthWindowUtc(new Date('2026-12-31T23:59:59Z'));
    expect(window.month).toBe('2026-12');
    expect(window.endsAt).toEqual(new Date('2027-01-01T00:00:00Z'));
  });

  it('le mois est celui d’UTC, pas celui d’un fuseau local', () => {
    // 23 h 30 UTC le 31 août : à Paris on est déjà le 1er septembre, mais le
    // calendrier collectif est UTC : le défi d'août court encore.
    expect(monthWindowUtc(new Date('2026-08-31T23:30:00Z')).month).toBe('2026-08');
  });
});

describe('buildMonthlyChallenges', () => {
  it('produit tout le catalogue, daté du mois demandé', () => {
    const seeds = buildMonthlyChallenges(new Date('2026-02-10T08:00:00Z'));

    expect(seeds).toHaveLength(MONTHLY_CHALLENGE_CATALOG.length);
    for (const seed of seeds) {
      expect(seed.month).toBe('2026-02');
      expect(seed.startsAt).toEqual(new Date('2026-02-01T00:00:00Z'));
      expect(seed.endsAt).toEqual(new Date('2026-03-01T00:00:00Z'));
      expect(seed.target).toBeGreaterThan(0);
    }
  });

  it('les slugs du catalogue sont uniques : c’est la clé d’idempotence du mois', () => {
    const slugs = MONTHLY_CHALLENGE_CATALOG.map((template) => template.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
  });

  it('les textes visibles tutoient et n’emploient pas de tiret cadratin', () => {
    for (const template of MONTHLY_CHALLENGE_CATALOG) {
      expect(`${template.title} ${template.description}`).not.toContain('—');
      expect(template.description).not.toMatch(/\bvous\b/i);
    }
  });
});
