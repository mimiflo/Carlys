'use client';

import { type AdminMuscleGroup } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminApi } from '@/lib/admin-api';

/** Une catégorie : renommage, rang d'affichage, suppression. */
export function CategoryRow({ group }: { group: AdminMuscleGroup }) {
  const queryClient = useQueryClient();
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(group.name);
  const [sortOrder, setSortOrder] = useState(String(group.sortOrder));

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['admin', 'muscle-groups'] });

  const save = useMutation({
    mutationFn: () =>
      adminApi.updateMuscleGroup(group.id, { name, sortOrder: Number(sortOrder) || 0 }),
    onSuccess: async () => {
      await refresh();
      setEditing(false);
    },
  });

  const remove = useMutation({
    mutationFn: () => adminApi.deleteMuscleGroup(group.id),
    onSuccess: refresh,
  });

  // Le serveur refuse la suppression d'un groupe encore PRINCIPAL ; le dire
  // ici évite de proposer un geste qu'on sait voué à un 409.
  const removable = group.primaryExercisesCount === 0;

  return (
    <tr className="border-b border-black/5 last:border-0">
      <td className="px-4 py-3">
        {editing ? (
          <input
            value={name}
            onChange={(event) => setName(event.target.value)}
            aria-label={`Nom de ${group.name}`}
            className="rounded-lg border border-black/10 px-2 py-1 text-sm"
          />
        ) : (
          <>
            <span className="font-medium">{group.name}</span>
            <span className="block text-xs text-muted">{group.slug}</span>
          </>
        )}
      </td>
      <td className="px-4 py-3">
        {editing ? (
          <input
            type="number"
            min={0}
            max={999}
            value={sortOrder}
            onChange={(event) => setSortOrder(event.target.value)}
            aria-label={`Rang de ${group.name}`}
            className="w-20 rounded-lg border border-black/10 px-2 py-1 text-sm"
          />
        ) : (
          group.sortOrder
        )}
      </td>
      <td className="px-4 py-3 text-muted">
        {group.exercisesCount} dont {group.primaryExercisesCount} en principal
      </td>
      <td className="px-4 py-3">
        <div className="flex flex-wrap gap-2">
          {editing ? (
            <>
              <button
                type="button"
                disabled={save.isPending}
                onClick={() => save.mutate()}
                className="rounded-lg bg-primary px-3 py-1 text-xs font-semibold text-white disabled:opacity-50"
              >
                Enregistrer
              </button>
              <button
                type="button"
                onClick={() => setEditing(false)}
                className="rounded-lg px-3 py-1 text-xs text-muted hover:bg-black/5"
              >
                Annuler
              </button>
            </>
          ) : (
            <button
              type="button"
              onClick={() => setEditing(true)}
              className="rounded-lg px-3 py-1 text-xs text-primary hover:bg-primary/10"
            >
              Modifier
            </button>
          )}
          <button
            type="button"
            disabled={!removable || remove.isPending}
            onClick={() => remove.mutate()}
            title={
              removable
                ? undefined
                : 'Cette catégorie est le groupe principal d’exercices : reclassez-les d’abord.'
            }
            className="rounded-lg px-3 py-1 text-xs font-semibold text-danger hover:bg-danger/10 disabled:opacity-40 disabled:hover:bg-transparent"
          >
            Supprimer
          </button>
        </div>
        {(save.isError || remove.isError) && (
          <p className="mt-1 text-xs text-danger" role="alert">
            {(save.error ?? remove.error) instanceof Error
              ? ((save.error ?? remove.error) as Error).message
              : 'Action refusée.'}
          </p>
        )}
      </td>
    </tr>
  );
}
