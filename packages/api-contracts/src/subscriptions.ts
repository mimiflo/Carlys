import { z } from 'zod';

/** Contrats des abonnements (/api/v1/subscriptions, /api/v1/entitlements). */

export const subscriptionPlanSlugSchema = z.enum(['free', 'premium']);
export type SubscriptionPlanSlug = z.infer<typeof subscriptionPlanSlugSchema>;

export const paymentProviderSchema = z.enum(['STRIPE', 'REVENUECAT', 'APP_STORE', 'PLAY_STORE']);
export type PaymentProvider = z.infer<typeof paymentProviderSchema>;

export const subscriptionStatusSchema = z.enum([
  'TRIALING',
  'ACTIVE',
  'PAST_DUE',
  'CANCELED',
  'EXPIRED',
]);
export type SubscriptionStatus = z.infer<typeof subscriptionStatusSchema>;

export const subscriptionSchema = z.object({
  id: z.string(),
  planSlug: subscriptionPlanSlugSchema,
  planName: z.string(),
  provider: paymentProviderSchema,
  status: subscriptionStatusSchema,
  currentPeriodStart: z.string().nullable(),
  currentPeriodEnd: z.string().nullable(),
  cancelAtPeriodEnd: z.boolean(),
  trialEndsAt: z.string().nullable(),
});
export type Subscription = z.infer<typeof subscriptionSchema>;

/** GET /subscriptions/me — plan effectif décidé côté serveur. */
export const subscriptionMeSchema = z.object({
  planSlug: subscriptionPlanSlugSchema,
  planName: z.string(),
  isPremium: z.boolean(),
  subscription: subscriptionSchema.nullable(),
});
export type SubscriptionMe = z.infer<typeof subscriptionMeSchema>;

/** Rythme de facturation d'une offre. */
export const offerPeriodSchema = z.enum(['month', 'year']);
export type OfferPeriod = z.infer<typeof offerPeriodSchema>;

/**
 * Une offre du catalogue. Les prix viennent du SERVEUR : une application qui
 * afficherait ses propres tarifs mentirait le jour où ils changent, et il
 * faudrait une mise à jour de l'app pour corriger un prix.
 */
export const subscriptionOfferSchema = z.object({
  id: z.string().min(1),
  planSlug: subscriptionPlanSlugSchema,
  name: z.string().min(1),
  period: offerPeriodSchema,
  amountCents: z.number().int().nonnegative(),
  currency: z.string().length(3),
  /** Prix ramené au mois, pour comparer deux rythmes sans calcul mental. */
  monthlyEquivalentCents: z.number().int().nonnegative(),
  /** Économie face au mensuel, en pourcentage entier. `null` si sans objet. */
  savingPercent: z.number().int().min(0).max(100).nullable(),
  trialDays: z.number().int().min(0).max(90),
  /** L'offre mise en avant. Une seule au plus. */
  isRecommended: z.boolean(),
});
export type SubscriptionOffer = z.infer<typeof subscriptionOfferSchema>;

/** GET /subscriptions/offers — le catalogue et l'état du paiement. */
export const subscriptionOffersResponseSchema = z.object({
  offers: z.array(subscriptionOfferSchema),
  /**
   * `false` tant que le paiement n'est pas configuré côté serveur. Le
   * catalogue reste lisible : on montre ce que Premium apporte, on ne
   * promet simplement pas un achat qui échouerait.
   */
  checkoutAvailable: z.boolean(),
});
export type SubscriptionOffersResponse = z.infer<typeof subscriptionOffersResponseSchema>;

/** POST /subscriptions/checkout — ouvre une session de paiement. */
export const createCheckoutSessionSchema = z.object({
  /** Identifiant fourni par l'appareil : rejouer n'ouvre pas deux paiements. */
  id: z.string().uuid(),
  offerId: z.string().min(1),
});
export type CreateCheckoutSession = z.infer<typeof createCheckoutSessionSchema>;

export const checkoutSessionSchema = z.object({
  /** Page de paiement à ouvrir dans le navigateur. */
  url: z.string().url(),
  provider: paymentProviderSchema,
});
export type CheckoutSession = z.infer<typeof checkoutSessionSchema>;

/**
 * Clés d'entitlements réservées (source de vérité : docs/product).
 * Le serveur DÉCIDE, le client ne fait qu'afficher.
 */
export const ENTITLEMENT_KEYS = [
  'unlimited_programs',
  'advanced_statistics',
  'premium_exercises',
  'health_sync',
  'cloud_backup',
  'ai_coaching',
  'coach_dashboard',
  'custom_animations',
  'priority_support',
] as const;

export const entitlementKeySchema = z.enum(ENTITLEMENT_KEYS);
export type EntitlementKey = z.infer<typeof entitlementKeySchema>;

/** Clés effectivement accordées par le plan premium aujourd'hui. */
export const PREMIUM_ENTITLEMENT_KEYS: readonly EntitlementKey[] = [
  'unlimited_programs',
  'advanced_statistics',
  'premium_exercises',
  'cloud_backup',
  'priority_support',
  'ai_coaching',
];

export const entitlementSchema = z.object({
  key: entitlementKeySchema,
  isActive: z.boolean(),
  expiresAt: z.string().nullable(),
});
export type Entitlement = z.infer<typeof entitlementSchema>;

/** GET /entitlements — droits effectifs, évalués côté serveur à la lecture. */
export const entitlementsResponseSchema = z.object({
  planSlug: subscriptionPlanSlugSchema,
  isPremium: z.boolean(),
  entitlements: z.array(entitlementSchema),
});
export type EntitlementsResponse = z.infer<typeof entitlementsResponseSchema>;
