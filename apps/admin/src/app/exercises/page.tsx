'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { ExercisePhotoCell } from '@/components/exercise-photo-cell';
import { adminApi } from '@/lib/admin-api';

function PublicationToggle({ exercise }: { exercise: AdminExerciseSummary }) {
  const queryClient = useQueryClient();
  const toggle = useMutation({
    mutationFn: () => adminApi.setExercisePublication(exercise.id, !exercise.isPublished),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['admin', 'exercises'] }),
  });

  return (
    <button
      type="button"
      disabled={toggle.isPending}
      onClick={() => toggle.mutate()}
      aria-pressed={exercise.isPublished}
      className={`rounded-full px-3 py-1 text-xs font-semibold transition-colors disabled:opacity-50 ${
        exercise.isPublished
          ? 'bg-primary/10 text-primary hover:bg-primary/20'
          : 'bg-black/5 text-muted hover:bg-black/10'
      }`}
    >
      {exercise.isPublished ? 'Publié' : 'Masqué'}
    </button>
  );
}

/**
 * Catalogue vu du back-office.
 *
 * **Tout média passe par ici** : les photos d'exercices ne sont pas embarquées
 * dans l'application, elles sont déposées depuis cet écran et servies par le
 * stockage objet. Ajouter une illustration ne demande donc aucune livraison.
 */
export default function ExercisesPage() {
  const [search, setSearch] = useState('');
  const [submitted, setSubmitted] = useState('');
  const { data, isPending, isError } = useQuery({
    queryKey: ['admin', 'exercises', submitted],
    queryFn: () => adminApi.listExercises(submitted === '' ? undefined : submitted),
  });

  return (
    <AdminShell title="Exercices">
      <p className="text-sm text-muted">
        Les photos déposées ici sont servies directement aux applications : elles apparaissent à la
        requête suivante, sans mise à jour de l’app.
      </p>

      <form
        className="mt-6 flex gap-2"
        onSubmit={(event) => {
          event.preventDefault();
          setSubmitted(search.trim());
        }}
      >
        <input
          type="search"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Rechercher un exercice…"
          aria-label="Rechercher un exercice"
          className="w-full max-w-sm rounded-lg border border-black/10 px-3 py-2 text-sm"
        />
        <button
          type="submit"
          className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white hover:bg-primary-dark"
        >
          Rechercher
        </button>
      </form>

      {isPending && <p className="mt-6 text-sm text-muted">Chargement…</p>}
      {isError && (
        <p className="mt-6 text-sm text-danger" role="alert">
          Catalogue indisponible — reconnectez-vous si le problème persiste.
        </p>
      )}
      {data !== undefined && (
        <div className="mt-6 overflow-x-auto rounded-xl bg-surface ring-1 ring-black/5">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-black/5 text-xs uppercase tracking-wide text-muted">
              <tr>
                <th className="px-4 py-3">Exercice</th>
                <th className="px-4 py-3">Muscle</th>
                <th className="px-4 py-3">Photo</th>
                <th className="px-4 py-3">Catalogue</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((exercise) => (
                <tr key={exercise.id} className="border-b border-black/5 last:border-0">
                  <td className="px-4 py-3">
                    <span className="font-medium">{exercise.name}</span>
                    {exercise.isPremium && (
                      <span className="ml-2 rounded bg-accent/10 px-1.5 py-0.5 text-xs font-semibold text-accent">
                        Premium
                      </span>
                    )}
                    <span className="block text-xs text-muted">{exercise.slug}</span>
                  </td>
                  <td className="px-4 py-3">{exercise.primaryMuscleGroupName ?? '—'}</td>
                  <td className="px-4 py-3">
                    <ExercisePhotoCell exercise={exercise} />
                  </td>
                  <td className="px-4 py-3">
                    <PublicationToggle exercise={exercise} />
                  </td>
                </tr>
              ))}
              {data.items.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-6 text-center text-muted">
                    Aucun exercice trouvé.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
      {data?.hasMore === true && (
        <p className="mt-3 text-xs text-muted">
          Seuls les {data.items.length} premiers exercices sont affichés — affinez la recherche.
        </p>
      )}
    </AdminShell>
  );
}
