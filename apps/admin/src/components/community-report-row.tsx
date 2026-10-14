'use client';

import { type AdminCommunityReport, type AdminCommunityReportParty } from '@carlys/api-contracts';
import Link from 'next/link';
import { COMMUNITY_REPORT_REASON_LABELS } from '@/lib/report-labels';
import { reportStatus, userStatus } from '@/lib/status-labels';
import { Badge } from './ui/badge';
import { button } from './ui/button';
import { td, tr } from './ui/table';

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
export function PartyLink({ party }: { party: AdminCommunityReportParty }) {
  return (
    <Link
      href={`/users/${party.id}`}
      title={party.email}
      className="font-medium text-primary-ink hover:underline"
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
function ChallengeTarget({
  title,
  message,
  removed,
}: {
  title: string;
  message: string | null;
  removed: boolean;
}) {
  return (
    <span className="flex flex-col gap-1">
      <span className="font-medium">Défi « {title} »</span>
      {message === null ? (
        <span className="text-xs text-muted">
          {removed ? 'Mot retiré par la modération' : '(sans message)'}
        </span>
      ) : (
        <q className="border-l-2 border-primary/40 pl-2 text-sm italic">{message}</q>
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
export function TargetCell({ report }: { report: AdminCommunityReport }) {
  if (report.friendChallengeTitle !== null) {
    return (
      <ChallengeTarget
        title={report.friendChallengeTitle}
        message={report.friendChallengeMessage}
        removed={report.friendChallengeMessageRemoved}
      />
    );
  }
  if (report.encouragementMessage === null) {
    return <span className="text-xs text-muted">La personne en général</span>;
  }
  return (
    <span className="flex flex-col gap-1">
      <q className="border-l-2 border-primary/40 pl-2 text-sm italic">
        {report.encouragementMessage}
      </q>
      {report.encouragementId === null && (
        <span className="text-xs text-muted">
          {report.contentRemoved ? 'Retiré par la modération' : 'Message retiré depuis'}
        </span>
      )}
    </span>
  );
}

/** Combien de fois cette personne a été signalée : le signal d'une récidive. */
export function ReportedHistory({ report }: { report: AdminCommunityReport }) {
  const total = report.reportedUserReportsCount;
  return (
    <span className="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-muted">
      {report.reportedUserStatus !== 'ACTIVE' && (
        <Badge status={userStatus(report.reportedUserStatus)} />
      )}
      {total > 1 && (
        <span className={total >= 3 ? 'font-medium text-danger-ink' : undefined}>
          {total} signalements · {report.reportedUserOpenReportsCount} ouvert
          {report.reportedUserOpenReportsCount > 1 ? 's' : ''}
        </span>
      )}
    </span>
  );
}

export function CommunityReportRow({
  report,
  onOpen,
}: {
  report: AdminCommunityReport;
  onOpen: () => void;
}) {
  return (
    // Un signalement résolu le DIT dans sa colonne d'état ; il ne pâlit
    // pas : à 60 % d'opacité, ses textes secondaires tombaient sous 3:1 et
    // le bouton « Rouvrir », toujours actif, avec eux.
    <tr className={tr}>
      <td className={`${td} tabular-nums whitespace-nowrap text-muted`}>
        {new Date(report.createdAt).toLocaleString('fr-FR', {
          dateStyle: 'short',
          timeStyle: 'short',
        })}
      </td>
      <td data-label="Motif" className={td}>
        <span className="font-medium">{COMMUNITY_REPORT_REASON_LABELS[report.reason]}</span>
        {report.details !== null && (
          <span className="block max-w-xs text-xs text-muted">{report.details}</span>
        )}
      </td>
      <td data-label="Auteur" className={td}>
        <PartyLink party={report.reporter} />
      </td>
      <td data-label="Personne visée" className={td}>
        <PartyLink party={report.reportedUser} />
        <ReportedHistory report={report} />
      </td>
      <td data-label="Contenu visé" className={`${td} max-w-xs`}>
        <TargetCell report={report} />
      </td>
      <td className={`${td} max-md:basis-full`}>
        <div className="flex flex-wrap items-center gap-2 md:flex-col md:items-start">
          <Badge status={reportStatus(report.status)} />
          <button type="button" onClick={onOpen} className={button('secondary', 'sm')}>
            {report.status === 'OPEN' ? 'Examiner' : 'Voir la décision'}
          </button>
        </div>
      </td>
    </tr>
  );
}
