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
 * Le plan ouvre-t-il les droits payants ?
 *
 * Le slug vit ICI, en un seul endroit, plutôt que dispersé dans le calcul.
 * Ce n'est pas la forme cible — l'ADR 0006 veut que le plan PORTE ses droits
 * en base plutôt que d'être reconnu par son nom — mais tant que
 * `SubscriptionPlan` n'a pas de relation vers les droits, le nommer une fois
 * vaut mieux que de le comparer au fil du code.
 */
function planGrantsPremium(slug: string): boolean {
  return slug === 'premium';
}

/** L'échéance la plus lointaine ; `null` (sans fin) l'emporte sur toute date. */
function latestExpiry(subscriptions: SubscriptionWithPlan[]): Date | null {
  let latest: Date | null = null;
  for (const subscription of subscriptions) {
    const end = subscription.currentPeriodEnd ?? subscription.trialEndsAt;
    if (end === null) {
      return null;
    }
    if (latest === null || end.getTime() > latest.getTime()) {
      latest = end;
    }
  }
  return latest;
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
   * L'administration a-t-elle RETIRÉ ce droit à la main ?
   *
   * À distinguer d'un simple « pas de droit » : une ligne posée par le
   * back-office (`sourceSubscriptionId === null`) avec `isActive: false`
   * survit désormais à tout webhook. Un abonnement souscrit après ce retrait
   * ne rendrait donc RIEN — il faut refuser le paiement plutôt qu'encaisser
   * pour rien.
   */
  async isManuallyRevoked(userId: string, key: EntitlementKey): Promise<boolean> {
    const row = await this.subscriptions.findEntitlement(userId, key);
    return row !== null && row.sourceSubscriptionId === null && !row.isActive;
  }

  /**
   * Recalcule les droits matérialisés d'un compte, depuis TOUS ses
   * abonnements — pas depuis celui dont l'événement vient d'arriver.
   *
   * POURQUOI CETTE DISTINCTION EST VITALE. Un compte peut légitimement porter
   * plusieurs abonnements : la migration web → magasin d'applications, que
   * `PaymentProvider` prévoit, laisse l'abonnement Stripe résilié à côté de
   * l'achat in-app actif. La version précédente calculait `grants` depuis le
   * SEUL abonnement reçu, puis écrasait les lignes de droits du compte :
   * l'événement terminal de l'abonnement révolu (expiration de la période
   * déjà payée, `customer.subscription.deleted`) passait donc les droits à
   * `false` — alors qu'un autre abonnement, actif et payé, les justifiait
   * toujours. Le membre perdait son accès en ayant payé.
   *
   * On prend le MEILLEUR des abonnements : dès qu'un seul ouvre le droit, le
   * droit est ouvert, et l'échéance retenue est la plus lointaine.
   *
   * Les attributions MANUELLES actives (sourceSubscriptionId null — Étape 7)
   * ne sont jamais écrasées par la synchronisation.
   */
  async syncFromSubscription(subscription: SubscriptionWithPlan): Promise<void> {
    const now = Date.now();
    const all = await this.subscriptions.listSubscriptions(subscription.userId);
    // L'abonnement reçu peut ne pas encore figurer dans la liste relue (même
    // transaction, réplica en retard) : on l'y ajoute, en remplaçant sa
    // version éventuellement périmée.
    const considered = [subscription, ...all.filter((row) => row.id !== subscription.id)];

    const granting = considered.filter(
      (row) =>
        planGrantsPremium(row.plan.slug) &&
        subscriptionGrantsAccess(row.status, row.currentPeriodEnd, now),
    );
    const grants = granting.length > 0;

    // L'échéance la plus LOINTAINE parmi ceux qui ouvrent le droit ; `null`
    // (jamais d'expiration) l'emporte sur toute date. Sans droit ouvert, on
    // garde l'échéance de l'abonnement reçu : la ligne inactive porte alors
    // la date à laquelle l'accès s'est arrêté.
    const expiresAt = grants
      ? latestExpiry(granting)
      : (subscription.currentPeriodEnd ?? subscription.trialEndsAt);
    const source = grants ? (granting[0]?.id ?? subscription.id) : subscription.id;

    // TOUTE décision manuelle est respectée, l'octroi COMME le retrait.
    //
    // Le filtre exigeait `isActive` en plus de `sourceSubscriptionId === null` :
    // seuls les octrois manuels étaient protégés. Un RETRAIT manuel — un admin
    // qui coupe l'accès d'un compte abusif — portait pourtant la même marque
    // (`sourceSubscriptionId: null`, `isActive: false`, cf.
    // `admin-users.repository.ts`), et le premier webhook venu le réécrivait.
    // La décision de l'administration était annulée en silence, par un
    // renouvellement de routine.
    //
    // Conséquence assumée : un compte dont un admin a retiré le droit ne le
    // retrouve pas en payant. C'est le propre d'une décision manuelle, et le
    // back-office est le seul chemin pour la lever.
    const existing = await this.subscriptions.listEntitlements(subscription.userId);
    const manuallyDecided = new Set(
      existing.filter((row) => row.sourceSubscriptionId === null).map((row) => row.entitlementKey),
    );

    for (const key of PREMIUM_ENTITLEMENT_KEYS) {
      if (manuallyDecided.has(key)) {
        continue;
      }
      await this.subscriptions.upsertEntitlement(subscription.userId, key, {
        isActive: grants,
        expiresAt,
        sourceSubscriptionId: source,
      });
    }
  }
}
