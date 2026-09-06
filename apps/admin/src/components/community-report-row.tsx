'use client';

import {
  type AdminCommunityReport,
  type AdminCommunityReportParty,
  type CommunityReportReason,
} from '@carlys/api-contracts';
import Link from 'next/link';
import { CommunityReportStatusCell } from './community-report-status-cell';

/** Motifs tels que le membre les a choisis, dans les mots de l'écran mobile. */
export const COMMUNITY_REPORT_REASON_LABELS: Record<CommunityReportReason, string> = {
  HARCELEMENT: 'Harcèlement',
  SPAM: 'Spam',
  CONTENU_INAPPROPRIE: 'Contenu inapproprié',
  AUTRE: 'Autre',
};

/**
 * Lien vers la fiche : c'est là qu'on suspend, on ne duplique pas ce geste
 * ici. Le nom peut manquer (profil jamais rempli) : l'e-mail prend le relais.
 */
function PartyLink({ party }: { party: AdminCommunityReportParty }) {
  return (
    <span className="flex flex-col">
      <Link href={`/users/${party.id}`} className="font-medium text-primary underline">
        {party.displayName ?? party.email}
      </Link>
      {party.displayName !== null && <span className="text-xs text-muted">{party.email}</span>}
    </span>
  );
}

/**
 * Le texte visé, s'il existe encore : un encouragement retiré depuis laisse
 * son identifiant, sans message ; un signalement sans encouragement vise la
 * personne elle-même.
 */
function EncouragementCell({ report }: { report: AdminCommunityReport }) {
  if (report.encouragementMessage !== null) {
    return <q className="italic">{report.encouragementMessage}</q>;
  }
  return (
    <span className="text-xs text-muted">
      {report.encouragementId !== null ? 'Message retiré depuis' : 'La personne en général'}
    </span>
  );
}

export function CommunityReportRow({ report }: { report: AdminCommunityReport }) {
  return (
    <tr
      className={`border-b border-black/5 last:border-0 ${
        report.status === 'RESOLVED' ? 'opacity-60' : ''
      }`}
    >
      <td className="whitespace-nowrap px-4 py-3">
        {new Date(report.createdAt).toLocaleString('fr-FR')}
      </td>
      <td className="px-4 py-3">
        <span className="font-medium">{COMMUNITY_REPORT_REASON_LABELS[report.reason]}</span>
        {report.details !== null && (
          <span className="block max-w-xs text-xs text-muted">{report.details}</span>
        )}
      </td>
      <td className="px-4 py-3">
        <PartyLink party={report.reporter} />
      </td>
      <td className="px-4 py-3">
        <PartyLink party={report.reportedUser} />
      </td>
      <td className="max-w-xs px-4 py-3">
        <EncouragementCell report={report} />
      </td>
      <td className="px-4 py-3">
        <CommunityReportStatusCell report={report} />
      </td>
    </tr>
  );
}
