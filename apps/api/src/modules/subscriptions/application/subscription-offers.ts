import { type SubscriptionOffer } from '@carlys/api-contracts';

/**
 * Le catalogue d'offres, calculé à partir des prix configurés.
 *
 * Fonction PURE : le rabais annuel, l'équivalent mensuel et la recommandation
 * se déduisent des deux montants, ils ne se saisissent pas. Un rabais saisi à
 * la main finit toujours par mentir après un changement de prix.
 */
export interface OfferCatalogInput {
  readonly currency: string;
  readonly monthlyCents: number;
  readonly yearlyCents: number;
  readonly trialDays: number;
}

const monthsPerYear = 12;

/** Identifiants d'offre — stables, ils voyagent jusqu'au paiement. */
export const MONTHLY_OFFER_ID = 'premium-mensuel';
export const YEARLY_OFFER_ID = 'premium-annuel';

export function buildOfferCatalog(input: OfferCatalogInput): SubscriptionOffer[] {
  const monthlyEquivalent = Math.round(input.yearlyCents / monthsPerYear);

  // Le rabais se lit sur le prix ramené au mois : c'est la seule comparaison
  // honnête entre deux rythmes de facturation.
  const saving =
    input.monthlyCents > 0
      ? Math.max(0, Math.round((1 - monthlyEquivalent / input.monthlyCents) * 100))
      : 0;

  return [
    {
      id: MONTHLY_OFFER_ID,
      planSlug: 'premium',
      name: 'Premium mensuel',
      period: 'month',
      amountCents: input.monthlyCents,
      currency: input.currency,
      monthlyEquivalentCents: input.monthlyCents,
      savingPercent: null,
      trialDays: input.trialDays,
      isRecommended: false,
    },
    {
      id: YEARLY_OFFER_ID,
      planSlug: 'premium',
      name: 'Premium annuel',
      period: 'year',
      amountCents: input.yearlyCents,
      currency: input.currency,
      monthlyEquivalentCents: monthlyEquivalent,
      // Pas de badge d'économie quand il n'y en a pas : annoncer « 0 % »
      // ou un rabais inexistant décrédibiliserait tout le reste.
      savingPercent: saving > 0 ? saving : null,
      trialDays: input.trialDays,
      isRecommended: saving > 0,
    },
  ];
}
