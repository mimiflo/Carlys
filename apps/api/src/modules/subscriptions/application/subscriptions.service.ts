import {
  type Subscription as SubscriptionContract,
  type SubscriptionMe,
  subscriptionPlanSlugSchema,
} from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { EntitlementsService } from './entitlements.service';
import {
  SubscriptionsRepository,
  type SubscriptionWithPlan,
} from '../infrastructure/subscriptions.repository';

function presentSubscription(subscription: SubscriptionWithPlan): SubscriptionContract {
  const planSlug = subscriptionPlanSlugSchema.safeParse(subscription.plan.slug);
  return {
    id: subscription.id,
    planSlug: planSlug.success ? planSlug.data : 'free',
    planName: subscription.plan.name,
    provider: subscription.provider,
    status: subscription.status,
    currentPeriodStart: subscription.currentPeriodStart?.toISOString() ?? null,
    currentPeriodEnd: subscription.currentPeriodEnd?.toISOString() ?? null,
    cancelAtPeriodEnd: subscription.cancelAtPeriodEnd,
    trialEndsAt: subscription.trialEndsAt?.toISOString() ?? null,
  };
}

@Injectable()
export class SubscriptionsService {
  constructor(
    private readonly subscriptions: SubscriptionsRepository,
    private readonly entitlements: EntitlementsService,
  ) {}

  /** Plan effectif — décidé côté serveur, le client ne fait qu'afficher. */
  async me(userId: string): Promise<SubscriptionMe> {
    const [subscription, isPremium] = await Promise.all([
      this.subscriptions.latestSubscription(userId),
      this.entitlements.hasEntitlement(userId, 'premium_exercises'),
    ]);

    return {
      planSlug: isPremium ? 'premium' : 'free',
      planName: isPremium ? 'Premium' : 'Gratuit',
      isPremium,
      subscription: subscription === null ? null : presentSubscription(subscription),
    };
  }
}
