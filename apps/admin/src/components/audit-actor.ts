import type { AdminAuditLog } from '@carlys/api-contracts';

export const AUDIT_ACTOR_LABELS: Record<AdminAuditLog['actorType'], string> = {
  ADMIN: 'Administration',
  USER: 'Membre',
  SYSTEM: 'Système',
};

export function auditActorId(log: AdminAuditLog): string | null {
  return log.actorType === 'ADMIN' ? log.adminUserId : log.userId;
}
