'use client';

import { type AdminMuscleGroup } from '@carlys/api-contracts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { CategoryRow } from '@/components/category-row';
import { button, field } from '@/components/ui/button';
import { ErrorState, SkeletonRows } from '@/components/ui/states';
import { TableCard, th, thead } from '@/components/ui/table';
import { adminApi } from '@/lib/admin-api';
import { unavailableMessage } from '@/lib/load-error';

/** Slug proposé à partir du nom : accents retirés, espaces en tirets. */
export function slugify(name: string): string {
  return name
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/gu, '-')
    .replace(/^-+|-+$/gu, '');
}

function CreateForm() {
  const queryClient = useQueryClient();
  const [name, setName] = useState('');
  const [slug, setSlug] = useState('');

  const create = useMutation({
    mutationFn: () =>
      adminApi.createMuscleGroup({ slug: slug === '' ? slugify(name) : slug, name }),
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['admin', 'muscle-groups'] });
      setName('');
      setSlug('');
    },
  });

  return (
    <form
      className="animate-enter flex flex-wrap items-end gap-3 rounded-xl border border-border bg-surface p-5"
      onSubmit={(event) => {
        event.preventDefault();
        create.mutate();
      }}
    >
      <label className="text-sm">
        <span className="block text-xs font-medium text-muted">Nom</span>
        <input
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Trapèzes"
          className={`${field} mt-1.5 w-56`}
        />
      </label>
      <label className="text-sm">
        <span className="block text-xs font-medium text-muted">Slug (proposé d’après le nom)</span>
        <input
          value={slug}
          onChange={(event) => setSlug(event.target.value)}
          placeholder={slugify(name) || 'trapezes'}
          className={`${field} mt-1.5 w-56 font-mono`}
        />
      </label>
      <button
        type="submit"
        disabled={name.trim().length < 2 || create.isPending}
        className={button('primary')}
      >
        Ajouter
      </button>
      {create.isError && (
        <p className="w-full text-sm text-danger-ink" role="alert">
          {create.error instanceof Error ? create.error.message : 'Création refusée.'}
        </p>
      )}
    </form>
  );
}

/**
 * Les catégories du catalogue — les groupes musculaires.
 *
 * Le nombre d'exercices rattachés est affiché à côté de chaque ligne : sans
 * lui, on supprimerait une catégorie sans savoir ce qu'elle emporte. Le
 * serveur refuse d'ailleurs de retirer un groupe encore PRINCIPAL quelque
 * part, la contrainte de base étant en cascade.
 */
export default function CategoriesPage() {
  const { data, isPending, error } = useQuery<AdminMuscleGroup[]>({
    queryKey: ['admin', 'muscle-groups'],
    queryFn: () => adminApi.listMuscleGroups(),
  });

  return (
    <AdminShell
      title="Catégories"
      description="Les groupes musculaires structurent la bibliothèque de l’application : elle se parcourt par catégorie. Une vignette manquante s’affiche sans image, jamais avec celle d’un autre muscle."
    >
      <CreateForm />

      <div className="mt-6">
        {isPending && <SkeletonRows />}
        {error !== null && (
          <ErrorState>
            {unavailableMessage(error, 'Catégories indisponibles', 'exercise:read')}
          </ErrorState>
        )}
        {data !== undefined && (
          <TableCard>
            <thead className={thead}>
              <tr>
                <th className={th}>Catégorie</th>
                <th className={th}>Rang</th>
                <th className={th}>Exercices</th>
                <th className={th}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.map((group) => (
                <CategoryRow key={group.id} group={group} />
              ))}
              {data.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-12 text-center text-sm text-muted">
                    Aucune catégorie.
                  </td>
                </tr>
              )}
            </tbody>
          </TableCard>
        )}
      </div>
    </AdminShell>
  );
}
