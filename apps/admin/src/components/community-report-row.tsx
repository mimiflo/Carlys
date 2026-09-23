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
 *
 * L'e-mail s'affichait EN PLUS du nom quand le nom existait : les deux
 * branches le rendaient, donc il apparaissait dans 100 % des cas et non dans
 * le seul repli que ce commentaire décrit. Deux parties par ligne, vingt
 * lignes par page : quatre-vingts adresses en permanence à l'écran, pour une
 * file où le seul geste est « Résoudre / Rouvrir ». Il reste atteignable —
 * l'infobulle le donne pour départager deux homonymes, la fiche le donne en
 * clair — mais sur une intention, pas par défaut.
 */
function PartyLink({ party }: { party: AdminCommunityReportParty }) {
  return (
    <Link
      href={`/users/${party.id}`}
      title={party.email}
      className="font-medium text-primary underline"
    >
      {party.displayName ?? party.email}
    </Link>
  );
}

/**
 * Le défi entre amis visé, tel qu'il était AU MOMENT du signalement : son
 * titre, puis le mot de son créateur cité — ou « (sans message) » s'il n'en
 * avait pas écrit, car c'est alors le titre seul qui est signalé. Les deux
 * sont des clichés figés par le serveur, comme le texte d'un encouragement.
 */
function ChallengeTarget({ title, message }: { title: string; message: string | null }) {
  return (
    <span className="flex flex-col gap-1">
      <span className="font-medium">Défi « {title} »</span>
      {message === null ? (
        <span className="text-xs text-muted">(sans message)</span>
      ) : (
        <q className="italic">{message}</q>
      )}
    </span>
  );
}

/**
 * Ce que vise le signalement, tel qu'il était AU MOMENT du signalement : le
 * serveur en fige un cliché dans la transaction qui le crée, donc la preuve
 * reste lisible même après coup. Un encouragement OU un défi, jamais les
 * deux (le serveur refuse). Pour un encouragement, trois états, tous
 * atteignables :
 *
 * - cliché + `encouragementId` : le message est toujours dans le fil ;
 * - cliché seul (`encouragementId` remis à `NULL` par la suppression) : le
 *   message a été retiré depuis, on montre quand même ce qui a été signalé ;
 * - ni l'un ni l'autre : le signalement vise la personne, pas un message.
 *
 * Un défi, lui, n'a aucune route de suppression (la suppression d'un compte
 * est logique, la ligne reste) : pas d'état « retiré depuis » à montrer. Si
 * la ligne venait à être effacée en base, `friendChallengeId` passerait à
 * `NULL` et les clichés suffiraient encore.
 */
function TargetCell({ report }: { report: AdminCommunityReport }) {
  if (report.friendChallengeTitle !== null) {
    return (
      <ChallengeTarget
        title={report.friendChallengeTitle}
        message={report.friendChallengeMessage}
      />
    );
  }
  if (report.encouragementMessage === null) {
    return <span className="text-xs text-muted">La personne en général</span>;
  }
  return (
    <span className="flex flex-col gap-1">
      <q className="italic">{report.encouragementMessage}</q>
      {report.encouragementId === null && (
        <span className="text-xs text-muted">Message retiré depuis</span>
      )}
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
        <TargetCell report={report} />
      </td>
      <td className="px-4 py-3">
        <CommunityReportStatusCell report={report} />
      </td>
    </tr>
  );
}
