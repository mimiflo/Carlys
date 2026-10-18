'use client';

import { type AdminMuscleGroup } from '@carlys/api-contracts';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminApi } from '@/lib/admin-api';
import { useFocusOnSwap } from './use-focus-on-swap';
import { button, field } from './ui/button';
import { td, tr } from './ui/table';

/** Partagée par la page Catégories et la fiche d'un exercice : un seul cache. */
export const MUSCLE_GROUPS_QUERY_KEY = ['admin', 'muscle-groups'] as const;

/** Une catégorie : renommage, rang d'affichage, suppression. */
export function CategoryRow({ group }: { group: AdminMuscleGroup }) {
  const queryClient = useQueryClient();
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState(group.name);
  const [sortOrder, setSortOrder] = useState(String(group.sortOrder));
  // Le champ Nom à l'ouverture, « Modifier » à la fermeture.
  const { target: focusTarget, request: requestFocus } = useFocusOnSwap();

  const refresh = () => queryClient.invalidateQueries({ queryKey: MUSCLE_GROUPS_QUERY_KEY });

  /**
   * Le brouillon repart de ce que la LISTE affiche — à l'ouverture comme à
   * l'annulation.
   *
   * « Annuler » ne faisait que refermer les champs : la saisie abandonnée
   * restait en mémoire, et la rouvrir puis enregistrer réécrivait le
   * renommage qu'on venait d'annuler. Pire, entre-temps la liste a pu
   * rapporter le renommage d'un AUTRE administrateur : enregistrer ce
   * brouillon périmé écrasait son travail sans un mot.
   */
  const resetDraft = () => {
    setName(group.name);
    setSortOrder(String(group.sortOrder));
  };

  const save = useMutation({
    mutationFn: () =>
      adminApi.updateMuscleGroup(group.id, { name, sortOrder: Number(sortOrder) || 0 }),
    onSuccess: async () => {
      await refresh();
      requestFocus();
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
    <tr className={tr}>
      <td className={td}>
        {editing ? (
          <input
            ref={focusTarget}
            value={name}
            onChange={(event) => setName(event.target.value)}
            aria-label={`Nom de ${group.name}`}
            className={`${field} h-8 max-w-56`}
          />
        ) : (
          <>
            <span className="font-medium">{group.name}</span>
            <span className="block text-xs text-muted">{group.slug}</span>
          </>
        )}
      </td>
      <td data-label="Rang" className={td}>
        {editing ? (
          <input
            type="number"
            min={0}
            max={999}
            value={sortOrder}
            onChange={(event) => setSortOrder(event.target.value)}
            aria-label={`Rang de ${group.name}`}
            className={`${field} h-8 w-20`}
          />
        ) : (
          group.sortOrder
        )}
      </td>
      <td data-label="Exercices" className={`${td} tabular-nums text-muted`}>
        {group.exercisesCount} dont {group.primaryExercisesCount} en principal
      </td>
      <td className={td}>
        <div className="flex flex-wrap gap-2">
          {editing ? (
            <>
              <button
                type="button"
                disabled={save.isPending}
                onClick={() => save.mutate()}
                className={button('primary', 'sm')}
              >
                Enregistrer
              </button>
              <button
                type="button"
                onClick={() => {
                  resetDraft();
                  requestFocus();
                  setEditing(false);
                }}
                className={button('ghost', 'sm')}
              >
                Annuler
              </button>
            </>
          ) : (
            <button
              ref={focusTarget}
              type="button"
              onClick={() => {
                resetDraft();
                requestFocus();
                setEditing(true);
              }}
              className={button('ghost', 'sm')}
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
                : 'Cette catégorie est le groupe principal d’exercices : reclasse-les d’abord.'
            }
            className={button('danger-outline', 'sm')}
          >
            Supprimer
          </button>
        </div>
        {(save.isError || remove.isError) && (
          <p className="mt-1 text-xs text-danger-ink" role="alert">
            {(save.error ?? remove.error) instanceof Error
              ? ((save.error ?? remove.error) as Error).message
              : 'Action refusée.'}
          </p>
        )}
      </td>
    </tr>
  );
}
