'use client';

import { MEDIA_ALLOWED_MIME_TYPES, type AdminExerciseSummary } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useId, useRef, useState } from 'react';
import { adminApi, AdminApiError } from '@/lib/admin-api';

const ACCEPT = MEDIA_ALLOWED_MIME_TYPES.IMAGE.join(',');

/**
 * Photo d'un exercice : dépôt, remplacement, retrait.
 *
 * Deux appels, dans cet ordre : on dépose le fichier dans la bibliothèque,
 * PUIS on le rattache. C'est la même séparation que côté serveur — un média
 * existe indépendamment de ce qui l'utilise, ce qui permettra demain de
 * réutiliser une photo sur plusieurs exercices sans la redéposer.
 */
export function ExercisePhotoCell({ exercise }: { exercise: AdminExerciseSummary }) {
  const queryClient = useQueryClient();
  const inputRef = useRef<HTMLInputElement>(null);
  const inputId = useId();
  const [error, setError] = useState<string | null>(null);

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['admin', 'exercises'] });

  const upload = useMutation({
    mutationFn: async (file: File) => {
      const media = await adminApi.uploadMedia(file, 'IMAGE', crypto.randomUUID());
      await adminApi.setExerciseImage(exercise.id, media.id);
    },
    onSuccess: async () => {
      setError(null);
      await refresh();
    },
    onError: (cause: unknown) => {
      setError(cause instanceof AdminApiError ? cause.message : 'Dépôt impossible.');
    },
  });

  const detach = useMutation({
    mutationFn: () => adminApi.setExerciseImage(exercise.id, null),
    onSuccess: async () => {
      setError(null);
      await refresh();
    },
    onError: () => setError('Retrait impossible.'),
  });

  const busy = upload.isPending || detach.isPending;

  return (
    <div className="flex items-center gap-3">
      {exercise.image === null ? (
        <div aria-hidden className="h-12 w-12 shrink-0 rounded-lg bg-black/5 ring-1 ring-black/5" />
      ) : (
        // eslint-disable-next-line @next/next/no-img-element -- source externe (stockage objet), hors domaines Next
        <img
          src={exercise.image.url}
          alt={`Photo de ${exercise.name}`}
          className="h-12 w-12 shrink-0 rounded-lg object-cover ring-1 ring-black/5"
        />
      )}

      <div className="min-w-0">
        <input
          id={inputId}
          ref={inputRef}
          type="file"
          accept={ACCEPT}
          className="sr-only"
          onChange={(event) => {
            const file = event.target.files?.[0];
            // Le champ garde sa valeur : sans remise à zéro, redéposer le même
            // fichier après une erreur n'émettrait aucun événement.
            event.target.value = '';
            if (file !== undefined) {
              upload.mutate(file);
            }
          }}
        />
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            disabled={busy}
            onClick={() => inputRef.current?.click()}
            className="rounded-lg border border-black/10 px-2.5 py-1 text-xs font-semibold transition-colors hover:border-primary hover:text-primary disabled:opacity-50"
          >
            {upload.isPending
              ? 'Dépôt…'
              : exercise.image === null
                ? 'Ajouter une photo'
                : 'Remplacer'}
          </button>
          {exercise.image !== null && (
            <button
              type="button"
              disabled={busy}
              onClick={() => detach.mutate()}
              className="text-xs font-medium text-muted transition-colors hover:text-danger disabled:opacity-50"
            >
              Retirer
            </button>
          )}
        </div>
        {exercise.image !== null && (
          <p className="mt-1 truncate text-xs text-muted" title={exercise.image.originalName}>
            {exercise.image.originalName}
            {exercise.image.width !== null && ` · ${exercise.image.width}×${exercise.image.height}`}
          </p>
        )}
        {error !== null && (
          <p className="mt-1 text-xs text-danger" role="alert">
            {error}
          </p>
        )}
      </div>
    </div>
  );
}
