import type { AdminCommunityReport, CommunityReportReason } from '@carlys/api-contracts';

export const COMMUNITY_REPORT_REASON_LABELS: Record<CommunityReportReason, string> = {
  HARCELEMENT: 'Harcèlement',
  SPAM: 'Spam',
  CONTENU_INAPPROPRIE: 'Contenu inapproprié',
  AUTRE: 'Autre',
};

/** Ce que vise un signalement : un encouragement, un défi, ou la personne en général. */
export type ReportTarget = 'encouragement' | 'challenge' | 'person';

export function reportTarget(report: AdminCommunityReport): ReportTarget {
  if (report.friendChallengeTitle !== null) return 'challenge';
  if (report.encouragementMessage !== null) return 'encouragement';
  return 'person';
}

/**
 * Le contenu visé existe-t-il encore, donc peut-il être retiré ?
 * Un encouragement retiré (par son auteur, son destinataire ou la modération)
 * a perdu son identifiant ; un mot de défi effacé l'est une fois pour toutes.
 */
export function contentStillThere(report: AdminCommunityReport): boolean {
  switch (reportTarget(report)) {
    case 'encouragement':
      return report.encouragementId !== null;
    case 'challenge':
      // Comme le serveur : le défi doit encore exister (la relation se vide à
      // sa suppression), porter un mot, et ce mot n'avoir pas déjà été effacé.
      return (
        report.friendChallengeId !== null &&
        report.friendChallengeMessage !== null &&
        !report.friendChallengeMessageRemoved
      );
    case 'person':
      return false;
  }
}

/** La décision prise, en une phrase, pour l'historique d'un signalement résolu. */
export function decisionSummary(report: AdminCommunityReport): string {
  const gestes = [
    report.contentRemoved ? 'contenu retiré' : null,
    report.userSuspended ? 'compte suspendu' : null,
  ].filter((geste): geste is string => geste !== null);
  return gestes.length === 0
    ? 'Classé sans suite'
    : gestes.join(' et ').replace(/^./u, (c) => c.toUpperCase());
}
