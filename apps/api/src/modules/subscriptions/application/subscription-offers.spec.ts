import { buildOfferCatalog } from './subscription-offers';

/**
 * Le catalogue d'offres.
 *
 * Un prix affiché est une promesse : ce qui se calcule ne doit jamais se
 * saisir, sans quoi un rabais survit à un changement de tarif et ment.
 */
describe('buildOfferCatalog', () => {
  const base = { currency: 'EUR', monthlyCents: 999, yearlyCents: 7990, trialDays: 7 };

  it('ramène l’annuel au mois pour que la comparaison soit possible', () => {
    const [, yearly] = buildOfferCatalog(base);

    expect(yearly?.monthlyEquivalentCents).toBe(666);
    expect(yearly?.amountCents).toBe(7990);
  });

  it('déduit l’économie des deux prix, et met l’annuel en avant', () => {
    const [monthly, yearly] = buildOfferCatalog(base);

    expect(yearly?.savingPercent).toBe(33);
    expect(yearly?.isRecommended).toBe(true);
    // Le mensuel n'affiche jamais d'économie : il est la référence.
    expect(monthly?.savingPercent).toBeNull();
    expect(monthly?.isRecommended).toBe(false);
  });

  it('sans avantage réel, aucun badge et aucune recommandation', () => {
    // Douze mensualités pour un an : annoncer « 0 % offert » ou recommander
    // l'annuel sans raison décrédibiliserait tout le reste de l'écran.
    const [, yearly] = buildOfferCatalog({ ...base, yearlyCents: 999 * 12 });

    expect(yearly?.savingPercent).toBeNull();
    expect(yearly?.isRecommended).toBe(false);
  });

  it('un annuel PLUS cher que douze mois ne se déguise pas en économie', () => {
    const [, yearly] = buildOfferCatalog({ ...base, yearlyCents: 15000 });

    expect(yearly?.savingPercent).toBeNull();
  });

  it('la période d’essai configurée vaut pour les deux offres', () => {
    const offers = buildOfferCatalog({ ...base, trialDays: 14 });

    expect(offers.map((offer) => offer.trialDays)).toEqual([14, 14]);
  });
});
