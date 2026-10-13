'use client';

import { type AdminCommunityReport } from '@carlys/api-contracts';
import { COMMUNITY_REPORT_REASON_LABELS, decisionSummary } from '@/lib/report-labels';
import { reportStatus } from '@/lib/status-labels';
import { PartyLink, ReportedHistory, TargetCell } from './community-report-row';
import { ReportReopen } from './community-report-status-cell';
import { ReportDecisionForm } from './report-decision-form';
import { Badge } from './ui/badge';
import { button } from './ui/button';
import { PanelSection, SidePanel } from './ui/side-panel';

const DATE = { dateStyle: 'long', timeStyle: 'short' } as const;

/**
 * Le dossier d'un signalement : ce qui est reproché, à qui, par qui, ce que
 * dit l'historique de la personne — puis la décision, ou celle déjà prise.
 */
export function ReportSheet({
  report,
  canSuspend,
  onShowPersonReports,
  onDecided,
  onClose,
}: {
  report: AdminCommunityReport;
  canSuspend: boolean;
  onShowPersonReports: () => void;
  onDecided: () => void;
  onClose: () => void;
}) {
  return (
    <SidePanel
      title={COMMUNITY_REPORT_REASON_LABELS[report.reason]}
      subtitle={
        <span className="flex flex-wrap items-center gap-2">
          <Badge status={reportStatus(report.status)} />
          Signalé le {new Date(report.createdAt).toLocaleString('fr-FR', DATE)}
        </span>
      }
      onClose={onClose}
    >
      <PanelSection title="Ce qui est signalé">
        <TargetCell report={report} />
        {report.details !== null && (
          <p className="mt-3 rounded-lg bg-surface-alt px-3 py-2 text-sm">
            <span className="block text-xs text-muted">Précisions de l’auteur</span>
            {report.details}
          </p>
        )}
      </PanelSection>

      <PanelSection title="Les personnes">
        <dl className="flex flex-col gap-3 text-sm">
          <div>
            <dt className="text-xs text-muted">Personne visée</dt>
            <dd>
              <PartyLink party={report.reportedUser} />
              <ReportedHistory report={report} />
              {report.reportedUserReportsCount > 1 && (
                <button
                  type="button"
                  onClick={onShowPersonReports}
                  className={`${button('ghost', 'sm')} mt-1 -ml-3`}
                >
                  Voir ses {report.reportedUserReportsCount} signalements
                </button>
              )}
            </dd>
          </div>
          <div>
            <dt className="text-xs text-muted">Auteur du signalement</dt>
            <dd>
              <PartyLink party={report.reporter} />
            </dd>
          </div>
        </dl>
      </PanelSection>

      {report.status === 'OPEN' ? (
        <PanelSection title="Décision">
          <ReportDecisionForm report={report} canSuspend={canSuspend} onDecided={onDecided} />
        </PanelSection>
      ) : (
        <PanelSection title="Décision prise">
          <p className="text-sm font-medium">{decisionSummary(report)}</p>
          <p className="mt-1 text-xs text-muted">
            {report.resolvedAt !== null &&
              `Résolu le ${new Date(report.resolvedAt).toLocaleString('fr-FR', DATE)}`}
            {report.resolvedBy !== null &&
              ` par ${report.resolvedBy.displayName ?? report.resolvedBy.email}`}
          </p>
          {report.resolutionNote !== null && (
            <blockquote className="mt-3 border-l-2 border-primary/40 pl-3 text-sm">
              {report.resolutionNote}
            </blockquote>
          )}
          <div className="mt-4">
            <ReportReopen report={report} />
          </div>
        </PanelSection>
      )}
    </SidePanel>
  );
}
