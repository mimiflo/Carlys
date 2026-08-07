import {
  ENTITLEMENT_KEYS,
  type EntitlementKey,
  type EntitlementsResponse,
  PREMIUM_ENTITLEMENT_KEYS,
} from '@carlys/api-contracts';
import { Injectable } from '@nestjs/common';
import { SubscriptionStatus, type UserEntitlement } from '@prisma/client';
import {
  SubscriptionsRepository,
  type SubscriptionWithPlan,
} from '../infrastructure/subscriptions.repository';

/**
 * Un abonnement donne-t-il accès aux droits payants ?
 * TRIALING/ACTIVE : oui ; PAST_DUE/CANCELED : jusqu'à la fin de la période
 * déjà payée ; EXPIRED : non. Fonction pure, testée unitairement.
 */
export function subscriptionGrantsAccess(
  status: SubscriptionStatus,
  currentPeriodEnd: Date | null,
  nowMs: number,
): boolean {
  switch (status) {
    case SubscriptionStatus.TRIALING:
    case SubscriptionStatus.ACTIVE:
      return true;
    case SubscriptionStatus.PAST_DUE:
    case SubscriptionStatus.CANCELED:
      return currentPeriodEnd !== null && currentPeriodEnd.getTime() > nowMs;
    case SubscriptionStatus.EXPIRED:
      return false;
  }
}

function rowIsActive(row: UserEntitlement, nowMs: number): boolean {
  return row.isActive && (row.expiresAt === null || row.expiresAt.getTime() > nowMs);
}

/**
 * Droits effectifs des utilisateurs — TOUJOURS décidés côté serveur.
 * Les lignes UserEntitlement sont matérialisées à chaque événement
 * d'abonnement ; l'expiration est réévaluée à chaque lecture.
 */
@Injectable()
export class EntitlementsService {
  constructor(private readonly subscriptions: SubscriptionsRepository) {}

  async entitlementsFor(userId: string): Promise<EntitlementsResponse> {
    const rows = await this.subscriptions.listEntitlements(userId);
    const now = Date.now();
    const byKey = new Map(rows.map((row) => [row.entitlementKey, row]));

    const entitlements = ENTITLEMENT_KEYS.map((key) => {
      const row = byKey.get(key);
      return {
        key,
        isActive: row !== undefined && rowIsActive(row, now),
        expiresAt: row?.expiresAt?.toISOString() ?? null,
      };
    });
    const isPremium =
      entitlements.find((entitlement) => entitlement.key === 'premium_exercises')?.isActive ??
      false;

    return { planSlug: isPremium ? 'premium' : 'free', isPremium, entitlements };
  }

  async hasEntitlement(userId: string, key: EntitlementKey): Promise<boolean> {
    const row = await this.subscriptions.findEntitlement(userId, key);
    return row !== null && rowIsActive(row, Date.now());
  }

  /**
   * Recalcule les droits matérialisés depuis l'état d'un abonnement.
   * Les attributions MANUELLES actives (sourceSubscriptionId null — Étape 7)
   * ne sont jamais écrasées par la synchronisation.
   */
  async syncFromSubscription(subscription: SubscriptionWithPlan): Promise<void> {
    const grants =
      subscription.plan.slug === 'premium' &&
      subscriptionGrantsAccess(subscription.status, subscription.currentPeriodEnd, Date.now());
    const expiresAt = subscription.currentPeriodEnd ?? subscription.trialEndsAt;

    const existing = await this.subscriptions.listEntitlements(subscription.userId);
    const manuallyGranted = new Set(
      existing
        .filter((row) => row.sourceSubscriptionId === null && row.isActive)
        .map((row) => row.entitlementKey),
    );

    for (const key of PREMIUM_ENTITLEMENT_KEYS) {
      if (manuallyGranted.has(key)) {
        continue;
      }
      await this.subscriptions.upsertEntitlement(subscription.userId, key, {
        isActive: grants,
        expiresAt,
        sourceSubscriptionId: subscription.id,
      });
    }
  }
}
