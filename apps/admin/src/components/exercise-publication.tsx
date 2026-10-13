'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { ApiError, adminApi } from '@/lib/admin-api';

/**
 * Publier ou masquer un exercice : un interrupteur, l'état dit en toutes
 * lettres à côté. Un exercice masqué disparaît des applications à la
 * requête suivante, sans rien perdre (séances et records gardent leur nom).
 */
export function ExercisePublication({ exercise }: { exercise: AdminExerciseSummary }) {
  const queryClient = useQueryClient();
  const toggle = useMutation({
    mutationFn: () => adminApi.setExercisePublication(exercise.id, !exercise.isPublished),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin', 'exercises'] }),
  });

  if (exercise.deletedAt !== null) {
    return <p className="text-sm text-muted">Supprimé : restaure-le pour le republier.</p>;
  }

  const on = exercise.isPublished;
  return (
    <div>
      <div className="flex items-center justify-between gap-4 rounded-lg border border-border px-4 py-3">
        <div>
          <p className="text-sm font-medium">Visible dans l’application</p>
          <p className="text-xs text-muted">
            {on ? 'Publié : les membres le voient.' : 'Masqué : seule l’administration le voit.'}
          </p>
        </div>
        <button
          type="button"
          role="switch"
          aria-checked={on}
          aria-label="Visible dans l’application"
          disabled={toggle.isPending}
          onClick={() => toggle.mutate()}
          className={`relative inline-flex h-6 w-11 shrink-0 items-center rounded-full transition-colors duration-150 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary disabled:opacity-50 ${
            on ? 'bg-primary' : 'bg-foreground/20'
          }`}
        >
          <span
            aria-hidden
            className={`inline-block h-5 w-5 rounded-full bg-surface shadow-sm transition-transform duration-150 ${
              on ? 'translate-x-5.5' : 'translate-x-0.5'
            }`}
          />
        </button>
      </div>
      {toggle.isError && (
        <p className="mt-2 text-xs text-danger-ink" role="alert">
          {toggle.error instanceof ApiError && toggle.error.status === 403
            ? 'Permission manquante pour publier ou masquer.'
            : 'Changement impossible, réessaie.'}
        </p>
      )}
    </div>
  );
}
