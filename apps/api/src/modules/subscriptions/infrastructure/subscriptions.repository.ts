import { Injectable } from '@nestjs/common';
import {
  type PaymentProvider,
  Prisma,
  type SubscriptionEvent,
  type SubscriptionStatus,
  type UserEntitlement,
} from '@prisma/client';
import { PrismaService } from '../../../database/prisma/prisma.service';

/**
 * Le plan d'un abonnement vient TOUJOURS avec les droits qu'il ouvre.
 *
 * `satisfies` et non une annotation : la forme littérale est ce dont Prisma
 * déduit le type du résultat ; l'annoter l'effacerait, et `plan.entitlements`
 * redeviendrait inconnu.
 */
export const PLAN_AVEC_DROITS = {
  plan: { include: { entitlements: true } },
} satisfies Prisma.SubscriptionInclude;

export type SubscriptionWithPlan = Prisma.SubscriptionGetPayload<{
  include: typeof PLAN_AVEC_DROITS;
}>;
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
  /** Client chez le fournisseur ; `null` quand l'événement ne le porte pas. */
  externalCustomerId: string | null;
  /**
   * Date d'ÉMISSION de l'événement chez le fournisseur — pas sa date de
   * réception. C'est elle qui ordonne les écritures ; `null` quand la charge
   * utile ne la porte pas, auquel cas l'ordre ne peut pas être établi et
   * l'écriture passe.
   */
  eventAt: Date | null;
}

export interface UpsertSubscriptionResult {
  subscription: SubscriptionWithPlan;
  /**
   * true : l'événement était plus ANCIEN que le dernier appliqué — la ligne
   * n'a pas été touchée, et c'est son état courant qui est rendu.
   */
  stale: boolean;
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
      include: PLAN_AVEC_DROITS,
    });
  }

  latestSubscription(userId: string): Promise<SubscriptionWithPlan | null> {
    return this.prisma.subscription.findFirst({
      where: { userId },
      include: PLAN_AVEC_DROITS,
      orderBy: { updatedAt: 'desc' },
    });
  }

  /**
   * TOUS les abonnements du compte, plan compris.
   *
   * Un compte peut légitimement en porter plusieurs : la migration web →
   * magasin d'applications, que `PaymentProvider` prévoit explicitement,
   * laisse l'abonnement Stripe résilié à côté de l'achat in-app actif. Les
   * droits se calculent donc sur l'ENSEMBLE, jamais sur un seul.
   */
  listSubscriptions(userId: string): Promise<SubscriptionWithPlan[]> {
    return this.prisma.subscription.findMany({
      where: { userId },
      include: PLAN_AVEC_DROITS,
      orderBy: { updatedAt: 'desc' },
    });
  }

  /**
   * Projette l'état d'un abonnement, en REFUSANT les événements périmés.
   *
   * L'écriture était inconditionnelle. Or les webhooks n'arrivent pas dans
   * l'ordre d'émission — un réessai après une coupure réseau, ou simplement
   * le parallélisme du fournisseur, suffit à livrer un événement ancien après
   * un plus récent. Un `customer.subscription.updated` émis AVANT un
   * renouvellement mais livré APRÈS réécrivait la période à jour avec
   * l'ancienne : l'accès d'un membre qui venait de payer se coupait, jusqu'au
   * prochain événement — c'est-à-dire un mois.
   *
   * Un événement périmé n'est pas une erreur : la ligne est rendue telle
   * qu'elle est, l'appelant recalcule les droits depuis cet état courant et
   * marque l'événement traité. Il A été traité — en étant ignoré à bon droit.
   *
   * La transaction lit puis écrit. Deux événements du MÊME abonnement traités
   * exactement en parallèle peuvent encore se marcher dessus (lecture-écriture
   * non atomique) ; l'écart est alors de quelques millisecondes entre deux
   * événements quasi simultanés, sans commune mesure avec le rembobinage que
   * cette garde supprime. Le verrouillage de ligne serait le remède complet ;
   * il n'est pas payé tant que ce scénario n'est pas observé.
   */
  async upsertSubscription(input: UpsertSubscriptionInput): Promise<UpsertSubscriptionResult> {
    const { provider, externalSubscriptionId, eventAt, ...data } = input;
    const where = {
      provider_externalSubscriptionId: { provider, externalSubscriptionId },
    };

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.subscription.findUnique({ where, include: PLAN_AVEC_DROITS });
      if (existing === null) {
        const subscription = await tx.subscription.create({
          data: { provider, externalSubscriptionId, lastEventAt: eventAt, ...data },
          include: PLAN_AVEC_DROITS,
        });
        return { subscription, stale: false };
      }

      // Strictement plus ancien : refusé. À égalité, on applique — les
      // fournisseurs datent à la seconde et émettent plusieurs événements
      // dans la même, où refuser ferait perdre des mises à jour légitimes.
      if (eventAt !== null && existing.lastEventAt !== null && eventAt < existing.lastEventAt) {
        return { subscription: existing, stale: true };
      }

      const subscription = await tx.subscription.update({
        where,
        data: {
          planId: data.planId,
          status: data.status,
          currentPeriodStart: data.currentPeriodStart,
          currentPeriodEnd: data.currentPeriodEnd,
          cancelAtPeriodEnd: data.cancelAtPeriodEnd,
          trialEndsAt: data.trialEndsAt,
          // Un client connu ne s'oublie pas : un événement sans `customer`
          // ne doit pas effacer ce qu'un précédent a appris.
          ...(data.externalCustomerId === null
            ? {}
            : { externalCustomerId: data.externalCustomerId }),
          // Même raison pour la date : un événement non daté ne doit pas
          // effacer le repère laissé par un événement daté, sans quoi la
          // garde se désarmerait toute seule.
          ...(eventAt === null ? {} : { lastEventAt: eventAt }),
        },
        include: PLAN_AVEC_DROITS,
      });
      return { subscription, stale: false };
    });
  }

  /** Client Stripe connu pour ce compte (le plus récent), ou `null`. */
  async stripeCustomerIdOf(userId: string): Promise<string | null> {
    const subscription = await this.prisma.subscription.findFirst({
      where: { userId, provider: 'STRIPE', externalCustomerId: { not: null } },
      orderBy: { updatedAt: 'desc' },
      select: { externalCustomerId: true },
    });
    return subscription?.externalCustomerId ?? null;
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
