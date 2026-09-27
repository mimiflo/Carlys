import type {
  ManagedEntitlement,
  ManagedPaidSubscription,
  PaymentProvider,
  SubscriptionStatus,
} from '@carlys/api-contracts';

/**
 * Les mots du back-office pour l'origine d'un droit et l'abonnement qui le
 * paie. Sans eux, la fiche ne pouvait dire QUE « actif » ou « inactif » : un
 * accès payé et un accès offert se ressemblaient, et le bouton qui les
 * retirait s'appelait « Retirer le premium manuel » dans les deux cas.
 */

export const PROVIDER_LABELS: Record<PaymentProvider, string> = {
  STRIPE: 'Stripe (web)',
  REVENUECAT: 'RevenueCat',
  APP_STORE: 'App Store',
  PLAY_STORE: 'Google Play',
};

export const SUBSCRIPTION_STATUS_LABELS: Record<SubscriptionStatus, string> = {
  TRIALING: 'en essai',
  ACTIVE: 'actif',
  PAST_DUE: 'paiement en retard',
  CANCELED: 'résilié',
  EXPIRED: 'expiré',
};

function dateFr(iso: string): string {
  return new Date(iso).toLocaleDateString('fr-FR');
}

/** L'origine d'un droit, en quelques mots, pour la liste des droits. */
export function sourceLabel(entitlement: ManagedEntitlement): string {
  switch (entitlement.source) {
    case 'SUBSCRIPTION':
      return entitlement.provider === undefined
        ? 'abonnement'
        : `abonnement ${PROVIDER_LABELS[entitlement.provider]}`;
    case 'MANUAL_GRANT':
      return 'offert à la main';
    case 'MANUAL_REVOCATION':
      return 'coupé à la main';
    case 'NONE':
      return 'jamais ouvert';
  }
}

/** Ce que la fiche dit de l'accès premium : son état ET d'où il vient. */
export function premiumStateSentence(entitlement: ManagedEntitlement): string {
  const provider =
    entitlement.provider === undefined ? '' : ` ${PROVIDER_LABELS[entitlement.provider]}`;
  switch (entitlement.source) {
    case 'SUBSCRIPTION':
      return entitlement.isActive
        ? `Ouvert par l’abonnement${provider} : il suit les paiements.`
        : `Fermé : l’abonnement${provider} ne l’ouvre plus.`;
    case 'MANUAL_GRANT':
      if (!entitlement.isActive && entitlement.expiresAt !== null) {
        return `L’offre manuelle a pris fin le ${dateFr(entitlement.expiresAt)}.`;
      }
      return entitlement.expiresAt === null
        ? 'Offert à la main par l’administration, sans échéance : il survit à la fin de tout abonnement.'
        : `Offert à la main par l’administration jusqu’au ${dateFr(entitlement.expiresAt)}.`;
    case 'MANUAL_REVOCATION':
      return 'Coupé à la main par l’administration : la coupure survit à tout paiement et bloque les achats.';
    case 'NONE':
      return 'Jamais ouvert : ni abonnement, ni décision de l’administration.';
  }
}

/** L'abonnement qui ouvre l'accès aujourd'hui, en une phrase. */
export function paidSubscriptionSentence(paid: ManagedPaidSubscription): string {
  const until =
    paid.currentPeriodEnd === null
      ? ''
      : `, période payée jusqu’au ${dateFr(paid.currentPeriodEnd)}`;
  const ending = paid.cancelAtPeriodEnd ? ', résilié à l’échéance' : '';
  return `Abonnement ${PROVIDER_LABELS[paid.provider]} ${SUBSCRIPTION_STATUS_LABELS[paid.status]}${until}${ending}.`;
}
