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
