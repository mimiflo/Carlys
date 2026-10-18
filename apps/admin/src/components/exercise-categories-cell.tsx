'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { adminApi } from '@/lib/admin-api';
import { MUSCLE_GROUPS_QUERY_KEY } from './category-row';
import { useFocusOnSwap } from './use-focus-on-swap';
import { button } from './ui/button';

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
          isPrimary ? 'bg-primary/10 text-primary-ink' : 'text-muted hover:bg-foreground/5'
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
  const { target: focusTarget, request: requestFocus } = useFocusOnSwap();
  const [open, setOpen] = useState(false);
  const [primary, setPrimary] = useState(exercise.primaryMuscleGroupSlug ?? '');
  const [groups, setGroups] = useState<string[]>(exercise.muscleGroupSlugs);
  const [equipment, setEquipment] = useState<string[]>(exercise.equipmentSlugs);

  /**
   * Le brouillon repart de ce que la LISTE affiche, à l'ouverture comme à
   * l'annulation : même règle que `CategoryRow`.
   *
   * L'état n'était lu qu'au montage. Cocher « Triceps », annuler, rouvrir :
   * Triceps était toujours coché, et « Enregistrer » écrivait le choix
   * annulé. Et quand la liste rapportait entre-temps le reclassement d'un
   * AUTRE administrateur, l'éditeur rouvert montrait l'ancien état :
   * enregistrer écrasait son travail sans un mot.
   */
  const resetDraft = () => {
    setPrimary(exercise.primaryMuscleGroupSlug ?? '');
    setGroups(exercise.muscleGroupSlugs);
    setEquipment(exercise.equipmentSlugs);
  };

  const close = () => {
    requestFocus();
    setOpen(false);
  };

  // Deux requêtes PARALLÈLES (elles s'enchaînaient), et la clé des groupes
  // est celle de la page Catégories : son cache sert ici, et inversement.
  const muscleGroups = useQuery({
    queryKey: MUSCLE_GROUPS_QUERY_KEY,
    queryFn: () => adminApi.listMuscleGroups(),
    enabled: open,
  });
  const equipmentList = useQuery({
    queryKey: ['admin', 'equipment'],
    queryFn: () => adminApi.listEquipment(),
    enabled: open,
  });
  const referentials =
    muscleGroups.data !== undefined && equipmentList.data !== undefined
      ? { muscleGroups: muscleGroups.data, equipment: equipmentList.data }
      : undefined;
  const referentialsFailed = muscleGroups.isError || equipmentList.isError;

  const save = useMutation({
    mutationFn: () =>
      adminApi.setExerciseCategories(exercise.id, {
        primaryMuscleGroupSlug: primary,
        secondaryMuscleGroupSlugs: groups.filter((slug) => slug !== primary),
        equipmentSlugs: equipment,
      }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['admin', 'exercises'] });
      close();
    },
  });

  function toggle(list: string[], slug: string): string[] {
    return list.includes(slug) ? list.filter((item) => item !== slug) : [...list, slug];
  }

  if (!open) {
    return (
      <button
        ref={focusTarget}
        type="button"
        onClick={() => {
          resetDraft();
          requestFocus();
          setOpen(true);
        }}
        className="rounded-lg px-2 py-1 text-left text-xs text-muted transition-colors duration-150 hover:bg-primary/5"
      >
        <span className="block font-medium text-foreground">
          {exercise.primaryMuscleGroupName ?? 'Sans groupe'}
        </span>
        <span className="block">
          {exercise.muscleGroupSlugs.length + exercise.equipmentSlugs.length} rattachement(s) ·
          modifier
        </span>
      </button>
    );
  }

  return (
    // Le focus se pose sur l'éditeur lui-même, pas sur une case : les
    // référentiels se chargent encore quand il s'ouvre. Le lecteur d'écran
    // annonce alors le groupe et son nom ; Tab mène à la première case.
    <div
      ref={focusTarget}
      tabIndex={-1}
      role="group"
      aria-label={`Catégories de ${exercise.name}`}
      // Dans la fiche latérale (son seul hôte) : toute la largeur, sans ombre de popover.
      className="animate-enter w-full rounded-xl border border-border bg-surface p-3 focus-visible:outline-2 focus-visible:outline-primary"
    >
      {referentials === undefined && !referentialsFailed && (
        <p className="text-xs text-muted">Chargement…</p>
      )}
      {referentialsFailed && (
        <p className="text-xs text-danger-ink" role="alert">
          Référentiels indisponibles.
        </p>
      )}
      {referentials !== undefined && (
        <>
          <p className="text-xs font-medium text-muted">Muscles</p>
          <ul className="mt-1 max-h-72 space-y-1 overflow-y-auto text-sm">
            {referentials.muscleGroups.map((group) => (
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

          <p className="mt-3 text-xs font-medium text-muted">Matériel</p>
          <ul className="mt-1 max-h-32 space-y-1 overflow-y-auto text-sm">
            {referentials.equipment.map((item) => (
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
        <p className="mt-2 text-xs text-danger-ink" role="alert">
          {save.error instanceof Error ? save.error.message : 'Enregistrement refusé.'}
        </p>
      )}
      <div className="mt-3 flex gap-2">
        <button
          type="button"
          disabled={primary === '' || save.isPending}
          onClick={() => save.mutate()}
          className={button('primary', 'sm')}
        >
          Enregistrer
        </button>
        <button
          type="button"
          onClick={() => {
            resetDraft();
            close();
          }}
          className={button('ghost', 'sm')}
        >
          Annuler
        </button>
      </div>
      {primary === '' && (
        <p className="mt-2 text-xs text-muted">Choisis un groupe principal (« définir »).</p>
      )}
    </div>
  );
}
