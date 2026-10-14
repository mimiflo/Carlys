'use client';

import { type AdminExerciseSummary } from '@carlys/api-contracts';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { LoadMore, useCursorPages } from '@/components/cursor-pages';
import { ExerciseSheet } from '@/components/exercise-sheet';
import { Badge } from '@/components/ui/badge';
import { Card } from '@/components/ui/card';
import { ArrowRightIcon, ImageIcon } from '@/components/ui/icons';
import { SearchForm } from '@/components/ui/search-form';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { adminApi } from '@/lib/admin-api';
import { unavailableMessage } from '@/lib/load-error';
import { planStatus, type StatusLabel } from '@/lib/status-labels';

function catalogStatus(exercise: AdminExerciseSummary): StatusLabel {
  if (exercise.deletedAt !== null) return { label: 'Supprimé', tone: 'neutral' };
  return exercise.isPublished
    ? { label: 'Publié', tone: 'success' }
    : { label: 'Masqué', tone: 'warning' };
}

/** Une ligne de la liste : la vignette, le nom, le groupe, les statuts — et la fiche au clic. */
function ExerciseRow({ exercise, onOpen }: { exercise: AdminExerciseSummary; onOpen: () => void }) {
  const others =
    exercise.muscleGroupSlugs.length - (exercise.primaryMuscleGroupName === null ? 0 : 1);
  return (
    <li>
      <button
        type="button"
        onClick={onOpen}
        aria-label={`Ouvrir la fiche de ${exercise.name}`}
        className="group grid w-full grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-x-3 gap-y-1 px-4 py-3 text-left md:flex md:gap-4 transition-colors duration-150 hover:bg-primary/[0.04] focus-visible:bg-primary/[0.06] focus-visible:outline-none"
      >
        {exercise.image === null ? (
          <span
            aria-hidden
            className="row-span-2 flex h-14 w-20 shrink-0 items-center justify-center rounded-lg bg-surface-alt text-muted ring-1 ring-border"
          >
            <ImageIcon />
          </span>
        ) : (
          // eslint-disable-next-line @next/next/no-img-element -- source externe (stockage objet), hors domaines Next
          <img
            src={exercise.image.url}
            alt=""
            loading="lazy"
            decoding="async"
            className="row-span-2 h-14 w-20 shrink-0 rounded-lg object-cover ring-1 ring-border"
          />
        )}
        <span className="min-w-0 self-end md:flex-1 md:self-auto">
          {/* Un exercice supprimé se BARRE, il ne pâlit pas : à 60 %
              d'opacité, son slug tombait à 2,17:1. */}
          <span
            className={`block truncate font-medium ${exercise.deletedAt === null ? '' : 'line-through'}`}
          >
            {exercise.name}
          </span>
          <span className="block truncate font-mono text-xs text-muted">{exercise.slug}</span>
        </span>
        <span className="hidden w-48 shrink-0 text-sm md:block">
          <span className="block truncate">{exercise.primaryMuscleGroupName ?? 'Sans groupe'}</span>
          <span className="block text-xs text-muted">
            {others > 0 ? `+ ${others} groupe${others > 1 ? 's' : ''}` : 'groupe principal'}
            {exercise.equipmentSlugs.length > 0 &&
              ` · ${exercise.equipmentSlugs.length} matériel${exercise.equipmentSlugs.length > 1 ? 's' : ''}`}
          </span>
        </span>
        <span className="col-start-2 flex flex-wrap gap-1.5 self-start md:w-40 md:shrink-0 md:justify-end md:self-auto">
          <Badge status={catalogStatus(exercise)} />
          {exercise.isPremium && <Badge status={planStatus(true)} />}
        </span>
        <span
          aria-hidden
          className="col-start-3 row-span-2 row-start-1 text-muted transition-transform duration-150 group-hover:translate-x-0.5"
        >
          <ArrowRightIcon width={16} height={16} />
        </span>
      </button>
    </li>
  );
}

export default function ExercisesPage() {
  const [submitted, setSubmitted] = useState('');
  const [includeDeleted, setIncludeDeleted] = useState(false);
  // L'exercice ouvert est lu dans la LISTE à chaque rendu : la fiche suit
  // donc chaque rafraîchissement (photo remplacée, catégories enregistrées).
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const {
    items: exercises,
    data,
    isPending,
    error,
    refetch,
    ...more
  } = useCursorPages(['admin', 'exercises', submitted, includeDeleted], (cursor) =>
    adminApi.listExercises(submitted === '' ? undefined : submitted, cursor, includeDeleted),
  );

  const selected = exercises.find((exercise) => exercise.id === selectedId);

  return (
    <AdminShell
      title="Exercices"
      description="Le catalogue des applications. Ouvre un exercice pour changer sa photo, ses catégories, sa publication. Une photo déposée ici apparaît à la requête suivante, sans mise à jour de l’app."
    >
      <SearchForm
        label="Rechercher un exercice"
        placeholder="Rechercher un exercice…"
        onSubmit={(term) => {
          setSelectedId(null);
          setSubmitted(term);
        }}
      >
        <label className="flex items-center gap-2 text-sm text-muted">
          <input
            type="checkbox"
            checked={includeDeleted}
            onChange={(event) => {
              // Comme pour les signalements : un exercice sorti de la liste
              // (supprimé) ne doit pas rouvrir sa fiche en y revenant.
              setSelectedId(null);
              setIncludeDeleted(event.target.checked);
            }}
            className="h-4 w-4 accent-primary"
          />
          Voir les supprimés
        </label>
      </SearchForm>

      <div className="mt-6">
        {isPending && <SkeletonRows />}
        {error !== null && (
          <ErrorState onRetry={() => void refetch()}>
            {unavailableMessage(error, 'Catalogue indisponible', 'exercise:read')}
          </ErrorState>
        )}
        {data !== undefined && (
          <Card className="overflow-hidden">
            <div className="hidden items-center gap-4 border-b border-border bg-surface-alt/60 px-4 py-2.5 text-xs font-medium text-muted md:flex">
              <span className="w-20 shrink-0">Photo</span>
              <span className="flex-1">Exercice</span>
              <span className="w-48 shrink-0">Groupe musculaire</span>
              <span className="w-40 shrink-0 text-right">Statut</span>
              <span className="w-4" />
            </div>
            {exercises.length === 0 ? (
              <p className="px-4 py-12 text-center text-sm text-muted">Aucun exercice trouvé.</p>
            ) : (
              <ul className="divide-y divide-border">
                {exercises.map((exercise) => (
                  <ExerciseRow
                    key={exercise.id}
                    exercise={exercise}
                    onOpen={() => setSelectedId(exercise.id)}
                  />
                ))}
              </ul>
            )}
          </Card>
        )}
        <LoadMore {...more} />
      </div>

      {selected !== undefined && (
        <ExerciseSheet exercise={selected} onClose={() => setSelectedId(null)} />
      )}
    </AdminShell>
  );
}
