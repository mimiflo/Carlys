import { SubscriptionStatus } from '@prisma/client';
import { z } from 'zod';

/**
 * Sous-ensemble VALIDÉ des charges utiles de webhooks — tout champ non
 * reconnu est ignoré, tout champ requis absent rejette l'événement.
 */

export const stripeEventSchema = z.object({
  id: z.string().min(1),
  type: z.string().min(1),
  data: z.object({
    object: z.object({
      id: z.string().min(1),
      status: z.string().optional(),
      /** Client Stripe (`cus_…`) : réutilisé au paiement, requis par le portail. */
      customer: z.string().optional(),
      cancel_at_period_end: z.boolean().optional(),
      current_period_start: z.number().optional(),
      current_period_end: z.number().optional(),
      trial_end: z.number().nullable().optional(),
      metadata: z.record(z.string(), z.string()).optional(),
      items: z
        .object({
          data: z.array(z.object({ price: z.object({ id: z.string().min(1) }) })),
        })
        .optional(),
    }),
  }),
});
export type StripeEvent = z.infer<typeof stripeEventSchema>;

export const revenueCatEventSchema = z.object({
  event: z.object({
    id: z.string().min(1),
    type: z.string().min(1),
    app_user_id: z.string().min(1),
    product_id: z.string().optional(),
    original_transaction_id: z.string().optional(),
    period_type: z.string().optional(),
    expiration_at_ms: z.number().nullable().optional(),
  }),
});
export type RevenueCatEvent = z.infer<typeof revenueCatEventSchema>;

/** Statut Stripe → statut interne. */
export function mapStripeStatus(status: string | undefined): SubscriptionStatus {
  switch (status) {
    case 'trialing':
      return SubscriptionStatus.TRIALING;
    case 'active':
      return SubscriptionStatus.ACTIVE;
    case 'past_due':
    case 'unpaid':
      return SubscriptionStatus.PAST_DUE;
    case 'canceled':
      return SubscriptionStatus.CANCELED;
    default:
      return SubscriptionStatus.EXPIRED;
  }
}

/** Type d'événement RevenueCat → statut interne (null : événement ignoré). */
export function mapRevenueCatType(
  type: string,
  periodType: string | undefined,
): SubscriptionStatus | null {
  switch (type) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'UNCANCELLATION':
    case 'PRODUCT_CHANGE':
      return periodType === 'TRIAL' ? SubscriptionStatus.TRIALING : SubscriptionStatus.ACTIVE;
    case 'CANCELLATION':
      return SubscriptionStatus.CANCELED;
    case 'BILLING_ISSUE':
      return SubscriptionStatus.PAST_DUE;
    case 'EXPIRATION':
      return SubscriptionStatus.EXPIRED;
    default:
      return null;
  }
}
