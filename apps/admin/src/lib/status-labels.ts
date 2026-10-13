import type {
  CommunityReportStatus,
  ManagedEntitlement,
  ManagedUserSummary,
} from '@carlys/api-contracts';

type ManagedUserStatus = ManagedUserSummary['status'];

/**
 * Les STATUTS du back-office, en français et avec leur teinte.
 *
 * Les écrans affichaient les constantes de l'API telles quelles (« ACTIVE »,
 * « SUSPENDED ») : un mot technique, en anglais, en capitales. Chaque statut
 * passe désormais par ici, une seule fois : libellé lisible + ton du badge.
 * Le ton n'est jamais le seul porteur du sens — le libellé l'écrit toujours.
 */
export type StatusTone = 'success' | 'warning' | 'danger' | 'neutral' | 'primary' | 'info';

export type StatusLabel = { label: string; tone: StatusTone };

const USER_STATUS: Record<ManagedUserStatus, StatusLabel> = {
  ACTIVE: { label: 'Actif', tone: 'success' },
  SUSPENDED: { label: 'Suspendu', tone: 'warning' },
  DELETED: { label: 'Supprimé', tone: 'neutral' },
};

export function userStatus(status: ManagedUserStatus): StatusLabel {
  return USER_STATUS[status];
}

export function planStatus(isPremium: boolean): StatusLabel {
  return isPremium ? { label: 'Premium', tone: 'primary' } : { label: 'Gratuit', tone: 'neutral' };
}

const REPORT_STATUS: Record<CommunityReportStatus, StatusLabel> = {
  OPEN: { label: 'Ouvert', tone: 'warning' },
  RESOLVED: { label: 'Résolu', tone: 'success' },
};

export function reportStatus(status: CommunityReportStatus): StatusLabel {
  return REPORT_STATUS[status];
}

/** Un droit coupé à la main se distingue d'un droit simplement fermé. */
export function entitlementStatus(entitlement: ManagedEntitlement): StatusLabel {
  if (entitlement.source === 'MANUAL_REVOCATION') {
    return { label: 'Coupé', tone: 'danger' };
  }
  return entitlement.isActive
    ? { label: 'Actif', tone: 'success' }
    : { label: 'Inactif', tone: 'neutral' };
}

/** Santé d'un composant de `/health` : `up`/`down`, ou l'état global `ok`/`error`. */
export function healthStatus(up: boolean): StatusLabel {
  return up ? { label: 'En service', tone: 'success' } : { label: 'Indisponible', tone: 'danger' };
}

/** L'API a répondu, mais l'un de ses composants est tombé : elle est dégradée. */
export const DEGRADED: StatusLabel = { label: 'Dégradée', tone: 'warning' };
