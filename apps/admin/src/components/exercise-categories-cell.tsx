'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminApi } from '@/lib/admin-api';

/** Cases à cocher d'un référentiel, avec le principal marqué d'une étoile. */
function GroupChoice({
  slug,
  name,
  checked,
  isPrimary,
  onToggle,
  onPrimary,
}: {
  slug: string;
  name: string;
  checked: boolean;
  isPrimary: boolean;
  onToggle: () => void;
  onPrimary: () => void;
}) {
  return (
    <li className="flex items-center gap-2">
      <label className="flex flex-1 items-center gap-2">
        <input type="checkbox" checked={checked} onChange={onToggle} />
        <span className={isPrimary ? 'font-semibold' : undefined}>{name}</span>
      </label>
      <button
        type="button"
        onClick={onPrimary}
        aria-pressed={isPrimary}
        title={`Faire de « ${name} » le groupe principal`}
        className={`rounded px-1.5 text-xs ${
          isPrimary ? 'bg-primary/10 text-primary' : 'text-muted hover:bg-black/5'
        }`}
      >
        {isPrimary ? 'principal' : 'définir'}
      </button>
      <span className="sr-only">{slug}</span>
    </li>
  );
}

/**
 * Reclasser un exercice : groupes musculaires et matériels, en une requête.
 *
 * L'écran manipule un ensemble complet plutôt que des ajouts et des retraits —
 * c'est ce que sont des cases à cocher, et c'est ce qui rend l'appel
 * idempotent : le rejouer ne peut pas dédoubler un rattachement.
 */
export function ExerciseCategoriesCell({ exercise }: { exercise: AdminExerciseSummary }) {
  const queryClient = useQueryClient();
  const [open, setOpen] = useState(false);
  const [primary, setPrimary] = useState(exercise.primaryMuscleGroupSlug ?? '');
  const [groups, setGroups] = useState<string[]>(exercise.muscleGroupSlugs);
  const [equipment, setEquipment] = useState<string[]>(exercise.equipmentSlugs);

  const referentials = useQuery({
    queryKey: ['admin', 'referentials'],
    queryFn: async () => ({
      muscleGroups: await adminApi.listMuscleGroups(),
      equipment: await adminApi.listEquipment(),
    }),
    enabled: open,
  });

  const save = useMutation({
    mutationFn: () =>
      adminApi.setExerciseCategories(exercise.id, {
        primaryMuscleGroupSlug: primary,
        secondaryMuscleGroupSlugs: groups.filter((slug) => slug !== primary),
        equipmentSlugs: equipment,
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['admin', 'exercises'] });
      setOpen(false);
    },
  });

  function toggle(list: string[], slug: string): string[] {
    return list.includes(slug) ? list.filter((item) => item !== slug) : [...list, slug];
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="rounded-lg px-2 py-1 text-left text-xs text-muted hover:bg-black/5"
      >
        <span className="block font-medium text-ink">
          {exercise.primaryMuscleGroupName ?? 'Sans groupe'}
        </span>
        <span className="block">
          {exercise.muscleGroupSlugs.length + exercise.equipmentSlugs.length} rattachement(s) —
          modifier
        </span>
      </button>
    );
  }

  return (
    <div className="w-64 rounded-lg bg-surface p-3 ring-1 ring-black/10">
      {referentials.isPending && <p className="text-xs text-muted">Chargement…</p>}
      {referentials.isError && (
        <p className="text-xs text-danger" role="alert">
          Référentiels indisponibles.
        </p>
      )}
      {referentials.data !== undefined && (
        <>
          <p className="text-xs font-semibold uppercase tracking-wide text-muted">Muscles</p>
          <ul className="mt-1 max-h-40 space-y-1 overflow-y-auto text-sm">
            {referentials.data.muscleGroups.map((group) => (
              <GroupChoice
                key={group.id}
                slug={group.slug}
                name={group.name}
                checked={groups.includes(group.slug)}
                isPrimary={primary === group.slug}
                onToggle={() => setGroups((current) => toggle(current, group.slug))}
                onPrimary={() => {
                  setPrimary(group.slug);
                  setGroups((current) =>
                    current.includes(group.slug) ? current : [...current, group.slug],
                  );
                }}
              />
            ))}
          </ul>

          <p className="mt-3 text-xs font-semibold uppercase tracking-wide text-muted">Matériel</p>
          <ul className="mt-1 max-h-32 space-y-1 overflow-y-auto text-sm">
            {referentials.data.equipment.map((item) => (
              <li key={item.id}>
                <label className="flex items-center gap-2">
                  <input
                    type="checkbox"
                    checked={equipment.includes(item.slug)}
                    onChange={() => setEquipment((current) => toggle(current, item.slug))}
                  />
                  {item.name}
                </label>
              </li>
            ))}
          </ul>
        </>
      )}

      {save.isError && (
        <p className="mt-2 text-xs text-danger" role="alert">
          {save.error instanceof Error ? save.error.message : 'Enregistrement refusé.'}
        </p>
      )}
      <div className="mt-3 flex gap-2">
        <button
          type="button"
          disabled={primary === '' || save.isPending}
          onClick={() => save.mutate()}
          className="rounded-lg bg-primary px-3 py-1 text-xs font-semibold text-white disabled:opacity-50"
        >
          Enregistrer
        </button>
        <button
          type="button"
          onClick={() => setOpen(false)}
          className="rounded-lg px-3 py-1 text-xs text-muted hover:bg-black/5"
        >
          Annuler
        </button>
      </div>
      {primary === '' && (
        <p className="mt-2 text-xs text-muted">Choisissez un groupe principal (« définir »).</p>
      )}
    </div>
  );
}
