import {
  type AdminCommunityReport,
  type CommunityReport as ReportContract,
} from '@carlys/api-contracts';
import {
  type CommunityModerationRepository,
  type CommunityReportRow,
} from '../infrastructure/community-moderation.repository';

/** Signalements reçus par la personne signalée : tous statuts, puis ouverts. */
export interface ReportCounts {
  total: number;
  open: number;
}

/** L'accusé de réception du SIGNALANT : rien sur la personne visée au-delà de son id. */
export function presentReport(row: CommunityReportRow): ReportContract {
  return {
    id: row.id,
    reportedUserId: row.reportedUserId,
    encouragementId: row.encouragementId,
    friendChallengeId: row.friendChallengeId,
    reason: row.reason,
    details: row.details,
    status: row.status,
    createdAt: row.createdAt.toISOString(),
    resolvedAt: row.resolvedAt?.toISOString() ?? null,
  };
}

export function presentAdminReport(
  row: CommunityReportRow,
  counts: ReportCounts | undefined,
): AdminCommunityReport {
  return {
    ...presentReport(row),
    reporter: {
      id: row.reporter.id,
      email: row.reporter.email,
      displayName: row.reporter.profile?.displayName ?? null,
    },
    reportedUser: {
      id: row.reportedUser.id,
      email: row.reportedUser.email,
      displayName: row.reportedUser.profile?.displayName ?? null,
    },
    // Le cliché pris au signalement, jamais le message vivant : l'auteur a pu
    // le retirer depuis, la preuve doit rester lisible.
    encouragementMessage: row.encouragementMessage,
    // Même règle pour un défi : son titre et son message tels qu'ils étaient.
    friendChallengeTitle: row.friendChallengeTitle,
    friendChallengeMessage: row.friendChallengeMessage,
    friendChallengeMessageRemoved: (row.friendChallenge?.messageRemovedAt ?? null) !== null,
    resolvedBy: row.resolvedBy,
    resolutionNote: row.resolutionNote,
    contentRemoved: row.contentRemoved,
    userSuspended: row.userSuspended,
    reportedUserStatus: row.reportedUser.status,
    reportedUserReportsCount: counts?.total ?? 0,
    reportedUserOpenReportsCount: counts?.open ?? 0,
  };
}

/** Un signalement seul, avec les compteurs de la personne qu'il vise. */
export async function presentOneAdminReport(
  moderation: CommunityModerationRepository,
  row: CommunityReportRow,
): Promise<AdminCommunityReport> {
  const counts = await moderation.reportCountsFor([row.reportedUserId]);
  return presentAdminReport(row, counts.get(row.reportedUserId));
}
