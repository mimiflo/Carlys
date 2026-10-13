'use client';

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import type { MediaAsset, MediaKind } from '@carlys/api-contracts';
import { AdminShell } from '@/components/admin-shell';
import { button } from '@/components/ui/button';
import { ImageIcon } from '@/components/ui/icons';
import { EmptyState, ErrorState, SkeletonRows } from '@/components/ui/states';
import { useFocusOnSwap } from '@/components/use-focus-on-swap';
import { adminApi } from '@/lib/admin-api';
import { unavailableMessage } from '@/lib/load-error';

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

  const { data, isPending, error } = useQuery({
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
    <AdminShell
      title="Bibliothèque de médias"
      description="Les fichiers servis aux applications. Ils arrivent par la page Exercices."
    >
      <div className="inline-flex flex-wrap items-center gap-1 rounded-lg bg-surface-alt p-1">
        {KINDS.map((entry) => (
          <button
            key={entry.value}
            type="button"
            onClick={() => setKind(entry.value)}
            aria-pressed={kind === entry.value}
            className={`h-7 rounded-md px-3 text-sm font-medium transition-[background-color,color,box-shadow] duration-150 focus-visible:outline-2 focus-visible:outline-primary ${
              kind === entry.value
                ? 'bg-surface text-foreground shadow-sm ring-1 ring-border'
                : 'text-muted hover:text-foreground'
            }`}
          >
            {entry.label}
          </button>
        ))}
      </div>

      <div className="mt-6 flex flex-col gap-4">
        {error !== null && (
          <ErrorState>
            {unavailableMessage(error, 'Bibliothèque indisponible', 'media:read')}
          </ErrorState>
        )}
        {remove.isError && (
          <ErrorState>
            Suppression refusée. Un média rattaché à un exercice doit d’abord en être détaché.
          </ErrorState>
        )}
        {isPending && <SkeletonRows rows={3} />}
        {data?.length === 0 && (
          <EmptyState icon={<ImageIcon />}>
            Aucun média de ce genre. Les fichiers arrivent par la page Exercices.
          </EmptyState>
        )}
      </div>

      <ul className="mt-2 grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
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
  // « Supprimer » devient « Confirmer / Annuler » : le focus va à
  // « Annuler » (jamais au geste destructeur), puis revient à « Supprimer ».
  const { target: focusTarget, request: requestFocus } = useFocusOnSwap();
  return (
    <li className="animate-enter group overflow-hidden rounded-xl border border-border bg-surface transition-shadow duration-250 hover:shadow-md">
      <div className="flex h-40 items-center justify-center overflow-hidden bg-surface-alt">
        {asset.kind === 'IMAGE' ? (
          // Aperçu sans composant d'image optimisée : les médias viennent du
          // stockage objet, dont le domaine varie par environnement. Chargé
          // à l'approche de l'écran : la liste en montre jusqu'à 200, en
          // taille d'origine.
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src={asset.url}
            alt={asset.originalName}
            loading="lazy"
            decoding="async"
            className="h-full w-full object-contain transition-transform duration-400 ease-out group-hover:scale-[1.03]"
          />
        ) : (
          <span className="flex flex-col items-center gap-2 text-xs font-medium text-muted">
            <span className="flex h-10 w-10 items-center justify-center rounded-full bg-primary/10 text-primary-ink">
              <ImageIcon />
            </span>
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
              className={button('danger', 'sm')}
            >
              {isDeleting ? 'Suppression…' : 'Confirmer'}
            </button>
            <button
              ref={focusTarget}
              type="button"
              onClick={() => {
                requestFocus();
                onCancel();
              }}
              className={button('ghost', 'sm')}
            >
              Annuler
            </button>
          </div>
        ) : (
          <button
            ref={focusTarget}
            type="button"
            onClick={() => {
              requestFocus();
              onAskDelete();
            }}
            className={`${button('danger-outline', 'sm')} mt-2`}
          >
            Supprimer
          </button>
        )}
      </div>
    </li>
  );
}
