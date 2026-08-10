'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminApi } from '@/lib/admin-api';

/**
 * Retirer un exercice du catalogue — ou l'y remettre.
 *
 * La suppression est DOUCE côté serveur : des séries déjà réalisées et des
 * records citent l'exercice. Le dire ici, à l'endroit du geste, évite de
 * laisser croire qu'on efface des données — et explique pourquoi il revient.
 */
export function ExerciseDeleteCell({ exercise }: { exercise: AdminExerciseSummary }) {
  const queryClient = useQueryClient();
  const [confirming, setConfirming] = useState(false);

  const mutate = useMutation({
    mutationFn: () =>
      exercise.deletedAt === null
        ? adminApi.deleteExercise(exercise.id)
        : adminApi.restoreExercise(exercise.id),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['admin', 'exercises'] });
      setConfirming(false);
    },
  });

  if (exercise.deletedAt !== null) {
    return (
      <div>
        <button
          type="button"
          disabled={mutate.isPending}
          onClick={() => mutate.mutate()}
          className="rounded-lg px-3 py-1 text-xs font-semibold text-primary hover:bg-primary/10 disabled:opacity-50"
        >
          Restaurer
        </button>
        <span className="block text-xs text-muted">
          Supprimé le {new Date(exercise.deletedAt).toLocaleDateString('fr-FR')}
        </span>
      </div>
    );
  }

  if (!confirming) {
    return (
      <button
        type="button"
        onClick={() => setConfirming(true)}
        className="rounded-lg px-3 py-1 text-xs font-semibold text-danger hover:bg-danger/10"
      >
        Supprimer
      </button>
    );
  }

  return (
    <div>
      <p className="text-xs text-muted">
        Il quitte le catalogue ; l’historique des séances qui le citent reste intact.
      </p>
      {mutate.isError && (
        <p className="text-xs text-danger" role="alert">
          {mutate.error instanceof Error ? mutate.error.message : 'Suppression refusée.'}
        </p>
      )}
      <div className="mt-1 flex gap-2">
        <button
          type="button"
          disabled={mutate.isPending}
          onClick={() => mutate.mutate()}
          className="rounded-lg bg-danger px-3 py-1 text-xs font-semibold text-white disabled:opacity-50"
        >
          Confirmer
        </button>
        <button
          type="button"
          onClick={() => setConfirming(false)}
          className="rounded-lg px-3 py-1 text-xs text-muted hover:bg-black/5"
        >
          Annuler
        </button>
      </div>
    </div>
  );
}
