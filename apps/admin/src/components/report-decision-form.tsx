'use client';

import {
  COMMUNITY_REPORT_NOTE_MAX_LENGTH,
  type AdminCommunityReport,
  type CommunityReportDecision,
} from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useId, useState } from 'react';
import { ApiError, adminApi } from '@/lib/admin-api';
import { contentStillThere, reportTarget } from '@/lib/report-labels';
import { COMMUNITY_REPORTS_QUERY_KEY } from './community-report-status-cell';
import { button, textarea } from './ui/button';

function Choice({
  label,
  hint,
  checked,
  disabled,
  onChange,
}: {
  label: string;
  hint: string;
  checked: boolean;
  disabled: boolean;
  onChange: (checked: boolean) => void;
}) {
  return (
    <label
      className={`flex items-start gap-3 rounded-lg border px-4 py-3 transition-colors duration-150 ${
        checked ? 'border-primary/50 bg-primary/5' : 'border-border'
      } ${disabled ? 'opacity-60' : 'cursor-pointer hover:border-primary/30'}`}
    >
      <input
        type="checkbox"
        checked={checked}
        disabled={disabled}
        onChange={(event) => onChange(event.target.checked)}
        className="mt-0.5 h-4 w-4 accent-primary"
      />
      <span>
        <span className="block text-sm font-medium">{label}</span>
        <span className="block text-xs text-muted">{hint}</span>
      </span>
    </label>
  );
}

function failureMessage(cause: unknown, suspending: boolean): string {
  if (cause instanceof ApiError && cause.status === 403) {
    return suspending
      ? 'Permission manquante : suspendre un compte demande aussi user:update.'
      : 'Permission manquante pour cette action.';
  }
  if (cause instanceof ApiError && (cause.status === 400 || cause.status === 409)) {
    return cause.message;
  }
  return 'Décision impossible pour le moment, réessaie.';
}

/**
 * Trancher un signalement OUVERT : retirer le contenu visé, suspendre la
 * personne, ou classer sans suite — avec une note, OBLIGATOIRE pour une
 * suspension (elle se justifie, et la note reste au dossier). Le serveur
 * refait chaque contrôle ; ici on ne propose que ce qu'il acceptera.
 */
export function ReportDecisionForm({
  report,
  canSuspend,
  onDecided,
}: {
  report: AdminCommunityReport;
  canSuspend: boolean;
  /** La décision est passée : le dossier se ferme (le signalement quitte « Ouverts »). */
  onDecided: () => void;
}) {
  const queryClient = useQueryClient();
  const noteId = useId();
  const [removeContent, setRemoveContent] = useState(false);
  const [suspendUser, setSuspendUser] = useState(false);
  const [note, setNote] = useState('');

  const decide = useMutation({
    mutationFn: (decision: CommunityReportDecision) =>
      adminApi.decideCommunityReport(report.id, decision),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: COMMUNITY_REPORTS_QUERY_KEY });
      onDecided();
    },
    // Tranché entre-temps par quelqu'un d'autre : la liste se relit pour le montrer.
    onError: (cause) => {
      if (cause instanceof ApiError && cause.status === 409) {
        void queryClient.invalidateQueries({ queryKey: COMMUNITY_REPORTS_QUERY_KEY });
      }
    },
  });

  const removable = contentStillThere(report);
  const target = reportTarget(report);
  const alreadySuspended = report.reportedUserStatus !== 'ACTIVE';
  const noteMissing = suspendUser && note.trim() === '';
  const acting = removeContent || suspendUser;

  const submit = () =>
    decide.mutate({
      removeContent,
      suspendUser,
      ...(note.trim() === '' ? {} : { note: note.trim() }),
    });

  return (
    <div className="flex flex-col gap-3">
      <Choice
        label={target === 'challenge' ? 'Retirer le mot du défi' : 'Retirer l’encouragement'}
        hint={
          target === 'person'
            ? 'Ce signalement vise la personne en général : rien à retirer.'
            : removable
              ? 'Il disparaît de l’application. Les autres signalements du même contenu sont résolus avec celui-ci.'
              : 'Le contenu n’existe plus.'
        }
        checked={removeContent}
        disabled={!removable}
        onChange={setRemoveContent}
      />
      <Choice
        label="Suspendre le compte"
        hint={
          alreadySuspended
            ? 'Le compte n’est déjà plus actif.'
            : canSuspend
              ? 'Toutes ses sessions sont fermées tout de suite. Se lève depuis sa fiche.'
              : 'Demande la permission user:update, que ton rôle n’a pas.'
        }
        checked={suspendUser}
        disabled={alreadySuspended || !canSuspend}
        onChange={setSuspendUser}
      />
      <label htmlFor={noteId} className="mt-1 text-sm font-medium">
        Note de décision {suspendUser ? '(obligatoire pour une suspension)' : '(facultative)'}
      </label>
      <textarea
        id={noteId}
        value={note}
        onChange={(event) => setNote(event.target.value)}
        maxLength={COMMUNITY_REPORT_NOTE_MAX_LENGTH}
        rows={3}
        placeholder="Ce qui a motivé la décision, pour l’équipe."
        className={textarea}
      />
      {decide.isError && (
        <p className="text-sm text-danger-ink" role="alert">
          {failureMessage(decide.error, suspendUser)}
        </p>
      )}
      <div className="flex flex-wrap gap-2">
        {acting ? (
          <button
            type="button"
            disabled={noteMissing || decide.isPending}
            onClick={submit}
            className={button(suspendUser ? 'danger' : 'primary')}
          >
            {decide.isPending ? 'Décision…' : 'Appliquer la décision'}
          </button>
        ) : (
          <button
            type="button"
            disabled={decide.isPending}
            onClick={submit}
            className={button('primary')}
          >
            {decide.isPending ? 'Décision…' : 'Classer sans suite'}
          </button>
        )}
      </div>
    </div>
  );
}
