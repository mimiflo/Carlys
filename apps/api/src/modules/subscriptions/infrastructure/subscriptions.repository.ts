import { Injectable } from '@nestjs/common';
import {
  type PaymentProvider,
  Prisma,
  type SubscriptionEvent,
  type SubscriptionStatus,
  type UserEntitlement,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

export type SubscriptionWithPlan = Prisma.SubscriptionGetPayload<{ include: { plan: true } }>;
export type ProductWithPlan = Prisma.SubscriptionProductGetPayload<{ include: { plan: true } }>;

export interface UpsertSubscriptionInput {
  userId: string;
  planId: string;
  provider: PaymentProvider;
  externalSubscriptionId: string;
  status: SubscriptionStatus;
  currentPeriodStart: Date | null;
  currentPeriodEnd: Date | null;
  cancelAtPeriodEnd: boolean;
  trialEndsAt: Date | null;
}

export interface RecordEventResult {
  /** false : événement déjà connu (idempotence par (provider, externalEventId)). */
  created: boolean;
  event: SubscriptionEvent;
}

@Injectable()
export class SubscriptionsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findProduct(
    provider: PaymentProvider,
    externalProductId: string,
  ): Promise<ProductWithPlan | null> {
    return this.prisma.subscriptionProduct.findUnique({
      where: { provider_externalProductId: { provider, externalProductId } },
      include: { plan: true },
    });
  }

  latestSubscription(userId: string): Promise<SubscriptionWithPlan | null> {
    return this.prisma.subscription.findFirst({
      where: { userId },
      include: { plan: true },
      orderBy: { updatedAt: 'desc' },
    });
  }

  upsertSubscription(input: UpsertSubscriptionInput): Promise<SubscriptionWithPlan> {
    const { provider, externalSubscriptionId, ...data } = input;
    return this.prisma.subscription.upsert({
      where: {
        provider_externalSubscriptionId: { provider, externalSubscriptionId },
      },
      create: { provider, externalSubscriptionId, ...data },
      update: {
        planId: data.planId,
        status: data.status,
        currentPeriodStart: data.currentPeriodStart,
        currentPeriodEnd: data.currentPeriodEnd,
        cancelAtPeriodEnd: data.cancelAtPeriodEnd,
        trialEndsAt: data.trialEndsAt,
      },
      include: { plan: true },
    });
  }

  // ── Journal des webhooks (append-only, idempotent) ──────────────────────

  async recordEvent(input: {
    provider: PaymentProvider;
    externalEventId: string;
    eventType: string;
    payload: Prisma.InputJsonValue;
  }): Promise<RecordEventResult> {
    try {
      const event = await this.prisma.subscriptionEvent.create({ data: input });
      return { created: true, event };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const event = await this.prisma.subscriptionEvent.findUniqueOrThrow({
          where: {
            provider_externalEventId: {
              provider: input.provider,
              externalEventId: input.externalEventId,
            },
          },
        });
        return { created: false, event };
      }
      throw error;
    }
  }

  markEventProcessed(eventId: string, subscriptionId: string | null): Promise<void> {
    return this.prisma.subscriptionEvent
      .update({
        where: { id: eventId },
        data: { processedAt: new Date(), processingError: null, subscriptionId },
      })
      .then(() => undefined);
  }

  markEventFailed(eventId: string, error: string): Promise<void> {
    return this.prisma.subscriptionEvent
      .update({ where: { id: eventId }, data: { processingError: error } })
      .then(() => undefined);
  }

  // ── Entitlements matérialisés ───────────────────────────────────────────

  listEntitlements(userId: string): Promise<UserEntitlement[]> {
    return this.prisma.userEntitlement.findMany({ where: { userId } });
  }

  findEntitlement(userId: string, entitlementKey: string): Promise<UserEntitlement | null> {
    return this.prisma.userEntitlement.findUnique({
      where: { userId_entitlementKey: { userId, entitlementKey } },
    });
  }

  upsertEntitlement(
    userId: string,
    entitlementKey: string,
    data: { isActive: boolean; expiresAt: Date | null; sourceSubscriptionId: string | null },
  ): Promise<void> {
    return this.prisma.userEntitlement
      .upsert({
        where: { userId_entitlementKey: { userId, entitlementKey } },
        create: { userId, entitlementKey, ...data },
        update: data,
      })
      .then(() => undefined);
  }
}
