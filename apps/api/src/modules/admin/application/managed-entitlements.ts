import {
  ENTITLEMENT_KEYS,
  type ManagedEntitlement,
  type ManagedEntitlementSource,
  type ManagedPaidSubscription,
} from '@carlys/api-contracts';
import {
  rowIsActive,
  subscriptionGrantsAccess,
} from '../../subscriptions/application/entitlements.service';
import {
  type ManagedSubscriptionRow,
  type ManagedUserDetailRow,
} from '../infrastructure/admin-users.repository';

type EntitlementRow = ManagedUserDetailRow['entitlements'][number];

/**
 * D'où vient l'état d'un droit. La marque d'une décision manuelle est
 * `sourceSubscriptionId === null` (posée par `upsertManualEntitlement`) ;
 * `isActive` dit ensuite si l'administration a offert ou coupé.
 */
export function entitlementSource(row: EntitlementRow | undefined): ManagedEntitlementSource {
  if (row === undefined) {
    return 'NONE';
  }
  if (row.sourceSubscriptionId !== null) {
    return 'SUBSCRIPTION';
  }
  return row.isActive ? 'MANUAL_GRANT' : 'MANUAL_REVOCATION';
}

/** Tous les droits du contrat, chacun avec son état effectif et son origine. */
export function presentManagedEntitlements(
  rows: readonly EntitlementRow[],
  nowMs: number,
): ManagedEntitlement[] {
  const byKey = new Map(rows.map((row) => [row.entitlementKey, row]));
  return ENTITLEMENT_KEYS.map((key) => {
    const row = byKey.get(key);
    const source = entitlementSource(row);
    const provider = source === 'SUBSCRIPTION' ? row?.sourceSubscription?.provider : undefined;
    return {
      key,
      isActive: row !== undefined && rowIsActive(row, nowMs),
      expiresAt: row?.expiresAt?.toISOString() ?? null,
      source,
      ...(provider === undefined ? {} : { provider }),
    };
  });
}

/**
 * L'abonnement qui ouvre l'accès aujourd'hui, s'il y en a un : le plus
 * récemment touché parmi ceux que `subscriptionGrantsAccess` retient. Une
 * coupure manuelle n'y change rien — c'est précisément ce que le back-office
 * doit voir : l'accès est coupé, la facturation continue.
 */
export function paidSubscriptionOf(
  subscriptions: readonly ManagedSubscriptionRow[],
  nowMs: number,
): ManagedPaidSubscription | null {
  const ouvrant = subscriptions.find((row) =>
    subscriptionGrantsAccess(row.status, row.currentPeriodEnd, nowMs),
  );
  if (ouvrant === undefined) {
    return null;
  }
  return {
    provider: ouvrant.provider,
    status: ouvrant.status,
    currentPeriodEnd: ouvrant.currentPeriodEnd?.toISOString() ?? null,
    cancelAtPeriodEnd: ouvrant.cancelAtPeriodEnd,
  };
}
