'use client';

import { type AdminMuscleGroup } from '@carlys/api-contracts';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { AdminShell } from '@/components/admin-shell';
import { CategoryRow } from '@/components/category-row';
import { adminApi } from '@/lib/admin-api';

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
      className="mt-6 flex flex-wrap items-end gap-3"
      onSubmit={(event) => {
        event.preventDefault();
        create.mutate();
      }}
    >
      <label className="text-sm">
        <span className="block text-xs uppercase tracking-wide text-muted">Nom</span>
        <input
          value={name}
          onChange={(event) => setName(event.target.value)}
          placeholder="Trapèzes"
          className="mt-1 rounded-lg border border-black/10 px-3 py-2 text-sm"
        />
      </label>
      <label className="text-sm">
        <span className="block text-xs uppercase tracking-wide text-muted">
          Slug (proposé d’après le nom)
        </span>
        <input
          value={slug}
          onChange={(event) => setSlug(event.target.value)}
          placeholder={slugify(name) || 'trapezes'}
          className="mt-1 rounded-lg border border-black/10 px-3 py-2 text-sm"
        />
      </label>
      <button
        type="submit"
        disabled={name.trim().length < 2 || create.isPending}
        className="rounded-lg bg-primary px-4 py-2 text-sm font-semibold text-white disabled:opacity-50"
      >
        Ajouter
      </button>
      {create.isError && (
        <p className="w-full text-sm text-danger" role="alert">
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
  const { data, isPending, isError } = useQuery<AdminMuscleGroup[]>({
    queryKey: ['admin', 'muscle-groups'],
    queryFn: () => adminApi.listMuscleGroups(),
  });

  return (
    <AdminShell title="Catégories">
      <p className="text-sm text-muted">
        Les groupes musculaires structurent la bibliothèque de l’application : elle se parcourt par
        catégorie. Une vignette manquante s’affiche sans image, jamais avec celle d’un autre muscle.
      </p>

      <CreateForm />

      {isPending && <p className="mt-6 text-sm text-muted">Chargement…</p>}
      {isError && (
        <p className="mt-6 text-sm text-danger" role="alert">
          Catégories indisponibles : reconnectez-vous si le problème persiste.
        </p>
      )}
      {data !== undefined && (
        <div className="mt-6 overflow-x-auto rounded-xl bg-surface ring-1 ring-black/5">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-black/5 text-xs uppercase tracking-wide text-muted">
              <tr>
                <th className="px-4 py-3">Catégorie</th>
                <th className="px-4 py-3">Rang</th>
                <th className="px-4 py-3">Exercices</th>
                <th className="px-4 py-3">Actions</th>
              </tr>
            </thead>
            <tbody>
              {data.map((group) => (
                <CategoryRow key={group.id} group={group} />
              ))}
              {data.length === 0 && (
                <tr>
                  <td colSpan={4} className="px-4 py-6 text-center text-muted">
                    Aucune catégorie.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </AdminShell>
  );
}
