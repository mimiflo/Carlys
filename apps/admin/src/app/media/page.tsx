'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import type { MediaAsset, MediaKind } from '@carlys/api-contracts';
import { AdminShell } from '@/components/admin-shell';
import { adminApi } from '@/lib/admin-api';

const KINDS: readonly { value: MediaKind | 'ALL'; label: string }[] = [
  { value: 'ALL', label: 'Tous' },
  { value: 'IMAGE', label: 'Images' },
  { value: 'MESH_3D', label: 'Maillages 3D' },
  { value: 'VIDEO', label: 'Vidéos' },
];

/** Taille lisible : les octets bruts ne disent rien à l'œil. */
export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} o`;
  const kilo = bytes / 1024;
  if (kilo < 1024) return `${Math.round(kilo)} Ko`;
  return `${(kilo / 1024).toFixed(1).replace('.', ',')} Mo`;
}

/**
 * Bibliothèque de médias.
 *
 * L'API sait lister et supprimer depuis le début ; sans cet écran, un média
 * détaché de son exercice restait invisible et impossible à purger. Le
 * stockage se remplissait de fichiers que plus personne ne pouvait voir.
 */
export default function MediaPage() {
  const queryClient = useQueryClient();
  const [kind, setKind] = useState<MediaKind | 'ALL'>('ALL');
  const [confirming, setConfirming] = useState<string | null>(null);

  const { data, isPending, isError } = useQuery({
    queryKey: ['admin', 'media', kind],
    queryFn: () => adminApi.listMedia(kind === 'ALL' ? undefined : kind),
  });

  const remove = useMutation({
    mutationFn: (id: string) => adminApi.deleteMedia(id),
    onSuccess: async () => {
      setConfirming(null);
      await queryClient.invalidateQueries({ queryKey: ['admin', 'media'] });
    },
  });

  return (
    <AdminShell title="Bibliothèque de médias">
      <div className="flex flex-wrap items-center gap-2">
        {KINDS.map((entry) => (
          <button
            key={entry.value}
            type="button"
            onClick={() => setKind(entry.value)}
            aria-pressed={kind === entry.value}
            className={`rounded-full px-4 py-1.5 text-sm ring-1 ring-black/5 ${
              kind === entry.value ? 'bg-primary text-white' : 'bg-surface text-muted'
            }`}
          >
            {entry.label}
          </button>
        ))}
      </div>

      {isError && (
        <p className="mt-6 text-sm text-danger" role="alert">
          Bibliothèque indisponible : la permission media:read est requise.
        </p>
      )}
      {remove.isError && (
        <p className="mt-6 text-sm text-danger" role="alert">
          Suppression refusée. Un média rattaché à un exercice doit d’abord en être détaché.
        </p>
      )}
      {isPending && <p className="mt-6 text-sm text-muted">Chargement…</p>}
      {data?.length === 0 && (
        <p className="mt-6 text-sm text-muted">
          Aucun média de ce genre. Les fichiers arrivent par la page Exercices.
        </p>
      )}

      <ul className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {data?.map((asset) => (
          <MediaCard
            key={asset.id}
            asset={asset}
            isConfirming={confirming === asset.id}
            isDeleting={remove.isPending && remove.variables === asset.id}
            onAskDelete={() => setConfirming(asset.id)}
            onCancel={() => setConfirming(null)}
            onConfirm={() => remove.mutate(asset.id)}
          />
        ))}
      </ul>
    </AdminShell>
  );
}

function MediaCard({
  asset,
  isConfirming,
  isDeleting,
  onAskDelete,
  onCancel,
  onConfirm,
}: {
  asset: MediaAsset;
  isConfirming: boolean;
  isDeleting: boolean;
  onAskDelete: () => void;
  onCancel: () => void;
  onConfirm: () => void;
}) {
  return (
    <li className="overflow-hidden rounded-xl bg-surface ring-1 ring-black/5">
      <div className="flex h-40 items-center justify-center bg-black/5">
        {asset.kind === 'IMAGE' ? (
          // Aperçu sans composant d'image optimisée : les médias viennent du
          // stockage objet, dont le domaine varie par environnement.
          // eslint-disable-next-line @next/next/no-img-element
          <img src={asset.url} alt={asset.originalName} className="h-full w-full object-contain" />
        ) : (
          <span className="text-xs uppercase tracking-widest text-muted">
            {asset.kind === 'MESH_3D' ? 'Maillage 3D' : 'Vidéo'}
          </span>
        )}
      </div>
      <div className="space-y-1 p-4">
        <p className="truncate text-sm font-medium" title={asset.originalName}>
          {asset.originalName}
        </p>
        <p className="text-xs text-muted">
          {formatBytes(asset.byteSize)}
          {asset.width !== null && asset.height !== null && ` · ${asset.width}×${asset.height}`}
        </p>
        {isConfirming ? (
          <div className="flex items-center gap-2 pt-2">
            <button
              type="button"
              onClick={onConfirm}
              disabled={isDeleting}
              className="rounded-lg bg-danger px-3 py-1.5 text-xs text-white disabled:opacity-60"
            >
              {isDeleting ? 'Suppression…' : 'Confirmer'}
            </button>
            <button type="button" onClick={onCancel} className="text-xs text-muted">
              Annuler
            </button>
          </div>
        ) : (
          <button type="button" onClick={onAskDelete} className="pt-2 text-xs text-danger">
            Supprimer
          </button>
        )}
      </div>
    </li>
  );
}
